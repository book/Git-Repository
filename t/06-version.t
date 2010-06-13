use strict;
use warnings;
use Test::More;
use Git::Repository;

plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_has_git('git');

plan tests => 1;

# get the git version
my $version = Git::Repository->run( '--version' );
like( $version, qr/^git version \d/, 'git --version' );

diag $version;

