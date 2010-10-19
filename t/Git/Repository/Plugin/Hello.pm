package Git::Repository::Plugin::Hello;

use strict;
use warnings;

use Git::Repository::Plugin;
our @ISA      = qw( Git::Repository::Plugin );
sub _keywords { qw( hello hello_gitdir ) }

sub hello { return "Hello, git world!\n" }

sub hello_gitdir { return "Hello, " . $_[0]->git_dir . "!\n"; }

1;

