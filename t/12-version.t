use strict;
use warnings;
use Test::More;
use Git::Repository;

# current version
my ($version) = Git::Repository->run('--version') =~ /git version (.*)/g;
my @version = split /\./, $version;
diag "Git version $version";

# other versions based on the current one
my ( @lesser, @greater );
for ( 0 .. $#version ) {
    local $" = '.';
    my @v = @version;
    $v[$_]++;
    push @greater, "@v";
    next if 0 > ( $v[$_] -= 2 );
    push @lesser, "@v";
}

# more complex comparisons
my @true = (
    [ '1.7.2.rc0.13.gc9eaaa', 'version_eq', '1.7.2.rc0.13.gc9eaaa' ],
);
my @false = (
    [ '1.7.0.4',   'version_eq', '1.7.2.rc0.13.gc9eaaa' ],
);

plan tests => 1 + 2 * @lesser + 2 * @greater + @true + @false;

my $r = 'Git::Repository';

# version_eq
ok( $r->version_eq($version), "$version version_eq $version" );
ok( !$r->version_eq($_), "$version not version_eq $_" ) for @greater, @lesser;

# version_gt
ok( $r->version_gt($_),  "$version version_gt $_" )     for @lesser;
ok( !$r->version_gt($_), "$version not version_gt $_" ) for @greater;

# test a number of special cases
my $dev;
{

    package Git::Repository::VersionFaker;
    our @ISA = qw( Git::Repository );
    sub run { return "git version $dev" }
}
$r = 'Git::Repository::VersionFaker';

for (@true) {
    ( $dev, my $meth, my $v ) = @$_;
    ok( $r->$meth($v), "$dev $meth $v" );
}

for (@false) {
    ( $dev, my $meth, my $v ) = @$_;
    ok( !$r->$meth($v), "$dev not $meth $v" );
}

