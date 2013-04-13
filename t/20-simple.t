use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use File::Spec;
use Cwd qw( cwd abs_path );
use Git::Repository;

has_git( '1.5.5' );

my $version = Git::Repository->version;

plan tests => my $tests;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
$ENV{GIT_AUTHOR_NAME}     = 'Test Author';
$ENV{GIT_AUTHOR_EMAIL}    = 'test.author@example.com';
$ENV{GIT_COMMITTER_NAME}  = 'Test Committer';
$ENV{GIT_COMMITTER_EMAIL} = 'test.committer@example.com';
my $home = cwd;

local $/ = chr rand 128;

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
Git::Repository->run('init');
my $r = Git::Repository->new();
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
delete @ENV{qw( EDITOR VISUAL GIT_EDITOR )};

SKIP: {
    BEGIN { $tests += 2 }
    skip "these tests require git >= 1.6.6, but we only have $version", 2
        if Git::Repository->version_lt('1.6.6');

    skip "editor defined directly in .gitconfig", 2
        if $r->run( config => 'core.editor' );

    skip "this test does not work with msysgit on Win32", 2
        if $^O eq 'MSWin32';

    ok( !eval { $r->run( var => 'GIT_EDITOR' ); 1; }, 'git var GIT_EDITOR' );
    like(
        $@,
        qr/^fatal: Terminal is dumb, but EDITOR unset /,
        'Git complains about lack of smarts and editor'
    );
}

# with git commit it's not fatal
BEGIN { $tests += 4 }
SKIP: {
    skip "editor defined directly in .gitconfig", 4
        if $r->run( config => 'core.editor' );

    skip "this test does not work with msysgit on Win32", 4
        if $^O eq 'MSWin32';

    ok( my $cmd = $r->command('commit'), 'git commit' );
    isa_ok( $cmd, 'Git::Repository::Command' );
    local $/ = "\n";
    my $error = $cmd->stderr->getline;
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

# test callbacks
BEGIN { $tests += 2 }
@log = $r->run( log => '--pretty=format:%s', sub { ~~ reverse } );
is_deeply( \@log, [ ~~ reverse $message ], 'run() with 1 callback' );

sub rot13 { $_[0] =~ y/a-z/n-za-m/; $_[0] }
@log = $r->run( log => '--pretty=format:%s', \&rot13, sub { ~~ reverse } );
is_deeply( \@log, [ ~~ reverse rot13 $message ], 'run() with 2 callback' );

# use commit-tree with input option
BEGIN { $tests += 4 }
my $parent = $r->run( log => '--pretty=format:%H' );
like( $parent, qr/^[a-f0-9]{40}$/, 'parent commit id' );
my $tree = $r->run( log => '--pretty=format:%T' );
like( $parent, qr/^[a-f0-9]{40}$/, 'parent tree id' );

my $commit;
$commit = $r->run(
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
    my $log = $cmd->stdout;
    local $/ = "\n";
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
    local $/ = "\n";
    my $line = $cmd->stdout->getline();
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
    local $/ = "\n";
    my $line = $cmd->stdout->getline();
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
like( $@, qr/^Can't chdir to .*not-there/, '... expected error message' );

# FAIL - pass more than one Git::Repository to Git::Repository::Command
BEGIN { $tests += 2 }
ok( !eval {
        $r->run( 'version',
            bless( { work_tree => 'TEH FAIL' }, 'Git::Repository' ) );
    },
    'Fail with more than one Git::Repository object'
);
like(
    $@,
    qr/^Too many Git::Repository objects given: /,
    '... expected error message'
);

# now work with GIT_DIR and GIT_WORK_TREE only
BEGIN { $tests += 1 }
{
    local %ENV = %ENV;
    $ENV{GIT_DIR} = $gitdir;

    my $got = Git::Repository->run( log => '-1', '--pretty=format:%H' );
    is( $got, $commit, 'git log -1' );
}

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

# PASS - pass the git binary as an option to new()
BEGIN { $tests += 9 }
{
    my $path_sep = $Config::Config{path_sep} || ';';
    my $re = qr/\Q$path_sep\E/;
    my @ext =
      ( '', $^O eq 'MSWin32' ? ( split $re, $ENV{PATHEXT} ) : () );
    my ($abs_git) = grep { -x && !-d }
      map {
        my $path = $_;
        map { File::Spec->catfile( $path, $_ ) } map { "git$_" } @ext
      } split $re, ( $ENV{PATH} || '' );

    # do not wipe the Windows PATH
    local $ENV{PATH} = join $path_sep,
        $^O eq 'MSWin32'
        ? grep { /\Q$ENV{SYSTEMROOT}\E/ }              split $re, $ENV{PATH}
        : grep { -x File::Spec->catfile( $_, 'pwd' ) } split $re, $ENV{PATH};

    $r = Git::Repository->new( git_dir => $gitdir, { git => $abs_git } );
    isa_ok( $r, 'Git::Repository' );
    is( $r->work_tree, $dir,    'work tree (git_dir, no PATH, git option)' );
    is( $r->git_dir,   $gitdir, 'git dir (git_dir, no PATH, git option)' );

    $r = Git::Repository->new( work_tree => $dir, { git => $abs_git } );
    isa_ok( $r, 'Git::Repository' );
    is( $r->work_tree, $dir, 'work tree (work_tree, no PATH, git option)' );
    is( $r->git_dir, $gitdir, 'git dir (work_tree, no PATH, git option)' );

    chdir $dir;
    $r = Git::Repository->new( { git => $abs_git } );
    isa_ok( $r, 'Git::Repository' );
    chdir $home;
    is( $r->work_tree, $dir,    'work tree (no PATH, git option)' );
    is( $r->git_dir,   $gitdir, 'git dir (no PATH, git option)' );
}

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
    { env => { GIT_AUTHOR_EMAIL => 'fail@fail.com' } },      # ignored silently
    { env => { GIT_AUTHOR_EMAIL => 'example@author.com' } }  # not ignored
);
($author) = grep {/^Author:/} $r->run( log => '-1', '--pretty=medium' );
is( $author,
    'Author: Example author <example@author.com>',
    'Option hash in new() and run()'
);

# FAIL - use more than one option HASH
BEGIN { $tests += 2 }
ok( !eval {
        $r = Git::Repository->new(
            work_tree => $dir,
            { env => { GIT_AUTHOR_NAME => 'Example author' } },
            { git => '/bin/false' }
        );
    },
    'new() dies when given more than one option HASH'
);
like( $@, qr/^Too many option hashes given: /, '... expected error message' );

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
my $log = $r->run( log => '--pretty=format:%s', -1, $commit, { input => undef } );
is( $log, 'a dumb way to set log message', 'Option hash in new() worked' );

# PASS - create the empty tree
BEGIN { $tests += 2 }
ok( $r = eval { Git::Repository->new( work_tree => $dir ) },
    'Git::Repository->new()' );
$tree = $r->run( mktree => { input => '' } );
is( $tree, '4b825dc642cb6eb9a060e54bf8d69288fbee4904', 'mktree empty tree' );

