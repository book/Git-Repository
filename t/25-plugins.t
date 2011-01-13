use strict;
use warnings;
use lib 't';
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use File::Spec;
use Cwd qw( cwd abs_path );
use Git::Repository;

has_git('1.5.0');

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};

plan tests => my $tests;

# first create a new empty repository
my $r      = test_repository;
my $dir    = $r->work_tree;
my $gitdir = $r->git_dir;

# FAIL - no hello method
BEGIN { $tests += 1 }
ok( !eval { $r->hello }, 'No hello() method' );

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
ok( !eval q{use Git::Repository 'DoesNotExist'; 2;},
    'Failed to load inexistent plugin' );
like(
    $@,
    qr{^Can't locate Git/Repository/Plugin/DoesNotExist\.pm },
    '... expected error message'
);

# PASS - load Hello2 and throw various warnings
my @warnings;
{
    BEGIN { $tests += 5 }
    local $SIG{__WARN__} = sub { push @warnings, shift };
    use_ok( 'Git::Repository', [ Hello2 => 'hello', 'zlonk' ] );

    is( scalar @warnings, 3, 'Got 3 warnings' );
    like(
        $warnings[0],
        qr/^Use of \@KEYWORDS by Git::Repository::Plugin::Hello2 is deprecated /,
        '... deprecation warning'
    );
    like(
        $warnings[1],
        qr/^Unknown keyword 'zlonk' in Git::Repository::Plugin::Hello2 /,
        '... unknown keyword'
    );
    like(
        $warnings[2],
        qr/^Subroutine (Git::Repository::)?hello redefined /,
        '... redefined method warning'
    );
    @warnings = ();

    BEGIN { $tests += 5 }
    use_ok( 'Git::Repository', [ Hello2 => 'bam' ] );
    is( scalar @warnings, 3, 'Got 3 warnings' );
    like(
        $warnings[0],
        qr/^Use of \@KEYWORDS by Git::Repository::Plugin::Hello2 is deprecated /,
        '... deprecation warning'
    );
    like(
        $warnings[1],
        qr/^Unknown keyword 'bam' in Git::Repository::Plugin::Hello2 /,
        '... unknown keyword'
    );
    like(
        $warnings[2],
        qr/^No keywords installed from Git::Repository::Plugin::Hello2 /,
        '... no valid keyword left'
    );
    @warnings = ();
}

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

