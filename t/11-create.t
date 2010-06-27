use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use File::Spec;
use File::Path;
use Cwd qw( cwd abs_path );
use Git::Repository;
use t::Util;

plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_has_git('git');

my ($version) = Git::Repository->run('--version') =~ /git version (.*)/g;
plan skip_all => "these tests require git > 1.6.0, but we only have $version"
    if !git_minimum_version('1.6.0');

plan tests => my $tests + my $extra;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
my $home = cwd();

# a place to put a git repository
my $tmp = abs_path( tempdir( CLEANUP => 1 ) );

# some dirname generating routine
my $i;

sub next_dir {
    my $dir = File::Spec->catdir( $tmp, ++$i );
    mkpath $dir if @_;
    return $dir;
}

my ( $dir, $r );
$dir = next_dir;

# PASS - non-existent directory
BEGIN { $tests += 4 }
my $gitdir = File::Spec->catdir( $dir, '.git' );
mkpath $dir;
chdir $dir;
ok( $r = eval { $r = Git::Repository->create( 'init' ); },
    "create( init ) => $i" );
diag $@ if $@;
isa_ok( $r, 'Git::Repository' );
is( $r->repo_path, $gitdir, '... correct repo_path' );
is( $r->wc_path,   $dir,    '... correct wc_path' );
chdir $home;

# PASS - new() on a normal repository
BEGIN { $tests += 4 }
ok( $r = eval { Git::Repository->new( repository => $gitdir ); },
    "new( repository => $i )" );
diag $@ if $@;
isa_ok( $r, 'Git::Repository' );
is( $r->repo_path, $gitdir, '... correct repo_path' );
is( $r->wc_path,   $dir,    '... correct wc_path' );

# PASS - new() on a normal repository
BEGIN { $tests += 4 }
ok( $r = eval { Git::Repository->new( working_copy => $dir ); },
    "new( repository => $i )" );
diag $@ if $@;
isa_ok( $r, 'Git::Repository' );
is( $r->repo_path, $gitdir, '... correct repo_path' );
is( $r->wc_path,   $dir,    '... correct wc_path' );

# PASS - new() on a subdir of the working copy
BEGIN { $tests += 5 }
my $subdir = File::Spec->catdir( $dir, 'sub' );
mkpath $subdir;
ok( $r = eval { Git::Repository->new( working_copy => $subdir ); },
    "new( repository => $i/sub )" );
diag $@ if $@;
isa_ok( $r, 'Git::Repository' );
is( $r->repo_path, $gitdir, '... correct repo_path' );
is( $r->wc_path,   $dir,    '... correct wc_path' );
is( $r->wc_subdir, $subdir, '... correct wc_subdir' );

# PASS - new() without arguments
BEGIN { $tests += 4 }
chdir $dir;
ok( $r = eval { $r = Git::Repository->new(); }, "new() => $i" );
diag $@ if $@;
isa_ok( $r, 'Git::Repository' );
is( $r->repo_path, $gitdir, '... correct repo_path' );
is( $r->wc_path,   $dir,    '... correct wc_path' );
chdir $home;

# PASS - new() without arguments from subdir
BEGIN { $tests += 5 }
chdir $subdir;
ok( $r = eval { $r = Git::Repository->new(); }, "new() => $i/sub" );
diag $@ if $@;
isa_ok( $r, 'Git::Repository' );
is( $r->repo_path, $gitdir, '... correct repo_path' );
is( $r->wc_path,   $dir,    '... correct wc_path' );
is( $r->wc_subdir, $subdir, '... correct wc_subdir' );
chdir $home;

# FAIL - command doesn't initialize a git repository
BEGIN { $tests += 2 }
ok( !( $r = eval { Git::Repository->create('--version'); } ),
    "create( --version ) FAILED" );
diag $@ if $@;
is( $r, undef, 'create( log ) did not create a repository' );

# PASS - clone an existing repo and warns
BEGIN { $tests += 4 }
my $old = $dir;
$dir = next_dir;
ok( $r = eval { Git::Repository->create( clone => $old => $dir ); },
    "create( clone => @{[ $i - 1 ]} => $i )" );
diag $@ if $@;
isa_ok( $r, 'Git::Repository' );
is( $r->repo_path,
    File::Spec->catdir( $dir, '.git' ),
    '... correct repo_path'
);
is( $r->wc_path, $dir, '... correct wc_path' );

# FAIL - clone a non-existing repo
BEGIN { $tests += 3 }
$old = next_dir;
$dir = next_dir;
ok( !( $r = eval { Git::Repository->create( clone => $old => $dir ); } ),
    "create( clone => @{[ $i - 1 ]} => $i ) FAILED" );
is( $r, undef,
    "create( clone => @{[ $i - 1 ]} => $i ) did not create a repository" );
like( $@, qr/^fatal: /, 'fatal error from git' );

# PASS - init a bare repository
BEGIN { $tests += 4 }
$dir = next_dir;
mkpath $dir;
chdir $dir;
ok( $r = eval { Git::Repository->create( qw( init --bare ) ); },
    "create( clone => @{[ $i - 1 ]} ) => $i" );
diag $@ if $@;
isa_ok( $r, 'Git::Repository' );
is( $r->repo_path, $dir,  '... correct repo_path' );
is( $r->wc_path,   undef, '... correct wc_path' );
chdir $home;

# PASS - new() on a bare repository
BEGIN { $tests += 4 }
ok( $r = eval { Git::Repository->new( repository => $dir ); },
    "new( repository => $i )" );
diag $@ if $@;
isa_ok( $r, 'Git::Repository' );
is( $r->repo_path, $dir,  '... correct repo_path' );
is( $r->wc_path,   undef, '... correct wc_path' );

# these tests requires git version > 1.6.5
SKIP: {
    skip "these tests require git > 1.6.5, but we only have $version", $extra
        if !git_minimum_version('1.6.5');

    # FAIL - init a dir that is a file
    BEGIN { $extra += 3 }
    $dir = next_dir;
    { open my $fh, '>', $dir; }    # creates an empty file
    ok( !( $r = eval { $r = Git::Repository->create( init => $dir ); } ),
        "create( init => $i ) FAILED" );
    is( $r, undef, "create( init => $i ) did not create a repository" );
    like( $@, qr/^fatal: /, 'fatal error from git' );

    # PASS - create() on an existing repository
    BEGIN { $extra += 8 }
    $dir = next_dir;
    $gitdir = File::Spec->catdir( $dir, '.git' );
    ok( $r = eval { Git::Repository->create( init => $dir ) },
        "create( init => $i ) " );
    diag $@ if $@;
    isa_ok( $r, 'Git::Repository' );
    is( $r->repo_path, $gitdir, '... correct repo_path' );
    is( $r->wc_path,   $dir,    '... correct wc_path' );

    ok( $r = eval { Git::Repository->create( init => $dir ) },
        "create( init => $i ) again" );
    diag $@ if $@;
    isa_ok( $r, 'Git::Repository' );
    is( $r->repo_path, $gitdir, '... correct repo_path' );
    is( $r->wc_path,   $dir,    '... correct wc_path' );
}
