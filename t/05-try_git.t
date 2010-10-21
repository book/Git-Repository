use strict;
use warnings;
use Test::More;
use Git::Repository;
use Cwd qw( cwd );
use File::Spec;

my $cwd = cwd();
my @not_git = ( map ( {
        (   $_,
            File::Spec->catfile( $cwd,              $_ ),
            File::Spec->catfile( File::Spec->updir, $_ )
        )
    } 'this-command-unlikely-to-even-exist-or-be-git' ),
    $^X, '' );

plan tests => 3 * @not_git + 2;

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
    skip 'Default git binary not found in PATH', 2
        if !Git::Repository::Command::_is_git('git');

    my $path_sep = $Config::Config{path_sep} || ';';
    my ($abs_git) = grep {-e}
        map {
        my $path = $_;
        map { File::Spec->catfile( $path, $_ ) }
            map {"git$_"} '', '.cmd', '.exe'
        }
        split /\Q$path_sep\E/, ( $ENV{PATH} || '' );

    diag "Testing _is_git with $abs_git from $cwd";
    ok( Git::Repository::Command::_is_git($abs_git), "_is_git( $abs_git ) " );

    my $rel_git = File::Spec->abs2rel( $abs_git ) ;
    diag "Testing _is_git with $rel_git from $cwd";
    ok( Git::Repository::Command::_is_git($rel_git), "_is_git( $rel_git ) " );
}

