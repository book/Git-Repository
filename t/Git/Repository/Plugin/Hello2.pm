package Git::Repository::Plugin::Hello2;

use strict;
use warnings;

use Git::Repository::Plugin;
our @ISA      = qw( Git::Repository::Plugin );
our @KEYWORDS = qw( hello hello_worktree );

sub hello { return "Hello, world!\n" }

sub hello_worktree { return "Hello, " . $_[0]->work_tree . "!\n"; }

1;

