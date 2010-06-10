use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use File::Spec;
use Cwd qw( abs_path );
use Git::Repository;

plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_has_git('git');

plan tests => my $tests;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};

# a place to put a git repository
my $dir = tempdir( CLEANUP => 1 );

# PASS - non-existent directory
BEGIN { $tests += 1 }
my $r = Git::Repository->create( init => $dir );
isa_ok( $r, 'Git::Repository' );

my $file = File::Spec->catfile( $r->wc_path, 'readme.txt' );
open my $fh, '>', $file or die "Can't open $file: $!";
print {$fh} << 'TXT';
Some readme text
for our example
TXT

# add file to the index
$r->run( add => 'readme.txt' );

# unset all editors
BEGIN { $tests += 2 }
delete @ENV{qw( EDITOR VISUAL )};
ok( !eval { $r->run( var => 'GIT_EDITOR' ); 1; }, 'git var GIT_EDITOR' );
like(
    $@,
    qr/^fatal: Terminal is dumb, but EDITOR unset /,
    'Git complains about lack of smarts and editor'
);

# with git commit it's not fatal
BEGIN { $tests += 3 }
ok( my $cmd = $r->command('commit'), 'git commit' );
isa_ok( $cmd, 'Git::Repository::Command' );
my $error = $cmd->{stderr}->getline;
$cmd->close;
like(
    $error,
    qr/^error: Terminal is dumb, but EDITOR unset/,
    'Git complains about lack of smarts and editor'
);

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

