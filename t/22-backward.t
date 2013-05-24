use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use File::Spec;
use Cwd qw( cwd realpath );
use Git::Repository;

has_git('1.5.0.rc1');

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
my $home = cwd();

# a place to put a git repository
my $fake   = realpath( tempdir( CLEANUP => 1 ) );
my $r      = test_repository;
my $dir    = $r->work_tree;
my $gitdir = $r->git_dir;

# capture warnings
my @warnings;
local $SIG{__WARN__} = sub { push @warnings, shift };

# use new with various options
my $re_wc = qr/^working_copy is obsolete, please use work_tree instead /;
my $re_re = qr/^repository is obsolete, please use git_dir instead /;
my @tests = (
    [ $home => [ working_copy => $dir ], $re_wc ],
    [ $home => [ work_tree => $dir, working_copy => $fake ], $re_wc ],
    [ $home => [ repository => $gitdir ], $re_re ],
    [ $home => [ git_dir    => $gitdir, repository => $fake ], $re_re ],
    [   $home => [
            git_dir      => $gitdir,
            repository   => $fake,
            work_tree    => $dir,
            working_copy => $fake,
        ],
        $re_re
    ],

    # order doesn't matter
    [   $home => [
            repository   => $fake,
            working_copy => $fake,
            work_tree    => $dir,
            git_dir      => $gitdir,
        ],
        $re_re
    ],
);

# test backward compatibility
plan tests => 2 * @tests;

# now test most possible cases for backward compatibility
for my $t (@tests) {
    my ( $cwd, $args, $re ) = @$t;
    chdir $cwd;
    my $i;
    my @args = grep { ++$i % 2 } @$args;
    $r = eval { Git::Repository->new(@$args) };
    ok( !$r, "Git::Repository->new( @args ) fails" );
    like( $@, $re, '... with expected error message' );
}

