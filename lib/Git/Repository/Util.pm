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
#
# We turn versions into strings, so we can use the fast `eq` and `gt`.
# The 6 elements are integers padded with 0:
# - the 4 parts of the dotted version (padded with as many .0 as needed)
# - '.000' if not an RC, or '-xxx' if an RC (- sorts before . in ascii)
# - the number of commits since the previous tag (for dev versions)
#
# The special cases are pre-computed below, the rest is computed as needed.
my %version_alias = (
    '0.99.7a' => '000.099.007.001.000.000',
    '0.99.7b' => '000.099.007.002.000.000',
    '0.99.7c' => '000.099.007.003.000.000',
    '0.99.7d' => '000.099.007.004.000.000',
    '0.99.8a' => '000.099.008.001.000.000',
    '0.99.8b' => '000.099.008.002.000.000',
    '0.99.8c' => '000.099.008.003.000.000',
    '0.99.8d' => '000.099.008.004.000.000',
    '0.99.8e' => '000.099.008.005.000.000',
    '0.99.8f' => '000.099.008.006.000.000',
    '0.99.8g' => '000.099.008.007.000.000',
    '0.99.9a' => '000.099.009.001.000.000',
    '0.99.9b' => '000.099.009.002.000.000',
    '0.99.9c' => '000.099.009.003.000.000',
    '0.99.9d' => '000.099.009.004.000.000',
    '0.99.9e' => '000.099.009.005.000.000',
    '0.99.9f' => '000.099.009.006.000.000',
    '0.99.9g' => '000.099.009.007.000.000',
    '0.99.9h' => '000.099.009.008.000.000',    # 1.0.rc1
    '1.0.rc1' => '000.099.009.008.000.000',
    '1.0rc1'  => '000.099.009.008.000.000',
    '0.99.9i' => '000.099.009.009.000.000',    # 1.0.rc2
    '1.0.rc2' => '000.099.009.009.000.000',
    '1.0rc2'  => '000.099.009.009.000.000',
    '0.99.9j' => '000.099.009.010.000.000',    # 1.0.rc3
    '1.0.rc3' => '000.099.009.010.000.000',
    '1.0rc3'  => '000.099.009.010.000.000',
    '0.99.9k' => '000.099.009.011.000.000',
    '0.99.9l' => '000.099.009.012.000.000',    # 1.0.rc4
    '1.0.rc4' => '000.099.009.012.000.000',
    '1.0rc4'  => '000.099.009.012.000.000',
    '0.99.9m' => '000.099.009.013.000.000',    # 1.0.rc5
    '1.0.rc5' => '000.099.009.013.000.000',
    '1.0rc5'  => '000.099.009.013.000.000',
    '0.99.9n' => '000.099.009.014.000.000',    # 1.0.rc6
    '1.0.rc6' => '000.099.009.014.000.000',
    '1.0rc6'  => '000.099.009.014.000.000',
    '1.0.0a'  => '001.000.001.000.000.000',
    '1.0.0b'  => '001.000.002.000.000.000',
);

sub _normalize {
    my @v = split /\./, $_[0];
    my ( $r, $c ) = ( 0, 0 );

    # commit count since the previous tag
    ($c) = splice @v, -2 if substr( $v[-1], 0, 1 ) eq 'g';

    # release candidate number
    ($r) = splice @v, -1 if substr( $v[-1], 0, 2 ) eq 'rc';
    $r &&= do { $r =~ s/rc//; sprintf '-%03d', $r };

    join( '.', map sprintf( '%03d', $_ ), ( @v, 0, 0, 0 )[ 0 .. 3 ] )
      . ( $r || '.000' )
      . sprintf( '.%03d', $c );
}

sub _version_eq {
    my ( $v1, $v2 ) = @_;
    $_ = $version_alias{$_} ||= _normalize( $_ ) for $v1, $v2;    # aliases
    return $v1 eq $v2;
}

sub _version_gt {
    my ( $v1, $v2 ) = @_;
    $_ = $version_alias{$_} ||= _normalize( $_ ) for $v1, $v2;    # aliases
    return $v1 gt $v2;
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
