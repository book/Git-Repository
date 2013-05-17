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

my @tests = (

    # empty repository
    {   cmd       => [qw( log -1 )],
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
);

# count the warnings we'll check
@warnings = map @{ $_->{warnings} ||= [] }, @tests;

plan tests => 3 * @tests + @warnings + grep exists $_->{output}, @tests;

my $output = '';
for my $t (@tests) {
    @warnings = ();

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
}
