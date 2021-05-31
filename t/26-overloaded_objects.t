# Test that we work with stringified path objects like Path::Class.
use strict;
use warnings;

use Test::More;
use Test::Requires::Git;
use Test::Git;
use File::Temp qw(tempdir);
use Cwd qw(realpath);

test_requires_git '1.6.5';

plan tests => 3;

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
$ENV{LC_ALL} = 'C';
$ENV{GIT_CONFIG_NOSYSTEM} = 1;
delete $ENV{XDG_CONFIG_HOME};
delete $ENV{HOME};

# A class with stringification to test with.
{
    package My::Dir;
    use overload
      '""'       => sub { $_[0]->{path} },
      "fallback" => 1;

    sub new {
        my $class = shift;
        my $path = shift;
        return bless { path => $path }, $class;
    }
}

# a quiet git init:
my @init = qw( init );
push @init, '-q' if Git::Repository->version_ge('1.5.2.3');

my $repo_dir = My::Dir->new( tempdir( CLEANUP => 1 ) );
note( Git::Repository->run( @init, $repo_dir ) );
ok -d "$repo_dir/.git", "git repo initialized";
my $r = eval { Git::Repository->new( work_tree => $repo_dir ); };
isa_ok $r, "Git::Repository";
is $r->work_tree, realpath($repo_dir), $repo_dir;
