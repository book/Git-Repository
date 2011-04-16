use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use File::Spec;
use File::Path;
use Cwd qw( cwd realpath );
use Git::Repository;

has_git('1.5.0');

my $version = Git::Repository->version;

plan tests => my $tests;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
my $home = cwd();

# a place to put a git repository
my $dir = realpath( tempdir( CLEANUP => 1 ) );

# capture warnings
my @warnings;
local $SIG{__WARN__} = sub { push @warnings, shift };

BEGIN { $tests += 4 }
mkpath $dir;
chdir $dir;

# check that create() does warn
ok( my $r = eval { Git::Repository->create('init'); },
    "Git::Repository->create()" );
diag $@ if $@;
isa_ok( $r, 'Git::Repository' );

is( scalar @warnings, 1, "create() outputs a single warning" );
like(
    $warnings[0],
    qr/^create\(\) is deprecated, please use run\(\) instead at /,
    "Git::Repository->create() warns"
);
chdir $home;

