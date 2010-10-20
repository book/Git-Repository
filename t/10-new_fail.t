use strict;
use warnings;
use Test::More;
use Cwd qw( abs_path );
use File::Temp qw( tempdir );
use File::Spec;
use File::Path;
use Git::Repository;

plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_is_git('git');

plan tests => 12;

# a place to put a git repository
my $dir = abs_path( tempdir( CLEANUP => 1 ) );
my $missing = File::Spec->catdir( $dir, 'missing' );
my $gitdir  = File::Spec->catdir( $dir, '.git' );

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};

# FAIL - missing repository directory
ok( !eval { Git::Repository->new( git_dir => $missing ) },
    'Missing repository directory' );
like( $@, qr/^directory not found: \Q$missing /, '... expected error message' );

# FAIL - missing working copy directory
ok( !eval { Git::Repository->new( work_tree => $missing ) },
    'Missing work_tree directory' );
like( $@, qr/^directory not found: \Q$missing /, '... expected error message' );

# FAIL - repository is not a git repository
ok( !eval { Git::Repository->new( git_dir => $dir ) },
    'repository directory is not a git repository'
);
like(
    $@,
    qr/^fatal: Not a git repository/,    # error from git itself
    '... expected error message'
);

# FAIL - working copy is not a git working copy
SKIP: {
    my $tmp = File::Spec->tmpdir();
    skip "$tmp is already a working copy for some git repository", 2
        if eval { Git::Repository->new( work_tree => $tmp ) };
    ok( !eval { Git::Repository->new( work_tree => $dir ) },
        'work_tree directory is not a git working copy'
    );
    like(
        $@,
        qr/^fatal: Not a git repository/,    # error from git itself
        '... expected error message'
    );
}

# FAIL - working copy is not a git working copy
mkpath($gitdir);
ok( !eval {
        Git::Repository->new( work_tree => $dir, git_dir => $gitdir );
    },
    'work_tree\'s repository directory is not a git repository'
);
like(
    $@,
    qr/^fatal: Not a git repository/,   # error from git itself
    '... expected error message'
);

# FAIL - extra parameters
ok( !eval {
        Git::Repository->new( work_tree => $dir, extra => 'stuff' );
    },
    'unknown extra parameter'
);
like( $@, qr/^Unknown parameters: extra /, '... expected error message' );

