package Git::Repository;

use warnings;
use strict;

our $VERSION = '0.01';

1;

__END__

=head1 NAME

Git::Repository - Perl wrapper around git

=head1 SYNOPSIS

    use Git::Repository;

    my $r = Git::Repository->new();
    # new object from a working copy
    my $r = Git::Repository->new( working_copy => $wc_path );

    # new object from a repository
    my $r = Git::Repository->new( repository => $repo_path );

    # new object from both
    my $r = Git::Repository->new(
        repository   => $repo_path,
        working_copy => $wc_path
    );

    # run a command
    my $output = $r->command( @cmd );

=head1 DESCRIPTION

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-git-repository at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Git-Repository>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Git::Repository


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Git-Repository>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Git-Repository>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Git-Repository>

=item * Search CPAN

L<http://search.cpan.org/dist/Git-Repository>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

