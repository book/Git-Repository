use strict;
use warnings;
use Test::More;
use Git::Repository;

# get the git version
my ($version) = Git::Repository->run('--version') =~ /git version (.*)/g;
diag "git version $version";

# other versions based on the current one
my @version = split /\./, $version;
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
    [ '1.7.1',                'version_gt', '1.7.1.rc0' ],
    [ '1.7.1.rc1',            'version_gt', '1.7.1.rc0' ],
    [ '1.3.2',                'version_gt', '0.99' ],
    [ '1.7.2.rc0.13.gc9eaaa', 'version_gt', '1.7.0.4' ],
    [ '1.7.1.rc2',            'version_gt', '1.7.1.rc1' ],
    [ '1.7.2.rc0.1.g078e',    'version_gt', '1.7.2.rc0' ],
    [ '1.7.2.rc0.10.g1ba5c',  'version_gt', '1.7.2.rc0.1.g078e' ],
    [ '1.7.1.1',              'version_gt', '1.7.1.1.gc8c07' ],
    [ '1.7.1.1',              'version_gt', '1.7.1.1.g5f35a' ],
);
my @false = (
    [ '1.7.0.4',   'version_eq', '1.7.2.rc0.13.gc9eaaa' ],
    [ '1.7.1.rc1', 'version_eq', '1.7.1.rc2' ],
);

plan tests => 5 + 6 * @lesser + 6 * @greater + @true + @false +
    grep { $_->[1] eq 'version_gt' } @true;

my $r = 'Git::Repository';

# version
is( Git::Repository->version(), $version, "git version $version" );

# version_eq
ok( $r->version_eq($version), "$version version_eq $version" );
ok( !$r->version_eq($_), "$version not version_eq $_" ) for @greater, @lesser;

# version_ne
ok( $r->version_ne($_), "$version version_ne $_" ) for @greater, @lesser;
ok( !$r->version_ne($version), "$version not version_ne $version" );

# version_gt
ok( $r->version_gt($_),  "$version version_gt $_" )     for @lesser;
ok( !$r->version_gt($_), "$version not version_gt $_" ) for @greater;

# version_le
ok( $r->version_lt($_),  "$version version_lt $_" )     for @greater;
ok( !$r->version_lt($_), "$version not version_lt $_" ) for @lesser;

# version_le
ok( $r->version_le($_), "$version version_le $_" ) for $version, @greater;
ok( !$r->version_le($_), "$version not version_le $_" ) for @lesser;

# version_ge
ok( $r->version_ge($_), "$version version_ge $_" ) for $version, @lesser;
ok( !$r->version_ge($_), "$version not version_ge $_" ) for @greater;

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

for ( @false, map { [ reverse @$_ ] } grep { $_->[1] eq 'version_gt' } @true )
{
    ( $dev, my $meth, my $v ) = @$_;
    ok( !$r->$meth($v), "$dev not $meth $v" );
}

