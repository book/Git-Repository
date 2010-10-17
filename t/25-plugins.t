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
BEGIN { $tests += 1 }
use_ok( 'Git::Repository', 'Hello' );

# PASS - new methods
BEGIN { $tests += 4 }
ok( my $got = eval { $r->hello }, 'hello() method is there' );
diag $@ if $@;
is( $got, "Hello, git world!\n", '... with expected value' );

ok( $got = eval { $r->hello_gitdir }, 'hello_gitdir() method is there' );
diag $@ if $@;
is( $got, "Hello, $gitdir!\n", '... with expected value' );

# FAIL - can't load this plugin
BEGIN { $tests += 2 }
ok( ! eval q{use Git::Repository 'DoesNotExist'; 2;}, 'Failed to load inexistent plugin' );
like( $@, qr{^Can't locate Git/Repository/Plugin/DoesNotExist\.pm }, '... expected error message' );

# PASS - load Hello2 and only a single method
BEGIN { $tests += 2 }
my @warnings;
{
    local $SIG{__WARN__} = sub { push @warnings, shift };
    use_ok( 'Git::Repository', [ Hello2 => 'hello' ] );

    like(
        $warnings[0],
        qr/^Subroutine Git::Repository::hello redefined /,
        'warning about redefined method'
    );
}
@warnings = ();

# PASS - new methods
BEGIN { $tests += 4 }
ok( $got = eval { $r->hello }, 'hello() method is there' );
diag $@ if $@;
is( $got, "Hello, world!\n", '... with new value' );

ok( !eval { $r->hello_worktree }, 'hello_worktree() method is not there' );
like(
    $@,
    qr/^Can't locate object method "hello_worktree" via package "Git::Repository" /,
    '... expected error message'
);

# PASS - load a fully qualified plgin class
BEGIN { $tests += 3 }
use_ok( 'Git::Repository', '+MyGit::Hello' );
ok( $got = eval { $r->myhello }, 'myhello() method is there' );
diag $@ if $@;
is( $got, "Hello, my git world!\n", '... with expected value' );

