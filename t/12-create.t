use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use File::Spec;
use File::Path;
use Cwd qw( cwd realpath );
use Git::Repository;

has_git('1.5.0.rc0');

my $version = Git::Repository->version;

plan tests => my $tests;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
my $home = cwd();

# a place to put a git repository
my $dir = realpath( tempdir( CLEANUP => 1 ) );

BEGIN { $tests += 2 }
mkpath $dir;
chdir $dir;

# check that create() dies
my $r = eval { Git::Repository->create('init'); };
ok( !$r, "Git::Repository->create() fails " );
like(
    $@,
    qr/^create\(\) is deprecated, see Git::Repository::Tutorial for better alternatives at /,
    "... with expected error message"
);
chdir $home;

