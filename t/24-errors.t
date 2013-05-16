use strict;
use warnings;
use Test::More;
use Test::Git;
use Git::Repository;

has_git('1.5.0');

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};

# a place to put a git repository
my $r = test_repository;

# capture all warnings
my @warnings;
local $SIG{__WARN__} = sub { push @warnings, shift };

# some error testing on the empty repository
@warnings = ();
eval { my $log = $r->run( log => '-1' ); };
like( $@, qr/^fatal: bad default revision 'HEAD' /, 'log: died' );
is( $? >> 8,   128, 'log: exit status 128' );
is( @warnings, 0,   'no warnings' );

# create the empty tree
@warnings = ();
my $tree = $r->run( mktree => { input => '' } );
is( $? >> 8, 0, 'mktree: exit status 0' );
is( $tree, '4b825dc642cb6eb9a060e54bf8d69288fbee4904', 'mktree empty tree' );
is( @warnings, 0, 'no warnings' );

# create a dummy commit
@warnings = ();
my $commit = $r->run( 'commit-tree', $tree, { input => "empty tree" } );
is( $? >> 8, 0, 'commit-tree: exit status 0' );
$r->run( 'update-ref' => 'refs/heads/master', $commit );
is( $? >> 8,   0, 'update-ref: exit status 0' );
is( @warnings, 0, 'no warnings' );

# update master
@warnings = ();
is( $r->run( log => '--pretty=format:%s' ), 'empty tree', 'commit' );
is( $? >> 8,   0, 'log: exit status 0' );
is( @warnings, 0, 'no warnings' );

# failing git rm
@warnings = ();
eval { $r->run( rm => 'void' ); };
like( $@, qr/^fatal: pathspec 'void' did not match any files /, 'rm: died' );
is( $? >> 8,   128, 'rm: exit status 128' );
is( @warnings, 0,   'no warnings' );

# failing git checkout
@warnings = ();
$r->run( checkout => 'void' );
is( $@,        '', 'checkout: ran ok (but warned)' );
is( $? >> 8,   1,  'checkout: exit status 1' );
is( @warnings, 1,  '1 warning' );
like(
    $warnings[0],
    qr/^error: pathspec 'void' did not match any file\(s\) known to git. /,
    '... with the expected error message'
);

# failing git checkout (quiet)
@warnings = ();
$r->run( checkout => 'void', { quiet => 1 } );
is( $@,        '', 'checkout: ran ok (but warned)' );
is( $? >> 8,   1,  'checkout: exit status 1' );
is( @warnings, 0,  'no warnings' );

done_testing();
