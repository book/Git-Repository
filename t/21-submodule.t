use strict;
use warnings;
use Test::More;
use Test::Requires::Git;
use Test::Git;
use Git::Repository;

test_requires_git '1.5.3.rc0'; # first git submodule appearance

plan skip_all => "git clone fails for git between 1.5.4.rc0 and 1.6.0.rc0"
    if Git::Repository->version_le('1.6.0.rc0')
        && Git::Repository->version_ge('1.5.4.rc0');

plan skip_all =>
    "git submodule add with a non-existing path fails for git between 1.7.0.rc1 and 1.7.0.2"
    if Git::Repository->version_le('1.7.0.2')
        && Git::Repository->version_ge('1.7.0.rc1');

plan skip_all =>
    "Removing environment variables requires System::Command 1.04, this is only $System::Command::VERSION"
    if $System::Command::VERSION < 1.04;

plan tests => 1;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
$ENV{LC_ALL}              = 'C';
$ENV{GIT_AUTHOR_NAME}     = 'Test Author';
$ENV{GIT_AUTHOR_EMAIL}    = 'test.author@example.com';
$ENV{GIT_COMMITTER_NAME}  = 'Test Committer';
$ENV{GIT_COMMITTER_EMAIL} = 'test.committer@example.com';

# create a small repository
my @init;
push @init, init => [ '-q' ] if Git::Repository->version_ge('1.5.2.3');
my $s = test_repository(@init);
my $blob =
  $s->run( qw( hash-object -t blob -w --stdin ), { input => 'hello' } );
my $tree = $s->run( mktree => { input => "100644 blob $blob\thello" } );
my $commit = $s->run( 'commit-tree' => $tree, { input => 'empty tree' } );
$s->run( 'update-ref', 'refs/heads/master' => $commit );
$s->run( checkout => 'master', { quiet => 1 } );

# now test adding a submodule
my $r = test_repository(@init);
$r->run(
    ( Git::Repository->version_ge('2.38.1') ? ('-c', 'protocol.file.allow=always') : ()),
    submodule => add => $s->work_tree => 'sub',
    { env => { GIT_WORK_TREE => undef } }
);

# the result of git submodule add has changed over time
my $expected
    = $r->version_lt('1.5.3.rc1') ? " $commit sub"
    : $r->version_lt('1.5.4.4')   ? " $commit sub (undefined)"
    : $r->version_lt('1.7.6.1')   ? "-$commit sub"
    :                               " $commit sub (heads/master)";

# do the test
my $status = $r->run( 'submodule', 'status', 'sub' );
is( $status, $expected, 'git submodule status' );

