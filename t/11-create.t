use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use File::Spec;
use File::Path;
use Cwd qw( cwd realpath );
use Git::Repository;

has_git( '1.6.0');

my $version = Git::Repository->version;

plan tests => my $tests + my $between + my $extra;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
my $home = cwd();

# a place to put a git repository
my $tmp = realpath( tempdir( CLEANUP => 1 ) );

# some dirname generating routine
my $i;

sub next_dir { return File::Spec->catdir( $tmp, ++$i ); }

sub test_repo {
    my ( $r, $gitdir, $dir, $options ) = @_;

    # normalize actual paths, but do not die under Win32
    eval { $gitdir = realpath($gitdir) } if defined $gitdir;
    eval { $dir    = realpath($dir) }    if defined $dir;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    isa_ok( $r, 'Git::Repository' );
    is( $r->git_dir,   $gitdir, '... correct git_dir' );
    is( $r->work_tree, $dir,    '... correct work_tree' );
    is_deeply( $r->options, $options, "... correct options" );
}

my ( $dir, $r );
$dir = next_dir;

# PASS - non-existent directory
BEGIN { $tests += 5 }
my $gitdir = File::Spec->catdir( $dir, '.git' );
mkpath $dir;
chdir $dir;
ok( $r = eval {
        $r = Git::Repository->run( 'init', { cwd => $dir } );
        Git::Repository->new( { cwd => $dir } );
    },
    "init => $i"
);
diag $@ if $@;
test_repo( $r, $gitdir, $dir, { cwd => $dir } );
chdir $home;

# PASS - new() on a normal repository
BEGIN { $tests += 5 }
ok( $r = eval { Git::Repository->new( git_dir => $gitdir ); },
    "new( git_dir => $i )" );
diag $@ if $@;
test_repo( $r, $gitdir, $dir, {} );

# PASS - new() on a normal repository
BEGIN { $tests += 5 }
ok( $r = eval { Git::Repository->new( work_tree => $dir ); },
    "new( work_tree => $i )" );
diag $@ if $@;
test_repo( $r, $gitdir, $dir, {} );

# PASS - new() on a subdir of the working copy
BEGIN { $tests += 5 }
my $subdir = File::Spec->catdir( $dir, 'sub' );
mkpath $subdir;
ok( $r = eval { Git::Repository->new( work_tree => $subdir ); },
    "new( work_tree => $i/sub )" );
diag $@ if $@;
test_repo( $r, $gitdir, $dir, {} );

# PASS - new() without arguments
BEGIN { $tests += 5 }
chdir $dir;
ok( $r = eval { Git::Repository->new(); }, "new() => $i" );
diag $@ if $@;
chdir $home;
test_repo( $r, $gitdir, $dir, {} );

# PASS - new() without arguments from subdir
BEGIN { $tests += 5 }
chdir $subdir;
ok( $r = eval { Git::Repository->new(); }, "new() => $i/sub" );
diag $@ if $@;
test_repo( $r, $gitdir, $dir, {} );
chdir $home;

# PASS - new() with both arguments from subdir
BEGIN { $tests += 5 }
chdir $subdir;
ok( $r = eval {
        Git::Repository->new( work_tree => $dir, git_dir => $gitdir );
    },
    "new( work_tree => $i, git_dir => $i/.git ) => $i/sub"
);
diag $@ if $@;
test_repo( $r, $gitdir, $dir, {} );
chdir $home;

my $old;
SKIP: {
    skip "cloning an empty repo dies for 1.7.0.rc1 <= git <= 1.7.0.2, we have $version",
        $between
        if Git::Repository->version_le('1.7.0.2')
            && Git::Repository->version_ge('1.7.0.rc1');

    # PASS - clone an existing repo and warns
    BEGIN { $between += 5 }
    $old = $dir;
    $dir = next_dir;
    ok( $r = eval {
            Git::Repository->run( clone => $old => $dir, { quiet => 1 } );
            Git::Repository->new( work_tree => $dir );
        },
        "clone => @{[ $i - 1 ]} => $i"
    );
    diag $@ if $@;
    test_repo( $r, File::Spec->catdir( $dir, '.git' ), $dir, {} );

    # PASS - clone an existing repo as bare and warns
    # relative target path
    BEGIN { $between += 5 }
    $old = $dir;
    $dir = next_dir;
    chdir $tmp;
    ok( $r = eval {
            Git::Repository->run( clone => '--bare', $old => $i, { quiet => 1} );
            Git::Repository->new( git_dir => $i );
        },
        "clone => --bare, @{[ $i - 1 ]} => $i"
    );
    diag $@ if $@;
    chdir $home;
    test_repo( $r, $dir, undef, {} );

    # PASS - clone an existing repo as bare and warns
    # absolute target path
    BEGIN { $between += 5 }
    SKIP: {
        $old = $dir;
        $dir = next_dir;
        skip 'git clone --bare fails with absolute target path', 5
            if $^O eq 'MSWin32';
        ok( $r = eval {
                Git::Repository->run( clone => '--bare', $old => $dir, { quiet => 1 } );
                Git::Repository->new( git_dir => $dir );
            },
            "clone => --bare, @{[ $i - 1 ]} => $i"
        );
        diag $@ if $@;
        test_repo( $r, $dir, undef, {} );
    }
}

# FAIL - clone a non-existing repo
BEGIN { $tests += 3 }
$old = next_dir;
$dir = next_dir;
ok( !(  $r = eval {
            Git::Repository->run( clone => $old => $dir );
            Git::Repository->new( work_tree => $dir );
        }
    ),
    "clone => @{[ $i - 1 ]} => $i - FAILED"
);
is( $r, undef,
    "clone => @{[ $i - 1 ]} => $i - did not create a repository" );
like( $@, qr/^fatal: /, 'fatal error from git' );

# PASS - init a bare repository
BEGIN { $tests += 5 }
$dir = next_dir;
mkpath $dir;
chdir $dir;
ok( $r = eval {
        Git::Repository->run(qw( init --bare ));
        Git::Repository->new();
    },
    "clone => @{[ $i - 1 ]} - $i"
);
diag $@ if $@;
test_repo( $r, $dir, undef, {} );
chdir $home;

# PASS - new() on a bare repository
BEGIN { $tests += 5 }
ok( $r = eval { Git::Repository->new( git_dir => $dir ); },
    "new( git_dir => $i )" );
diag $@ if $@;
test_repo( $r, $dir, undef, {} );

# PASS - non-existent directory, not a .git GIT_DIR
# no --work-tree mean it's bare
BEGIN { $tests += 5 }
$dir = next_dir;
mkpath $dir;
chdir $dir;
$gitdir = File::Spec->catdir( $dir, '.notgit' );
my $options
    = { cwd => $dir, env => { GIT_DIR => File::Spec->abs2rel($gitdir) } };
ok( $r = eval {
        Git::Repository->run( 'init', $options );
        Git::Repository->new($options);
    },
    "init - cwd => $i, GIT_DIR => '.notgit'"
);
diag $@ if $@;
chdir $home;
test_repo( $r, $gitdir, undef, $options );

BEGIN { $tests += 5 }
ok( $r = eval { Git::Repository->new( git_dir => $gitdir ); },
    "new( git_dir => $i )" );
diag $@ if $@;
test_repo( $r, $gitdir, undef, {} );

# PASS - non-existent directory, not a .git GIT_DIR
# now provide a --work-tree
BEGIN { $tests += 5 }
$dir = next_dir;
mkpath $dir;
chdir $dir;
$gitdir = File::Spec->catdir( $dir, '.notgit' );
$options = { cwd => $dir, env => { GIT_DIR => File::Spec->abs2rel($gitdir) } };
ok( $r = eval {
        Git::Repository->run( "--work-tree=$dir", 'init', $options );
        Git::Repository->new( work_tree => $dir, $options );
    },
    "init - cwd => $i, GIT_DIR => '.notgit'"
);
diag $@ if $@;
test_repo( $r, $gitdir, $dir, $options );
chdir $home;

# PASS - non-existent directory, not a .git GIT_DIR
# provide a --work-tree, and start in a subdir
BEGIN { $tests += 5 }
$dir = next_dir;
mkpath $dir;
$gitdir = File::Spec->catdir( $dir, '.notgit' );
$subdir = File::Spec->catdir( $dir, 'sub' );
mkpath $subdir;
chdir $subdir;
$options = {
    cwd => $subdir,
    env => {
        GIT_DIR       => File::Spec->abs2rel( $gitdir, $subdir ),
        GIT_WORK_TREE => File::Spec->abs2rel( $dir,    $subdir )
    }
};
ok( $r = eval {
        Git::Repository->run( 'init', $options );
        Git::Repository->new($options);
    },
    "init - cwd => $i, GIT_DIR => '.notgit'"
);
diag $@ if $@;
chdir $home;
test_repo( $r, $gitdir, $dir, $options );

# these tests requires git version >= 1.6.5
SKIP: {
    skip "these tests require git >= 1.6.5, but we only have $version", $extra
        if Git::Repository->version_lt('1.6.5');

    # FAIL - init a dir that is a file
    BEGIN { $extra += 3 }
    $dir = next_dir;
    { open my $fh, '>', $dir; }    # creates an empty file
    ok( !(  $r = eval {
                Git::Repository->run( init => $dir );
                Git::Repository->new( work_tree => $dir );
            }
        ),
        "init => $i - FAILED"
    );
    is( $r, undef, "init => $i - did not create a repository" );
    like( $@, qr/^fatal: /, 'fatal error from git' );

    # PASS - init on an existing repository
    BEGIN { $extra += 10 }
    $dir = next_dir;
    $gitdir = File::Spec->catdir( $dir, '.git' );
    ok( $r = eval {
            Git::Repository->run( init => $dir );
            Git::Repository->new( work_tree => $dir );
        },
        "init => $i"
    );
    diag $@ if $@;
    test_repo( $r, $gitdir, $dir, {} );

    ok( $r = eval {
            Git::Repository->run( init => $dir );
            Git::Repository->new( work_tree => $dir );
        },
        "init => $i - again"
    );
    diag $@ if $@;
    test_repo( $r, $gitdir, $dir, {} );
}

