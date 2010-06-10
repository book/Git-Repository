use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use File::Spec;
use File::Path;
use Git::Repository;

plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_has_git('git');

plan tests => 12;

# a place to put a git repository
my $dir = tempdir( CLEANUP => 1 );
my $missing = File::Spec->catdir( $dir, 'missing' );
my $gitdir  = File::Spec->catdir( $dir, '.git' );

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};

# FAIL - no paramaters
ok( !eval { Git::Repository->new() }, 'No arguments' );
like(
    $@,
    qr/^'repository' or 'working_copy' argument required /,
    '... expected error message'
);

# FAIL - missing repository directory
ok( !eval { Git::Repository->new( repository => $missing ) },
    'Missing repository directory' );
like( $@, qr/^directory not found: $missing /, '... expected error message' );

# FAIL - missing working copy directory
ok( !eval { Git::Repository->new( working_copy => $missing ) },
    'Missing working_copy directory' );
like( $@, qr/^directory not found: $missing /, '... expected error message' );

# FAIL - repository is not a git repository
ok( !eval { Git::Repository->new( repository => $dir ) },
    'repository directory is not a git repository'
);
like(
    $@,
    qr/^fatal: Not a git repository/,    # error from git itself
    '... expected error message'
);

# FAIL - working copy is not a git working copy
ok( !eval { Git::Repository->new( working_copy => $dir ) },
    'working_copy directory is not a git working copy'
);
like(
    $@,
    qr/^fatal: Not a git repository/,    # error from git itself
    '... expected error message'
);

# FAIL - working copy is not a git working copy
mkpath($gitdir);
ok( !eval {
        Git::Repository->new( working_copy => $dir, repository => $gitdir );
    },
    'working_copy\'s repository directory is not a git repository'
);
like(
    $@,
    qr/^fatal: Not a git repository: $gitdir /,   # error from Git::Repository
    '... expected error message'
);

