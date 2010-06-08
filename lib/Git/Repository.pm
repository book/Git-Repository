package Git::Repository;

use warnings;
use strict;

use Carp;
use File::Spec;
use Cwd qw( cwd abs_path );

use Git::Repository::Command;

our $VERSION = '0.01';

# a few simple accessors
for my $attr (qw( repo_path wc_path )) {
    no strict 'refs';
    *$attr = sub { $_[0]{$attr} };
}

#
# constructor-related methods
#

sub new {
    my ( $class, %arg ) = @_;

    # setup default options
    my ( $repo_path, $wc_path ) = @arg{qw( repository working_copy )};

    croak "'repository' or 'working_copy' argument required"
        if !defined $repo_path && !defined $wc_path;

    # create the object
    my $self = bless {}, $class;

    if ( defined $repo_path ) {
        croak "directory not found: $repo_path"
            if !-d $repo_path;
        $self->{repo_path} = abs_path($repo_path);
    }

    if ( defined $wc_path ) {
        croak "directory not found: $wc_path"
            if !-d $wc_path;
        $self->{wc_path} = abs_path($wc_path);
        $self->{repo_path}
            = abs_path( $self->run_oneline(qw( rev-parse --git-dir )) )
            if !defined $self->{repo_path};
    }
    elsif (
        $self->run_oneline(qw( rev-parse --is-bare-repository )) eq 'false' )
    {

        # we have a repo_path, try to find the wc_path
        my $updir
            = File::Spec->catdir( $self->{repo_path}, File::Spec->updir );
        if ($self->run_oneline( qw( rev-parse --is-inside-work-tree ),
                { cwd => $updir } ) eq 'true'
            )
        {
            my $cdup = $self->run_oneline(qw(rev-parse --show-cdup));
            $self->{wc_path} = abs_path(
                File::Spec->catdir( $updir, length $cdup ? $cdup : () ) );
        }
    }

    # sanity check
    my $gitdir
        = eval { abs_path( $self->run_oneline(qw( rev-parse --git-dir )) ) }
        || '';
    croak "fatal: Not a git repository: $repo_path"
        if $self->{repo_path} ne $gitdir;

    return $self;
}

sub create {
    my ($class, @args) = @_;
    my @output = $class->run( @args );
    return $class->new( repository => $1 )
        if $output[0] =~ /^Initialized empty Git repository in (.*)/;
    return;
}

#
# command-related methods
#

# return a Git::Repository::Command object
sub command {
    return Git::Repository::Command->new(@_);
}

# run a command, returns the output
# die with errput if any
sub run {
    my ( $self, @cmd ) = @_;

    # run the command (pass the instance if called as an instance method)
    my $command
        = Git::Repository::Command->new( ref $self ? $self : (), @cmd );

    # get output / errput
    my ( $stdout, $stderr ) = @{$command}{qw(stdout stderr)};
    chomp( my @output = <$stdout> );
    chomp( my @errput = <$stderr> );

    # done with it
    $command->close;

    # something's wrong
    if (@errput) {
        my $errput = join "\n", @errput;
        if   ( $command->{exit} == 128 ) { croak $errput; }
        else                             { carp $errput; }
    }

    # return the output
    return wantarray ? @output : join "\n", @output;
}

# run a command, return the first line of output
sub run_oneline { return ( shift->run(@_) )[0]; }

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

