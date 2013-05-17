use strict;
use warnings;
use Test::More;
use Test::Git;
use Git::Repository;

has_git('1.5.0');

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};

# a place to put a git repository
my $r;

# the alias used to control git exit values
# TODO: needs a Windows version
my $exit_alias = qq<!f(){ $^X -e'exit shift' -- "\$\@";};f>;

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

    # check log message
    {   cmd    => [qw( log --pretty=format:%s )],
        exit   => 0,
        output => 'empty tree',
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
            qr/^error: pathspec 'does-not-exist' did not match any file\(s\) known to git. /,
        ],
    },

    # failing git checkout (quiet)
    {   cmd  => [ checkout => 'does-not-exist', { quiet => 1 } ],
        exit => 1,
    },

    # usage messages make run() die too
    {   cmd  => [ branch => '--does-not-exist' ],
        exit => '129',
        dollar_at => qr/^error: unknown option `does-not-exist'/
    },

    # test fatal
    {   cmd  => [ checkout => 'does-not-exist', { fatal => [1] } ],
        exit => 1,
        dollar_at =>
            qr/^error: pathspec 'does-not-exist' did not match any file\(s\) known to git. /,
    },
    {   cmd  => [ checkout => 'does-not-exist', { fatal => 1 } ],
        exit => 1,
        dollar_at =>
            qr/^error: pathspec 'does-not-exist' did not match any file\(s\) known to git. /,
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

    # an helpful alias to die as we want
    {   cmd  => [ config => 'alias.exit' => $exit_alias ],
        exit => 0
    },

    # test some fatal combinations
    {   cmd  => [ exit => 123 ],
        exit => 123,
    },
    {   cmd  => [ exit => 124, { fatal => [ 1 .. 255 ] } ],
        exit => 124,
        dollar_at => qr/^fatal: unknown git error/,
    },

    # setup a repo with some 'fatal' options
    # and override them in the call to run()
    {   test_repo => [ git    => { fatal      => [ 1 .. 255 ] } ],
        cmd       => [ config => 'alias.exit' => $exit_alias ],
        exit      => 0,
    },
    {   cmd       => [ exit => 125 ],
        exit      => 125,
        dollar_at => qr/^fatal: unknown git error/,
    },
    {   cmd  => [ exit => 126, { fatal => [ -130 .. -120 ] } ],
        exit => 126,
    },

);

# count the warnings we'll check
@warnings = map @{ $_->{warnings} ||= [] }, @tests;

plan tests => 3 * @tests + @warnings + grep exists $_->{output}, @tests;

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
    is( $output, $t->{output}, "$cmd: $output" ) if exists $t->{output};

    # check warnings
    is( @warnings, @{ $t->{warnings} }, "warnings: " . @{ $t->{warnings} } );
    for my $warning ( @{ $t->{warnings} } ) {
        like( shift @warnings, $warning, '... expected warning' );
    }
    diag $_ for @warnings;
}
