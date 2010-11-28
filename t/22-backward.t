use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use File::Spec;
use Cwd qw( cwd realpath );
use Git::Repository;

has_git('1.5.0');

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
my $home = cwd();

# a place to put a git repository
my $fake   = realpath( tempdir( CLEANUP => 1 ) );
my $r      = test_repository;
my $dir    = $r->work_tree;
my $gitdir = $r->git_dir;

# use new with various options
my @tests = (
    [ $dir  => [] ],
    [ $home => [ working_copy => $dir ] ],
    [ $home => [ work_tree => $dir, working_copy => $fake ] ],
    [ $home => [ repository => $gitdir ] ],
    [ $home => [ git_dir    => $gitdir, repository => $fake ] ],
    [   $home => [
            git_dir      => $gitdir,
            repository   => $fake,
            work_tree    => $dir,
            working_copy => $fake,
        ]
    ],

    # order doesn't matter
    [   $home => [
            repository   => $fake,
            working_copy => $fake,
            work_tree    => $dir,
            git_dir      => $gitdir,
        ]
    ],
);

# test backward compatibility
plan tests => 6 * @tests;

# now test most possible cases for backward compatibility
for my $t (@tests) {
    my ( $cwd, $args ) = @$t;
    chdir $cwd;
    my $i;
    my @args = grep { ++$i % 2 } @$args;
    ok( $r = eval { Git::Repository->new(@$args) },
        "Git::Repository->new( @args )" );
    diag $@ if !$r;
    isa_ok( $r, 'Git::Repository' ) or next;
    is( $r->git_dir,   realpath($gitdir), '... correct git_dir' );
    is( $r->work_tree, realpath($dir),    '... correct work_tree' );
    is( $r->repo_path, $r->git_dir,       '... repo_path == git_dir' );
    is( $r->wc_path,   $r->work_tree,     '... wc_path == work_tree' );
}

