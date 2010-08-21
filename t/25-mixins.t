use strict;
use warnings;
use lib 't';
use Test::More;
use File::Temp qw( tempdir );
use File::Spec;
use Cwd qw( cwd abs_path );
use Git::Repository;

plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_has_git('git');

my $version = Git::Repository->version;
plan skip_all => "these tests require git >= 1.5.0, but we only have $version"
    if Git::Repository->version_lt('1.5.0');

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
my $home = cwd();

# a place to put a git repository
my $dir = abs_path( tempdir( CLEANUP => 1 ) );

plan tests => my $tests;

# first create a new empty repository
chdir $dir;
BEGIN { $tests += 1 }
ok( my $r = eval { Git::Repository->create('init') },
    q{Git::Repository->create( 'init' ) => dir }
);
diag $@ if !$r;
my $gitdir = $r->git_dir;

# FAIL - no hello method
BEGIN { $tests += 1 }
ok( !eval { $r->hello }, 'No hello() method' );

# make sure 't' is still where it should be
chdir $home;

# PASS - load Hello
BEGIN { $tests += 2 }
use_ok( 'Git::Repository', 'Hello' );
is_deeply(
    \@Git::Repository::ISA,
    ['Git::Repository::Mixin::Hello'],
    'expected @Git::Repository::ISA'
);

# PASS - new methods
BEGIN { $tests += 4 }
ok( my $got = eval { $r->hello }, 'hello() method is there' );
diag $@ if $@;
is( $got, "Hello, git world!\n", '... with expected value' );

ok( $got = eval { $r->hello_gitdir }, 'hello_gitdir() method is there' );
diag $@ if $@;
is( $got, "Hello, $gitdir!\n", '... with expected value' );

# FAIL - can't load this mixin
BEGIN { $tests += 2 }
ok( ! eval q{use Git::Repository 'DoesNotExist'; 1;}, 'Failed to load inexistent mixin' );
like( $@, qr{^Can't locate Git/Repository/Mixin/DoesNotExist\.pm }, '... expected error message' );

# PASS - load Hello2
BEGIN { $tests += 2 }
use_ok( 'Git::Repository', 'Hello2' );
is_deeply(
    \@Git::Repository::ISA,
    [ 'Git::Repository::Mixin::Hello', 'Git::Repository::Mixin::Hello2', ],
    'expected @Git::Repository::ISA'
);

# PASS - new methods
BEGIN { $tests += 4 }
ok( $got = eval { $r->hello }, 'hello() method is there' );
diag $@ if $@;
is( $got, "Hello, git world!\n", '... with expected old value' );

ok( $got = eval { $r->hello_worktree }, 'hello_worktree() method is there' );
diag $@ if $@;
is( $got, "Hello, $dir!\n", '... with expected value' );

