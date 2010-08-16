use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use File::Spec;
use Cwd qw( cwd abs_path );
use Git::Repository;

plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_has_git('git');

my $version = Git::Repository->version;
plan skip_all => "these tests require git >= 1.5.5, but we only have $version"
    if Git::Repository->version_lt('1.5.5');

plan tests => my $tests;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
$ENV{GIT_AUTHOR_NAME}     = 'Test Author';
$ENV{GIT_AUTHOR_EMAIL}    = 'test.author@example.com';
$ENV{GIT_COMMITTER_NAME}  = 'Test Committer';
$ENV{GIT_COMMITTER_EMAIL} = 'test.committer@example.com';
my $home = cwd;

# small helper sub
sub update_file {
    my ( $file, $content ) = @_;
    open my $fh, '>', $file or die "Can't open $file: $!";
    print {$fh} $content;
    close $fh;
}

# a place to put a git repository
my $dir = abs_path( tempdir( CLEANUP => 1 ) );

# PASS - non-existent directory
BEGIN { $tests += 3 }
chdir $dir;
my $r = Git::Repository->create( 'init' );
isa_ok( $r, 'Git::Repository' );
chdir $home;

is( $r->work_tree, $dir, 'work tree' );

my $gitdir = $r->run( qw( rev-parse --git-dir ) );
$gitdir = File::Spec->catfile( $dir, $gitdir )
    if ! File::Spec->file_name_is_absolute( $gitdir );
is( $gitdir, $r->git_dir, 'git-dir' );

# check usage exit code
BEGIN { $tests += 2 }
ok( ! eval { $r->run( qw( commit --bonk ) ); }, "FAIL with usage text" );
like( $@, qr/^usage: .*?git[- ]commit/m, '... expected usage message' );

# add file to the index
update_file( File::Spec->catfile( $dir, 'readme.txt' ), << 'TXT' );
Some readme text
for our example
TXT

$r->run( add => 'readme.txt' );

# unset all editors
delete @ENV{qw( EDITOR VISUAL )};

SKIP: {
    BEGIN { $tests += 2 }
    skip "these tests require git >= 1.6.6, but we only have $version", 2
        if Git::Repository->version_lt('1.6.6');

    ok( !eval { $r->run( var => 'GIT_EDITOR' ); 1; }, 'git var GIT_EDITOR' );
    like(
        $@,
        qr/^fatal: Terminal is dumb, but EDITOR unset /,
        'Git complains about lack of smarts and editor'
    );
}

# with git commit it's not fatal
BEGIN { $tests += 4 }
{
    ok( my $cmd = $r->command('commit'), 'git commit' );
    isa_ok( $cmd, 'Git::Repository::Command' );
    my $error = $cmd->{stderr}->getline;
    is_deeply( [ $cmd->cmdline ], [ qw( git commit ) ], 'command-line' );
    $cmd->close;
    like(
        $error,
        qr/^(?:error: )?Terminal is dumb/,
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
BEGIN { $tests += 3 }
{
    my $lines;
    my $cmd = $r->command( log => '--pretty=oneline', '--all' );
    isa_ok( $cmd, 'Git::Repository::Command' );
    is_deeply( [ $cmd->cmdline ], [ qw( git log --pretty=oneline --all ) ], 'command-line' );
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
    $cmd->stdout->close;
    $cmd->stderr->close;
}

# FAIL - run a command in a non-existent directory
BEGIN { $tests += 2 }
ok( !eval {
        $r->run(
            log => '-1',
            { cwd => File::Spec->catdir( $dir, 'not-there' ) },
            bless( {}, 'Foo' )    # will be ignored silently
        );
    },
    'Fail with option { cwd => non-existent dir }'
);
like( $@, qr/^Can't chdir to \Q$dir/, '... expected error message' );

# now work with GIT_DIR and GIT_WORK_TREE only
BEGIN { $tests += 1 }
$ENV{GIT_DIR} = $gitdir;

my $got = Git::Repository->run( log => '-1', '--pretty=format:%H' );
is( $got, $commit, 'git log -1' );

# PASS - try with a relative dir
BEGIN { $tests += 3 }
chdir $dir;
$r = Git::Repository->new( work_tree => '.' );
isa_ok( $r, 'Git::Repository' );
chdir $home;

is( $r->work_tree, $dir, 'work tree' );
is( $r->git_dir, $gitdir, 'git dir' );

# PASS - try with a no dir
BEGIN { $tests += 3 }
chdir $dir;
$r = Git::Repository->new();
isa_ok( $r, 'Git::Repository' );
chdir $home;

is( $r->work_tree,   $dir,    'work tree' );
is( $r->git_dir, $gitdir, 'git dir' );

# PASS - use an option HASH
BEGIN { $tests += 3 }
is( Git::Repository->options(), undef, 'No options on the class' );
$r = Git::Repository->new(
    work_tree => $dir,
    {   env => {
            GIT_AUTHOR_NAME  => 'Example author',
            GIT_AUTHOR_EMAIL => 'author@example.com'
        }
    },
    { git => '/bin/false' },    # second option hash will be ignored silently
);
update_file( my $file = File::Spec->catfile( $dir, 'other.txt' ), << 'TXT' );
Some other text
forcing an author
TXT
$r->run( add => $file );
$r->run( commit => '-m', 'Test option hash in new()' );
my ($author) = grep {/^Author:/} $r->run( log => '-1', '--pretty=medium' );
is( $author,
    'Author: Example author <author@example.com>',
    'Option hash in new()'
);

update_file( $file, << 'TXT' );
Some other text
forcing another author
TXT
$r->run(
    commit => '-a',
    '-m', 'Test option hash in run()',
    { env => { GIT_AUTHOR_EMAIL => 'example@author.com' } },
    bless( { work_tree => 'TEH FAIL' }, 'Git::Repository' ),  # ignored silently
    { env => { GIT_AUTHOR_EMAIL => 'fail@fail.com' } },     # ignored silently
);
($author) = grep {/^Author:/} $r->run( log => '-1', '--pretty=medium' );
is( $author,
    'Author: Example author <example@author.com>',
    'Option hash in new() and run()'
);

# PASS - use an option HASH (no env key)
BEGIN { $tests += 2 }
( $parent, $tree ) = split /-/, $r->run( log => '--pretty=format:%H-%T', -1 );
ok( $r = eval {
        Git::Repository->new(
            work_tree => $dir,
            { input => 'a dumb way to set log message' },
        );
    },
    'Git::Repository->new()'
);
$commit = $r->run( 'commit-tree', $tree, '-p', $parent );
my $log = $r->run( log => '--pretty=format:%s', -1, $commit );
is( $log, 'a dumb way to set log message', 'Option hash in new() worked' );

