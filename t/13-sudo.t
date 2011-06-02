use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Spec;

has_git();

plan tests => 1;

# test using a wrapper
my $sudo = File::Spec->catfile( t => 'sudo.pl' );
my $out = Git::Repository->run( qw( a b ), { git => [ $^X, $sudo, 'c' ] } );
is( $out, 'c a b', 'wrapper called correctly' );

