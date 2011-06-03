use strict;
use warnings;
use lib 't';
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use File::Spec;
use Cwd qw( cwd abs_path );
use Git::Repository;

has_git('1.5.0');

my $version = Git::Repository->version;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};

plan tests => my $tests;

# first create a new empty repository
my $r      = test_repository;
my $dir    = $r->work_tree;
my $gitdir = $r->git_dir;

# some test data
my %commit = (
    1 => {
        tree    => 'df2b8fc99e1c1d4dbc0a854d9f72157f1d6ea078',
        parent  => [],
        subject => 'empty file',
        body    => '',
        extra   => '',
    },
    2 => {
        tree    => '6820ead72140bd33a7a821965a05f9a1e89bf3c8',
        parent  => [],
        subject => 'one line',
        body    => "of data\n",
        extra   => '',
    },
);

sub check_commit {
    my ( $id, $log, %more ) = @_;
    my $commit = { %{ $commit{$id} }, %more };
    is( $log->tree, $commit->{tree}, "commit $id tree" );
    is_deeply( [ $log->parent ], $commit->{parent}, "commit $id parent" );
    is( $log->subject, $commit->{subject}, "commit $id subject" );
    is( $log->body,    $commit->{body},    "commit $id body" );
    is( $log->extra,   $commit->{extra},   "commit $id extra" );
}

# no log method yet
BEGIN { $tests += 3 }
ok( !eval { $r->log('-1') }, 'no log() method' );

# load the log method
use_ok( 'Git::Repository', 'Log' );
ok( eval { $r->log('-1') }, 'log() method exists now' );

# create an empty file and commit it
BEGIN { $tests += 2 }
my $file = File::Spec->catfile( $dir, 'file' );
do { open my $fh, '>', $file; };
$r->run( add => 'file' );
$r->run( commit => '-m', $commit{1}{subject} );
my @log = $r->log();
is( scalar @log, 1, '1 commit' );
isa_ok( $_, 'Git::Repository::Log' ) for @log;

# check some log details
BEGIN { $tests += 5 }
check_commit( 1 => $log[0] );
push @{ $commit{2}{parent} }, $log[0]->commit;

# create another commit
BEGIN { $tests += 3 }
do { open my $fh, '>', $file; print $fh 'line 1'; };
$r->run( add => 'file' );
$r->run( commit => '-m', "$commit{2}{subject}\n\n$commit{2}{body}" );
@log = $r->log();
is( scalar @log, 2, '2 commits' );
isa_ok( $_, 'Git::Repository::Log' ) for @log;

# check some log details
BEGIN { $tests += 5 }
check_commit( 2 => $log[0] );

# try as a class method
BEGIN { $tests += 8 }
my $home = cwd;
chdir $dir;
@log = Git::Repository->log();
is( scalar @log, 2, '2 commits' );
isa_ok( $_, 'Git::Repository::Log' ) for @log;

check_commit( 2 => $log[0] );

chdir $home;

# try a command that fails (fatal)
BEGIN { $tests += 2 }
ok( !eval { @log = Git::Repository->log('zlonk') }, q{log('zlonk') failed} );
like(
    $@,
    qr/^fatal: ambiguous argument 'zlonk': unknown revision or path not in/,
    'unknown revision or path'
);

# try a command that returns a git error (usage)
BEGIN { $tests += 2 }
ok( !eval { @log = Git::Repository->log('--bam') }, q{log('--bam') failed} );
like(
    $@,
    qr/^fatal: unrecognized argument: --bam at/,
    'unknown revision or path'
);

# various options combinations
my @options;

BEGIN {
    @options = (
        [ [qw( -p -- file )], [ <<'DIFF', << 'DIFF'] ],
diff --git a/file b/file
index e69de29..dcf168c 100644
--- a/file
+++ b/file
@@ -0,0 +1 @@
+line 1
\ No newline at end of file
DIFF
diff --git a/file b/file
new file mode 100644
index 0000000..e69de29
DIFF
        [ [qw( file )],            [ '', '' ] ],
        [ [qw( --decorate file )], [ '', '' ], '1.5.2.rc0' ],
        [ [qw( --pretty=raw )],    [ '', '' ] ],
    );
    $tests += 13 * @options;
}

for my $o (@options) {
    my ( $args, $extra, $minver ) = @$o;
SKIP: {
        skip "git log @$args needs $minver, we only have $version", 13
            if $minver && Git::Repository->version_lt($minver);
        @log = $r->log(@$args);
        is( scalar @log, 2, "2 commits for @$args" );
        isa_ok( $_, 'Git::Repository::Log' ) for @log;
        check_commit( 2 => $log[0], extra => $extra->[0] );
        check_commit( 1 => $log[1], extra => $extra->[1] );
    }
}

my @badopts;

BEGIN {
    @badopts = ( [qw( --pretty=oneline )], [qw( --graph )], );
    $tests += 2 * @badopts;
}
for my $badopt (@badopts) {
    ok( !eval { $r->log(@$badopt) }, "bad options: @$badopt" );
    like( $@, qr/^log\(\) cannot parse @$badopt/, '.. expected error' );
}

