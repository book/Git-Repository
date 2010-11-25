package Test::Git;

use strict;
use warnings;

use Exporter;
use Test::Builder;
use Git::Repository 1.14;

our $VERSION = '1.00';
our @ISA     = qw( Exporter );
our @EXPORT  = qw( has_git );

my $Test = Test::Builder->new();

sub has_git {
    my ($version) = @_;

    # check some git is present
    $Test->skip_all('Default git binary not found in PATH')
        if !Git::Repository::Command::_is_git('git');

    # check it's at least some minimum version
    my $git_version = Git::Repository->version;
    $Test->skip_all(
        "Test script requires git >= $version (this is only $git_version)" )
        if $version && Git::Repository->version_lt($version);
}

1;

__END__

=head1 NAME

Test::Git - Helper functions for test scripts using Git

=head1 SYNOPSIS

    use Test::More;
    use Test::Git;
    
    # check there is a git binary available, or skip all
    has_git();
    
    # check there is a minimum version of git available, or skip all
    has_git( '1.6.5' );
    
    # normal plan
    plan tests => 2;
    
    # run some tests using git
    ...

=head1 DESCRIPTION

C<Test::Git> provides a number of helpful functions when running test
scripts that require the creation and management of a Git repository.


=head1 EXPORTED FUNCTIONS

=head2 has_git( $version )

Checks if there is a git binary available, or skips all tests.

If the optionanl C<$version> argument is provided, also checks if the
available git binary has a version greater or equal to C<$version>.

This function must be called before C<plan()>.


=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

