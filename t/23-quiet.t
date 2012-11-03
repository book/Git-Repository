use strict;
use warnings;
use Test::More;
use Test::Git;
use Git::Repository;

has_git('1.5.0');

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
$ENV{GIT_AUTHOR_NAME}     = 'Test Author';
$ENV{GIT_AUTHOR_EMAIL}    = 'test.author@example.com';
$ENV{GIT_COMMITTER_NAME}  = 'Test Committer';
$ENV{GIT_COMMITTER_EMAIL} = 'test.committer@example.com';

# a place to put a git repository
my $r = test_repository;

# PREV will be replaced by the result of the previous command
my @tests = (
    [ [ qw( mktree ),           { input => '' } ] ],
    [ [ qw( commit-tree PREV ), { input => 'empty tree' } ] ],
    [ [qw( update-ref refs/heads/master PREV )] ],
    [ [qw( checkout -b slave )], qr/^Switched to a new branch ['"]slave['"] at / ],
    [ [qw( checkout master )], qr/^Switched to branch ['"]master['"] at / ],
    [ [ qw( checkout slave ), { quiet => 1 } ] ],
    [ [ qw( checkout master ), { quiet => 1 } ] ],
);

plan tests => scalar @tests;

my $PREV;
for my $t (@tests) {
    my ( $args, $re ) = @$t;

    # capture warnings
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, shift };

    # replace the args
    $args = [ map $_ eq 'PREV' ? $PREV : $_, @$args ];

    # run the command
    $PREV = $r->run(@$args);

    # format the command for test output
    my $cmd = join ' ', 'git', map {
        my $v = $_;
        ref $v ? "{ @{[map{qq'$_ => $v->{$_}'}sort keys %$v]} }" : $v
    } @$args;

    # run the actual test
    if ($re) {
        like( $warnings[0], $re, "Got the expected warning for: $cmd" );
    }
    else {
        is( @warnings, 0, "No warning for: $cmd" );
    }
}

