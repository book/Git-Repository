use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Spec;

has_git();

plan tests => 3;

# test using a wrapper
my $sudo = File::Spec->catfile( t => 'sudo.pl' );
my $out = Git::Repository->run( qw( a b ), { git => [ $^X, $sudo, 'git' ] } );
is( $out, 'git a b', 'wrapper called correctly' );

# same wrapper, but to something that fails to identify as git
ok( !eval {
        $out = Git::Repository->run( qw( a b ),
            { git => [ $^X, $sudo, 'meh' ] } );
    },
    'sudo meh fails to pass for sudo git'
);
like(
    $@,
    qr/^git binary '.*meh' not available or broken/,
    '... with expected error message'
);

