use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use File::Spec;
use File::Path;
use Cwd qw( abs_path );
use Git::Repository;

plan tests => 6;

# a place to put a git repository
my $dir = tempdir( CLEANUP => 1 );
my $missing = File::Spec->catdir( $dir, 'missing' );

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};

# FAIL - non-existent directory
ok( !eval { Git::Repository->init($missing); }, 'Missing directory' );
like( $@, qr/^directory not found: $missing /, '... expected error message' );

# init a classic git repository
my $wc = File::Spec->catdir( $dir, 'wc' );
mkpath($wc);
my $r = Git::Repository->init($wc);
isa_ok( $r, 'Git::Repository' );
is( $r->run_oneline(qw( rev-parse --is-bare-repository )),
    'false', '... but not a bare repository' );
is( $r->wc_path, abs_path( $wc ), '... and directory is the working copy' );

# init a bare repository
my $bare = File::Spec->catdir( $dir, 'bare' );
mkpath($bare);
$r = Git::Repository->init( $bare, '--bare' );
isa_ok( $r, 'Git::Repository' );
is( $r->run_oneline(qw( rev-parse --is-bare-repository )),
    'true', '... and is a bare repository' );
is( $r->repo_path, $bare, '... also has a git directory ' );
is( $r->wc_path, undef, '... but has no working copy' );

