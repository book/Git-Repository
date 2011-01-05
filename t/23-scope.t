use strict;
use warnings;
use Test::More;
use Test::Git;
use Git::Repository;

has_git();

my $version = Git::Repository->version;

plan tests => 1;

TODO: {
    local $TODO = 'Scope issues with Git::Repository::Command';
    my $fh = Git::Repository::Command->new('--version')->stdout;
    my $v  = <$fh>;
    is( $v, $version );
}

