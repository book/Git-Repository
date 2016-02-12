package Git::Repository::Util;

use strict;
use warnings;
use Exporter;

use Scalar::Util qw( looks_like_number );
use namespace::clean;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
  _version_eq _version_gt
  cmp_git
);

# A few versions have two tags, or non-standard numbering:
# - the left-hand side is what `git --version` reports
# - the right-hand side is an internal canonical name
my %version_alias = (
    '0.99.7a' => '0.99.7.1',
    '0.99.7b' => '0.99.7.2',
    '0.99.7c' => '0.99.7.3',
    '0.99.7d' => '0.99.7.4',
    '0.99.8a' => '0.99.8.1',
    '0.99.8b' => '0.99.8.2',
    '0.99.8c' => '0.99.8.3',
    '0.99.8d' => '0.99.8.4',
    '0.99.8e' => '0.99.8.5',
    '0.99.8f' => '0.99.8.6',
    '0.99.8g' => '0.99.8.7',
    '0.99.9a' => '0.99.9.1',
    '0.99.9b' => '0.99.9.2',
    '0.99.9c' => '0.99.9.3',
    '0.99.9d' => '0.99.9.4',
    '0.99.9e' => '0.99.9.5',
    '0.99.9f' => '0.99.9.6',
    '0.99.9g' => '0.99.9.7',
    '0.99.9h' => '0.99.9.8',     # 1.0.rc1
    '1.0.rc1' => '0.99.9.8',
    '0.99.9i' => '0.99.9.9',     # 1.0.rc2
    '1.0.rc2' => '0.99.9.9',
    '0.99.9j' => '0.99.9.10',    # 1.0.rc3
    '1.0.rc3' => '0.99.9.10',
    '0.99.9k' => '0.99.9.11',
    '0.99.9l' => '1.0.rc4',
    '0.99.9m' => '1.0.rc5',
    '0.99.9n' => '1.0.rc6',
    '1.0.0a'  => '1.0.1',
    '1.0.0b'  => '1.0.2',
);

sub _version_eq {
    my ( $v1, $v2 ) = @_;
    $_ = $version_alias{$_} || $_ for $v1, $v2;    # aliases
    return $v1 eq $v2;
}

sub _version_gt {
    my ( $v1, $v2 ) = @_;
    $_ = $version_alias{$_} || $_ for $v1, $v2;    # aliases

    my @v1 = split /\./, $v1;
    my @v2 = split /\./, $v2;

    # pick up any dev parts
    my @dev1 = splice @v1, -2 if substr( $v1[-1], 0, 1 ) eq 'g';
    my @dev2 = splice @v2, -2 if substr( $v2[-1], 0, 1 ) eq 'g';

    # skip to the first difference
    shift @v1, shift @v2 while @v1 && @v2 && $v1[0] eq $v2[0];

    # we're comparing dev versions with the same ancestor
    if ( !@v1 && !@v2 ) {
        @v1 = @dev1;
        @v2 = @dev2;
    }

    # prepare the bits to compare
    ( $v1, $v2 ) = ( $v1[0] || 0, $v2[0] || 0 );

    # rcX is less than any number
    return looks_like_number($v1)
             ? looks_like_number($v2) ? $v1 > $v2 : 1
             : looks_like_number($v2) ? ''        : $v1 gt $v2;
}

sub cmp_git ($$) {
    return _version_gt( $_[0], $_[1] ) || -_version_gt( $_[1], $_[0] );
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
