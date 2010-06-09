use strict;
use warnings;
use Test::More;
use Git::Repository;

plan tests => 3;

my $not_git = 'this-command-unlikely-to-even-exist-or-be-git';

# direct test
ok( !Git::Repository::Command::_has_git($not_git),
    '_has_git() fails with bad git command'
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

