use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use File::Spec::Functions;
use Cwd qw( cwd abs_path );
use Git::Repository;

has_git('1.6.2.rc0');    # git clone supports existing directories since then

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
$ENV{LC_ALL}              = 'C';
$ENV{GIT_AUTHOR_NAME}     = 'Test Author';
$ENV{GIT_AUTHOR_EMAIL}    = 'test.author@example.com';
$ENV{GIT_COMMITTER_NAME}  = 'Test Committer';
$ENV{GIT_COMMITTER_EMAIL} = 'test.committer@example.com';
$ENV{GIT_CONFIG_NOSYSTEM} = 1;
delete $ENV{XDG_CONFIG_HOME};
delete $ENV{HOME};
my $home = cwd;

my $r = test_repository;

# add a file
my $file = 'hello.txt';
{
    open my $fh, '>', catfile( $r->work_tree, $file )
        or die "Can't open $file for writing: $!";
    print $fh "Hello, world!\n";
}
$r->run( add => $file );
$r->run( commit => '-m' => 'hello' );
my $sha1 = $r->run( 'rev-parse' => 'master' );

# expect test_repository to fail
if (   Git::Repository->version_ge('1.7.0.rc1')
    && Git::Repository->version_le('1.7.0.2') )
{
    for my $meth (qw( work_tree git_dir )) {
        ok(
            !eval { test_repository( clone => [ $r->$meth ] ) },
            '`git clone <dir1> <dir2>` fails with 1.7.0.rc1 <= git <= 1.7.0.2'
        );
        like(
            $@,
            qr/^test_repository\( clone => \.\.\. \) requires /,
            '.. expected error message'
        );
    }
}

# make a clone with test_repository
else {
    my $s;
    for my $meth (qw( work_tree git_dir )) {
        $s = test_repository( clone => [ $r->$meth ] );
        isnt( $s->git_dir, $r->git_dir, "$meth clone: different git_dir" );
        isnt( $s->work_tree, $r->work_tree,
            "$meth clone: different work_tree" );
        is( $s->run( 'rev-parse' => 'master' ),
            $sha1, "$meth clone points to the same master" );
    }
}

done_testing;
