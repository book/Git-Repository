use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use File::Spec;
use Cwd qw( cwd abs_path );
use Git::Repository;
use t::Util;

plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_has_git('git');

my ($version) = Git::Repository->run('--version') =~ /git version (.*)/g;
plan skip_all => "these tests require git > 1.6.0, but we only have $version"
    if !git_minimum_version('1.6.0');

plan tests => my $tests;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
my $home = cwd;

# a place to put a git repository
my $dir = abs_path( tempdir( CLEANUP => 1 ) );

# PASS - non-existent directory
BEGIN { $tests += 3 }
chdir $dir;
my $r = Git::Repository->create( 'init' );
isa_ok( $r, 'Git::Repository' );
chdir $home;

is( $r->wc_path, $dir, 'work tree' );

my $gitdir = $r->run( qw( rev-parse --git-dir ) );
$gitdir = File::Spec->catfile( $dir, $gitdir )
    if ! File::Spec->file_name_is_absolute( $gitdir );
is( $gitdir, $r->repo_path, 'git-dir' );

# check usage exit code
BEGIN { $tests += 2 }
ok( ! eval { $r->run( qw( commit --bonk ) ); }, "FAIL with usage text" );
like( $@, qr/^usage: git commit/m, '... expected usage message' );

# add file to the index
my $file = File::Spec->catfile( $dir, 'readme.txt' );
open my $fh, '>', $file or die "Can't open $file: $!";
print {$fh} << 'TXT';
Some readme text
for our example
TXT

$r->run( add => 'readme.txt' );

# unset all editors
delete @ENV{qw( EDITOR VISUAL )};

SKIP: {
    BEGIN { $tests += 2 }
    skip "these tests require git > 1.6.6, but we only have $version", 2
        if !git_minimum_version('1.6.6');

    ok( !eval { $r->run( var => 'GIT_EDITOR' ); 1; }, 'git var GIT_EDITOR' );
    like(
        $@,
        qr/^fatal: Terminal is dumb, but EDITOR unset /,
        'Git complains about lack of smarts and editor'
    );
}

# with git commit it's not fatal
BEGIN { $tests += 3 }
{
    ok( my $cmd = $r->command('commit'), 'git commit' );
    isa_ok( $cmd, 'Git::Repository::Command' );
    my $error = $cmd->{stderr}->getline;
    $cmd->close;
    like(
        $error,
        qr/^error: Terminal is dumb/,
        'Git complains about lack of smarts and editor'
    );
}

# commit again
BEGIN { $tests += 1 }
my $message = 'a readme file';
$r->run( commit => '-m', $message );

my @log = $r->run( log => '--pretty=format:%s' );
is_deeply( \@log, [$message], 'git commit ; git log' );

# use commit-tree with input option
BEGIN { $tests += 4 }
my $parent = $r->run( log => '--pretty=format:%H' );
like( $parent, qr/^[a-f0-9]{40}$/, 'parent commit id' );
my $tree = $r->run( log => '--pretty=format:%T' );
like( $parent, qr/^[a-f0-9]{40}$/, 'parent tree id' );
my $commit = $r->run(
    'commit-tree' => $tree,
    '-p',
    $parent,
    { input => "$message $tree" },
);
like( $commit, qr/^[a-f0-9]{40}$/, 'new commit id' );
cmp_ok( $commit, 'ne', $parent, 'new commit id is different from parent id' );
$r->run( reset => $commit );

# process "long" output
BEGIN { $tests += 2 }
{
    my $lines;
    my $cmd = $r->command( log => '--pretty=oneline', '--all' );
    isa_ok( $cmd, 'Git::Repository::Command' );
    my $log = $cmd->{stdout};
    while (<$log>) {
        $lines++;
    }
    is( $lines, 2, 'git log' );

    # no call to close, we count on DESTROY
}

# use command as a class method, with cwd option
BEGIN { $tests += 2 }
{
    my $cmd = Git::Repository->command(
        { cwd => $dir },
        log => '-1',
        '--pretty=format:%H'
    );
    isa_ok( $cmd, 'Git::Repository::Command' );
    my $line = $cmd->{stdout}->getline();
    chomp $line;
    is( $line, $commit, 'git log -1' );
}

# use command as a class method, with env option
BEGIN { $tests += 2 }
{
    my $cmd = Git::Repository->command(
        { env => { GIT_DIR => $gitdir } },
        log => '-1',
        '--pretty=format:%H'
    );
    isa_ok( $cmd, 'Git::Repository::Command' );
    my $line = $cmd->{stdout}->getline();
    chomp $line;
    is( $line, $commit, 'git log -1' );
    $cmd->{stdout}->close;
    $cmd->{stderr}->close;
}

# FAIL - run a command in a non-existent directory
BEGIN { $tests += 2 }
ok( !eval {
        $r->run(
            log => '-1',
            { cwd => File::Spec->catdir( $dir, 'not-there' ) }
        );
    },
    'Fail with option { cwd => non-existent dir }'
);
like( $@, qr/^Can't chdir to $dir/, '... expected error message' );

# now work with GIT_DIR and GIT_WORK_TREE only
BEGIN { $tests += 1 }
$ENV{GIT_DIR} = $gitdir;

my $got = Git::Repository->run( log => '-1', '--pretty=format:%H' );
is( $got, $commit, 'git log -1' );
