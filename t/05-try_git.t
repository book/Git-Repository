use strict;
use warnings;
use Test::More;
use Git::Repository;
use Cwd qw( cwd );
use File::Spec;

my @not_git = ( map ( {
        (   $_,
            File::Spec->catfile( cwd(),             $_ ),
            File::Spec->catfile( File::Spec->updir, $_ )
        )
    } 'this-command-unlikely-to-even-exist-or-be-git' ),
    $^X, '' );

plan tests => 3 * @not_git;

for my $not_git (@not_git) {

    # special case: '' means test removing $ENV{PATH}
    local $ENV{PATH} if ! $not_git;
    $not_git ||= 'git';

    # direct test
    ok( !Git::Repository::Command::_has_git($not_git),
        "_has_git( $not_git ) fails with bad git command"
    );

    # as an option
    ok( !eval {
            Git::Repository->run( '--version', { git => $not_git } );
            1;
        },
        'run() fails with bad git command'
    );
    like(
        $@,
        qr/^git binary '.*?' not available or broken/,
        '... with expected error message'
    );
}
