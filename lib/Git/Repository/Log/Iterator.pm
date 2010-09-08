package Git::Repository::Log::Iterator;

use strict;
use warnings;
use Carp;

use Git::Repository;
use Git::Repository::Command;
use Git::Repository::Log;

our $VERSION = '1.00';

sub new {
    my ( $class, @cmd ) = @_;

    # enforce the format
    @cmd = ( 'log', map { $_ eq '--' ? ( '--pretty=raw', $_ ) : $_ } @cmd,
        '--' );
    pop @cmd;

    # run the command (@cmd may hold a Git::Repository instance)
    bless { cmd => Git::Repository::Command->new( @cmd ) }, $class;
}

sub next {
    my ($self) = @_;
    my $fh = $self->{cmd}->stdout;

    # get records
    my @records = ( $self->{record} || () );
    {
        local $/ = "\n\n";
        while (<$fh>) {
            $self->{record} = $_, last if /\Acommit / && @records;
            chomp;
            push @records, $_;
        }
    }

    # EOF
    return if !@records;

    # the first two records are always the same, with --pretty=raw
    my ( $header, $message, $extra ) = ( @records, '' );
    my @headers = map { chomp; split / /, $_, 2 } split /^/m, $header;

    # create the log object
    return Git::Repository::Log->new(
        @headers,
        message => $message,
        extra   => $extra,
    );
}

1;

__END__

=head1 NAME

Git::Repository::Log::Iterator - Split a git log stream into records

=head1 SYNOPSIS

    use Git::Repository::Log::Iterator;

    # use a default Git::Repository context
    my $iter = Git::Repository::Log::Iterator->new('HEAD~10..');

    # or provide an existing instance
    my $iter = Git::Repository::Log::Iterator->new( $r, 'HEAD~10..' );

    # get the next log record
    while ( my $log = $iter->next ) {
        ...;
    }

=head1 DESCRIPTION

C<Git::Repository::Log::Iterator> initiates a B<git log> command
from a list of paramaters and parses its output to produce
C<Git::Repository::Log> objects represening each log item.

=head1 METHODS

=head2 new( @args )

Create a new B<git log> stream from the parameter list in C<@args>
and return a iterator on it.

=head2 next()

Return the next log item as a C<Git::Repository::Log> object,
or nothing if the stream has ended.

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

