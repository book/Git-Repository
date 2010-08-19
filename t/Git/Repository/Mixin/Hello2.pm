package Git::Repository::Mixin::Hello2;

use strict;
use warnings;

sub hello { return "Hello, world!\n" }

sub hello_worktree { return "Hello, " . $_[0]->work_tree . "!\n"; }

1;

