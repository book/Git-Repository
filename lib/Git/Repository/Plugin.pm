package Git::Repository::Plugin;

use strict;
use warnings;
use 5.006;
use Carp;

sub install {
    my ( $class, @keywords ) = @_;
    no strict 'refs';
    my %keyword = map { $_ => 1 } my @all_keywords = $class->_keywords;
    @keywords = @all_keywords if !@keywords;
    @keywords = grep {
        !( !exists $keyword{$_} and carp "Unknown keyword '$_' in $class" )
    } @keywords;
    carp "No keywords installed from $class" if !@keywords;
    *{"Git::Repository::$_"} = \&{"$class\::$_"} for @keywords;
}

sub _keywords {
    my ($class) = @_;
    no strict 'refs';
    carp "Use of \@KEYWORDS by $class is deprecated";
    return @{"$class\::KEYWORDS"};
}

1;

# ABSTRACT: Base class for Git::Repository plugins

=pod

=head1 SYNOPSIS

    package Git::Repository::Plugin::Hello;

    use Git::Repository::Plugin;
    our @ISA = qw( Git::Repository::Plugin );

    sub _keywords { return qw( hello hello_gitdir ) }

    sub hello        { return "Hello, git world!\n"; }
    sub hello_gitdir { return "Hello, " . $_[0]->git_dir . "!\n"; }

    1;

=head1 DESCRIPTION

L<Git::Repository::Plugin> allows one to define new methods for
L<Git::Repository>, that will be imported in the L<Git::Repository>
namespace.

The L<SYNOPSIS> provides a full example.

The documentation of L<Git::Repository> describes how to load plugins
with all the methods they provide, or only a selection of them.

=head1 METHODS

L<Git::Repository::Plugin> provides a single method:

=head2 install( @keywords )

Install all keywords provided in the L<Git::Repository> namespace.

If called with an empty list, will install all available keywords.

=head1 SUBCLASSING

When creating a plugin, the new keywords that are added by the plugin
to L<Git::Repository> must be returned by a C<_keywords()> method.

=head1 ACKNOWLEDGEMENTS

Thanks to Todd Rinalo, who wanted to add more methods to
L<Git::Repository>, which made me look for a solution that would preserve
the minimalism of L<Git::Repository>.

After a not-so-good design using @ISA (so L<Git::Repository> would
I<inherit> the extra methods), further discussions with Aristotle
Pagaltzis and a quick peek at L<Dancer>'s plugin management helped me
come up with the current design. Thank you Aristotle and the L<Dancer>
team.

Further improvements to the plugin system proposed by Aristotle Pagaltzis.

=cut
