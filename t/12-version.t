use strict;
use warnings;
use Test::More;
use Git::Repository;

# current version
my ($version) = Git::Repository->run('--version') =~ /git version (.*)/g;
my @version = split /\./, $version;
diag "Git version $version";

# other versions
my ( @lesser, @greater );
for ( 0 .. $#version ) {
    local $" = '.';
    my @v = @version;
    $v[$_]++;
    push @greater, "@v";
    next if 0 > ( $v[$_] -= 2 );
    push @lesser, "@v";
}

plan tests => 1 + 2 *@lesser + 2 * @greater;

my $r = 'Git::Repository';

# version_eq
ok( $r->version_eq($version), "$version version_eq $version" );
ok( !$r->version_eq($_), "$version not version_eq $_" ) for @greater, @lesser;

# version_gt
ok( $r->version_gt($_),  "$version version_gt $_" )     for @lesser;
ok( !$r->version_gt($_), "$version not version_gt $_" ) for @greater;

