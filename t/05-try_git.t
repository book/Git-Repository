use strict;
use warnings;
use Test::More;
use Git::Repository;
use Cwd qw( cwd );
use File::Spec;
use File::Temp qw( tempdir );
use File::Path qw( mkpath rmtree );
use Config;

my $cwd = cwd();
my @not_git = ( map ( {
        (   $_,
            File::Spec->catfile( $cwd,              $_ ),
            File::Spec->catfile( File::Spec->updir, $_ )
        )
    } 'this-command-unlikely-to-even-exist-or-be-git' ),
    $^X, '', 't' );

plan tests => 3 * @not_git + 2 + 8;

for my $not_git (@not_git) {

    # special case: '' means test removing $ENV{PATH}
    local $ENV{PATH} if ! $not_git;
    $not_git ||= 'git';

    # direct test
    ok( !Git::Repository::Command::_is_git($not_git),
        "_is_git( $not_git ) fails with bad git command"
    );

    # as an option
    ok( !eval {
            Git::Repository->run( '--version', { git => $not_git } );
            1;
        },
        'run() fails with bad git command'
    );
    like(
        $@,
        qr/^git binary '.*?' not available or broken/,
        '... with expected error message'
    );
}

# more tests if git is available
SKIP:
{
    skip 'Default git binary not found in PATH', 10
        if !Git::Repository::Command::_is_git('git');

    my $path_sep = $Config::Config{path_sep} || ';';
    my ($abs_git) = grep { -x && !-d }
        map {
        my $path = $_;
        map { File::Spec->catfile( $path, $_ ) }
            map {"git$_"} '', '.cmd', '.exe'
        }
        split /\Q$path_sep\E/, ( $ENV{PATH} || '' );

    diag "Testing _is_git with $abs_git from $cwd";
    ok( Git::Repository::Command::_is_git($abs_git), "_is_git( $abs_git ) " );

    my $rel_git = File::Spec->abs2rel($abs_git);
    diag "Testing _is_git with $rel_git from $cwd";
    ok( Git::Repository::Command::_is_git($rel_git), "_is_git( $rel_git ) " );

    # tests with symlinks
SKIP:
    {
        my $osname = "@Config{qw( osname osvers archname archname64 )}";
        skip "symlink() not supported on this $osname", 8
            if !eval { symlink( '', '' ); 1 };

        # a place to experiment
        my $dir = tempdir( DIR => 't', CLEANUP => 1 );
        my $target = File::Spec->catfile( $dir, 'target' );
        my $link   = File::Spec->catfile( $dir, 'link' );
        my $real   = File::Spec->catfile( $dir, 'real' );
        $ENV{PATH} = $dir;

        # symlink pointing to the real thing
        # (not using 'link', because the _is_git() cache is not very smart
        # with links that change of target while the program is running)
        ok( symlink( $abs_git, $real ), "real -> $abs_git" );
        ok( Git::Repository::Command::_is_git('real'), 'symlink to git' );
        unlink $link;

        # create a dangling symlink
        open my $fh, '>', $target or diag "Can't open $target: $!";
        close $fh;
        chmod 0777, $target;
        ok( symlink( 'target', $link ), 'link -> target' );
        unlink $target;
        ok( !Git::Repository::Command::_is_git('link'), 'dangling symlink' );
        unlink $link;

        # symlink pointing to a directory
        mkpath $target;
        ok( symlink( 'target', $link ), 'link -> target/' );
        ok( !Git::Repository::Command::_is_git('link'), 'symlink to a dir' );

        # secondary target, working, but later in the PATH
        my $subdir = File::Spec->catdir( $dir, 'sub' );
        mkpath $subdir;
        $ENV{PATH} = join $path_sep, $dir, $subdir;
        ok( symlink( $abs_git, File::Spec->catfile( $subdir, 'link' ) ),
            "sub/link -> $abs_git " );
        ok( Git::Repository::Command::_is_git('link'), 'symlink to git' );
    }
}

