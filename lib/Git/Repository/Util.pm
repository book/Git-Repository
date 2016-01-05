package Git::Repository::Util;

use strict;
use warnings;
use Exporter;
use Git::Repository;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw( cmp_git );

sub cmp_git ($$) {
    return Git::Repository::_version_gt( $_[0], $_[1] )
      || -Git::Repository::_version_gt( $_[1], $_[0] );
}

1;

__END__

=head1 NAME

Git::Repository::Util - A selection of general-utility Git-related subroutines

=head1 SYNOPSIS

    use Git::Repository::Util qw( cmp_git );

    # result: 1.2.3 1.7.0.rc0 1.7.4.rc1 1.8.3.4 1.9.3 2.0.0.rc2 2.0.3 2.3.0.rc1
    my @versions = sort cmp_git qw(
      1.7.4.rc1 1.9.3 1.7.0.rc0 2.0.0.rc2 1.2.3 1.8.3.4 2.3.0.rc1 2.0.3
    );

=head1 DESCRIPTION

L<Git::Repository::Util> contains a selection of subroutines that make
dealing with Git-related things (like versions) a little bit easier.

By default L<Git::Repository::Util> does not export any subroutines.

=head1 AVAILABLE FUNCTIONS

=head2 cmp_git

    @versions = sort cmp_git @versions;

A Git-aware version of the C<cmp> operator.

=head1 COPYRIGHT

Copyright 2016 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
