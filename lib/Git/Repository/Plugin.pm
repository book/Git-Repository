package Git::Repository::Plugin;

use strict;
use warnings;

sub install {
    my ( $class, @names ) = @_;
    no strict 'refs';
    @names = @{"$class\::KEYWORDS"} if !@names;
    *{"Git::Repository::$_"} = \&{"$class\::$_"} for @names;
}

1;

__END__

=head1 NAME

Git::Repository::Plugin - Base class for Git::Repository plugins

=head1 SYNOPSIS

    package Git::Repository::Plugin::Hello;

    use Git::Repository::Plugin;
    our @ISA      = qw( Git::Repository::Plugin );
    our @KEYWORDS = qw( hello hello_gitdir );

    sub hello        { return "Hello, git world!\n"; }
    sub hello_gitdir { return "Hello, " . $_[0]->git_dir . "!\n"; }

    1;

=head1 DESCRIPTION

C<Git::Repository> intentionally has only few methods.
The idea is to provide a lightweight wrapper around git, to be used to
create interesting tools based on Git.

However, people will want to add extra functionality to
C<Git::Repository>, the obvious example being a C<log()> method that
returns simple objects with useful attributes.

A hypothetical C<Git::Repository::Plugin::Hello> module could be written
like in the L<SYNOPSIS>.  And the methods would be loaded and used
as follows:

    use Git::Repository qw( Hello );

    my $r = Git::Repository->new();
    print $r->hello();
    print $r->hello_gitdir();

It's possible to load only a selection of methods from the plugin:

    use Git::Repository [ Hello => 'hello' ];

    my $r = Git::Repository->new();
    print $r->hello();
    print $r->hello_gitdir();    # dies

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 ACKNOWLEDGEMENTS

Thanks to Todd Rinalo, who wanted to add more methods to
C<Git::Repository>, which made me look for a solution that would preserve
the minimalism of C<Git::Repository>.

After a not-so-good design using @ISA (so C<Git::Repository> would
I<inherit> the extra methods), further discussions with Aristotle
Pagaltzis and a quick peek at Dancer's plugin management helped me
come up with the current design. Thank you Aristotle and the Dancer
team.

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK).

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

