use strict;
use warnings;
use Test::More;
use Test::Git;
use Git::Repository;
use File::Temp qw( tempfile );
use constant MSWin32 => $^O eq 'MSWin32';

has_git('1.5.0.rc1');

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
$ENV{GIT_AUTHOR_NAME}     = 'Test Author';
$ENV{GIT_AUTHOR_EMAIL}    = 'test.author@example.com';
$ENV{GIT_COMMITTER_NAME}  = 'Test Committer';
$ENV{GIT_COMMITTER_EMAIL} = 'test.committer@example.com';

# a place to put a git repository
my $r;

# a fake git binary used for setting the exit status
my $exit;
eval {
    my $version = Git::Repository->version;
    ( my $fh, $exit ) = tempfile(
        DIR    => 't',
        UNLINK => 1,
      ( SUFFIX => '.bat' )x!! MSWin32,
    );
    print {$fh} MSWin32 ? << "WIN32" : << "UNIX";
\@$^X -e "shift =~ /version/ ? print qq{git version $version\\n} : exit shift" -- %1 %2
WIN32
#!$^X
shift =~ /version/ ? print "git version $version\\n"
                   : exit shift;
UNIX
    close $fh or diag "close $exit failed: $!";
    chmod 0755, $exit or diag "chmod $exit failed: $!";
};

# make sure the binary is available
if ( !-x $exit ) {
    diag "Skipping 'git exit' tests: $exit is not "
        . ( -e _ ? 'executable' : 'available' );
    $exit = '';
}

# capture all warnings
my @warnings;
local $SIG{__WARN__} = sub { push @warnings, shift };

my @tests = (

    # empty repository
    {   test_repo => [],
        cmd       => [qw( log -1 )],
        exit      => 128,
        dollar_at => qr/^fatal: bad default revision 'HEAD' /,
    },

    # create the empty tree
    {   cmd  => [ mktree => { input => '' } ],
        exit => 0,
    },

    # create a dummy commit
    {   cmd  => [ 'commit-tree', undef, { input => "empty tree" } ],
        exit => 0,
    },

    # update master
    {   cmd  => [ 'update-ref' => 'refs/heads/master', undef ],
        exit => 0,
    },

    # failing git rm
    {   cmd  => [ rm => 'does-not-exist' ],
        exit => 128,
        dollar_at =>
            qr/^fatal: pathspec 'does-not-exist' did not match any files /,
    },

    # failing git checkout
    {   cmd      => [ checkout => 'does-not-exist' ],
        exit     => 1,
        warnings => [
            qr/^error: pathspec 'does-not-exist' did not match any file\(s\) known to git\./,
        ],
    },

    # failing git checkout (quiet)
    {   cmd  => [ checkout => 'does-not-exist', { quiet => 1 } ],
        exit => 1,
    },

    # usage messages make run() die too
    {   cmd  => [ branch => '--does-not-exist' ],
        exit => '129',
        dollar_at => Git::Repository->version_lt('1.5.4.rc0')
          ? qr/^usage: git-branch /
          : qr/^error: unknown option `does-not-exist'/
    },

    # test fatal
    {   cmd  => [ checkout => 'does-not-exist', { fatal => [1] } ],
        exit => 1,
        dollar_at =>
            qr/^error: pathspec 'does-not-exist' did not match any file\(s\) known to git\./,
    },
    {   cmd  => [ checkout => 'does-not-exist', { fatal => 1 } ],
        exit => 1,
        dollar_at =>
            qr/^error: pathspec 'does-not-exist' did not match any file\(s\) known to git\./,
    },
    {   cmd      => [ rm => 'does-not-exist', { fatal => -128 } ],
        exit     => 128,
        warnings => [
            qr/^fatal: pathspec 'does-not-exist' did not match any files /,
        ],
    },
    {   cmd  => [ rm => 'does-not-exist', { fatal => -128, quiet => 1 } ],
        exit => 128,
    },
);

# tests that depend on $exit
push @tests, (

    # test some fatal combinations
    {   cmd  => [ exit => 123, { git => $exit } ],
        exit => 123,
    },
    {   cmd  => [ exit => 124, { git => $exit, fatal => [ 1 .. 255 ] } ],
        exit => 124,
        dollar_at => qr/^fatal: unknown git error/,
    },

    # setup a repo with some 'fatal' options
    # and override them in the call to run()
    {   test_repo => [ git    => { fatal      => [ 1 .. 255 ] } ],
        cmd       => [ exit => 125, { git => $exit } ],
        exit      => 125,
        dollar_at => qr/^fatal: unknown git error/,
    },
    {   cmd  => [ exit => 126, { git => $exit, fatal => [ -130 .. -120 ] } ],
        exit => 126,
    },

)x!! $exit;

# test case where EVERY exit status is fatal
push @tests, (

    # FATALITY
    {   test_repo => [ git => { fatal => [ 0 .. 255 ] } ],
        cmd       => ['version'],
        exit      => 0,
        dollar_at => qr/^fatal: unknown git error/,
    },
    {
        cmd  => [ version => { fatal => '-0' } ],
        exit => 0,
    },
);

# more tests that depend on $exit
push @tests, (

    # "!0" is a shortcut for 1..255
    {   test_repo => [],
        cmd       => [ exit => 140, { git => $exit, fatal => '!0' } ],
        exit      => 140,
        dollar_at => qr/^fatal: unknown git error/,
    },
    {   test_repo => [ git => { fatal => '!0' } ],
        cmd       => [ exit => 141, { git => $exit } ],
        exit      => 141,
        dollar_at => qr/^fatal: unknown git error/,
    },
    {   cmd  => [ exit => 142, { git => $exit, fatal => [ -150 .. -130 ] } ],
        exit => 142,
    },

)x!! $exit;

# count the warnings we'll check
@warnings = map @{ $_->{warnings} ||= [] }, @tests;

plan tests => 3 * @tests + @warnings;

my $output = '';
for my $t (@tests) {
    @warnings = ();

    # create a new test repository if needed
    $r = test_repository( @{ $t->{test_repo} } )
        if $t->{test_repo};

    # check if the command threw errors
    my @cmd = map { (defined) ? $_ : $output } @{ $t->{cmd} };
    my $cmd = join ' ', grep !ref, @cmd;
    $output = eval { $r->run(@cmd); };
    $t->{dollar_at}
        ? like( $@, $t->{dollar_at}, "$cmd: died" )
        : is( $@, '', "$cmd: ran ok" );
    is( $? >> 8, $t->{exit}, "$cmd: exit status $t->{exit}" );

    # check warnings
    is( @warnings, @{ $t->{warnings} }, "warnings: " . @{ $t->{warnings} } );
    for my $warning ( @{ $t->{warnings} } ) {
        like( shift @warnings, $warning, '... expected warning' );
    }
    diag $_ for @warnings;
}
