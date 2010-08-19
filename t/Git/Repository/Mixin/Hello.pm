package Git::Repository::Mixin::Hello;

use strict;
use warnings;

sub hello { return "Hello, git world!\n" }

sub hello_gitdir { return "Hello, " . $_[0]->git_dir . "!\n"; }

1;

