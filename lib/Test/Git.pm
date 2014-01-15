package Test::Git;

use strict;
use warnings;

use Exporter;
use Test::Builder;
use Git::Repository;    # 1.15
use File::Temp qw( tempdir );
use File::Spec::Functions qw( catdir );
use Cwd qw( cwd );
use Carp;

our @ISA     = qw( Exporter );
our @EXPORT  = qw( has_git test_repository );

my $Test = Test::Builder->new();

sub has_git {
    my ( $version, @options ) = ( ( grep !ref, @_ )[0], grep ref, @_ );

    # check some git is present
    $Test->skip_all('Default git binary not found in PATH')
        if !Git::Repository::Command::_is_git('git');

    # check it's at least some minimum version
    my $git_version = Git::Repository->version(@options);
    $Test->skip_all(
        "Test script requires git >= $version (this is only $git_version)")
        if $version && Git::Repository->version_lt( $version, @options );
}

sub test_repository {
    my %args = @_;

    croak "Can't use both 'init' and 'clone' paramaters"
        if exists $args{init} && exists $args{clone};

    # setup some default values
    my $temp = $args{temp} || [ CLEANUP => 1 ];    # File::Temp options
    my $init = $args{init} || [];                  # git init options
    my $opts = $args{git}  || {};                  # Git::Repository options
    my $safe = { %$opts, fatal => [] };            # ignore 'fatal' settings
    my $clone = $args{clone};                      # git clone options

    # git init requires at least Git 1.5.0
    my $git_version = Git::Repository->version($safe);
    croak "test_repository() requires git >= 1.5.0.rc1 (this is only $git_version)"
      if Git::Repository->version_lt( '1.5.0.rc1', $safe );

    # create a temporary directory to host our repository
    my $dir = tempdir(@$temp);
    my $cwd = { cwd => $dir };    # option to chdir there

    # create the git repository there
    my @cmd = $clone ? ( clone => @$clone ) : ( init => @$init );
    Git::Repository->run( @cmd, '.', $safe, $cwd );

    # create the Git::Repository object
    my $gitdir = Git::Repository->run( qw( rev-parse --git-dir ), $cwd );
    return Git::Repository->new( git_dir => catdir( $dir, $gitdir ), $opts );
}

1;

# ABSTRACT: Helper functions for test scripts using Git

=pod

=head1 SYNOPSIS

    use Test::More;
    use Test::Git;
    
    # check there is a git binary available, or skip all
    has_git();
    
    # check there is a minimum version of git available, or skip all
    has_git( '1.6.5' );
    
    # check the git we want to test has a minimum version, or skip all
    has_git( '1.6.5', { git => '/path/to/alternative/git' } );
    
    # normal plan
    plan tests => 2;
    
    # create a new, empty repository in a temporary location
    # and return a Git::Repository object
    my $r = test_repository();
    
    # clone an existing repository in a temporary location
    # and return a Git::Repository object
    my $c = test_repository( clone => [ $url ] );

    # run some tests on the repository
    ...

=head1 DESCRIPTION

L<Test::Git> provides a number of helpful functions when running test
scripts that require the creation and management of a Git repository.


=head1 EXPORTED FUNCTIONS

=head2 has_git( $version, \%options )

Checks if there is a git binary available, or skips all tests.

If the optional L<$version> argument is provided, also checks if the
available git binary has a version greater or equal to C<$version>.

This function also accepts an option hash of the same kind as those
accepted by L<Git::Repository> and L<Git::Repository::Command>.

This function must be called before C<plan()>, as it performs a B<skip_all>
if requirements are not met.


=head2 test_repository( %options )

Creates a new empty git repository in a temporary location, and returns
a L<Git::Repository> object pointing to it.

This function takes options as a hash. Each key will influence a
different part of the creation process.

The keys are:

=over 4

=item temp

Array reference containing parameters to L<File::Temp> C<tempdir> function.

Default: C<[ CLEANUP => 1 ]>

=item init

Array reference containing parameters to C<git init>.
Must not contain the target directory parameter, which is provided
by C<test_repository()> (via L<File::Temp>).

Default: C<[]>

=item clone

Array reference containing parameters to C<git clone>.
Must not contain the target directory parameter, which is provided
by C<test_repository()> (via L<File::Temp>).

Default: C<[]>

Note that C<clone> and C<init> are mutually exclusive and that
C<test_repository()> will croak if both are provided.

=item git

Hash reference containing options for L<Git::Repository>.

Default: C<{}>

=back

This call is the equivalent of the default call with no options:

    test_repository(
        temp => [ CLEANUP => 1 ],    # File::Temp::tempdir options
        init => [],                  # git init options
        git  => {},                  # Git::Repository options
    );

To create a I<bare> repository:

    test_repository( init => [ '--bare' ] );

To leave the repository in its location after the end of the test:

    test_repository( temp => [ CLEANUP => 0 ] );

Note that since C<test_repository()> uses C<git init> to create the test
repository, it requires at least Git version C<1.5.0.rc1>.

=head1 COPYRIGHT

Copyright 2010-2013 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
