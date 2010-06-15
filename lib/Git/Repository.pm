package Git::Repository;

use warnings;
use strict;

use Carp;
use File::Spec;
use Cwd qw( cwd abs_path );

use Git::Repository::Command;

our $VERSION = '1.02';

# a few simple accessors
for my $attr (qw( repo_path wc_path wc_subdir )) {
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
    $wc_path = cwd()
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
        if ( !defined $self->{repo_path} ) {
            $self->{repo_path} = $self->run(qw( rev-parse --git-dir ));
            $self->{repo_path}
                = File::Spec->catdir( $self->{wc_path}, $self->{repo_path} )
                if !File::Spec->file_name_is_absolute( $self->{repo_path} );
        }
    }

    # this is a non-bare repository, the work tree is just above the gitdir
    elsif ( $self->run(qw( rev-parse --is-bare-repository )) eq 'false' ) {
        $self->{wc_path} = abs_path(
            File::Spec->catdir( $self->{repo_path}, File::Spec->updir ) );
    }

    # sanity check
    my $gitdir
        = eval { abs_path( $self->run(qw( rev-parse --git-dir )) ) } || '';
    croak "fatal: Not a git repository: $repo_path"
        if $self->{repo_path} ne $gitdir;

    # ensure wc_path is the top-level directory of the working copy
    if ( defined $self->{wc_path} ) {
        my $cdup = Git::Repository->run( qw( rev-parse --show-cdup ),
            { cwd => $self->{wc_path} } );
        if ($cdup) {
            $self->{wc_subdir} = $self->{wc_path};
            $self->{wc_path}
                = abs_path( File::Spec->catdir( $self->{wc_path}, $cdup ) );
        }
    }

    return $self;
}

sub create {
    my ( $class, @args ) = @_;
    my @output = $class->run(@args);
    return $class->new( repository => $1 )
        if $output[0] =~ /^Initialized empty Git repository in (.*)/;
    return;
}

#
# command-related methods
#

# return a Git::Repository::Command object
sub command {
    shift @_ if !ref $_[0];    # remove class name if called as class method
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
        my $exit = $command->{exit};

        # exit codes: 128 => fatal, 129 => usage
        if   ( $exit == 128 || $exit == 129 ) { croak $errput; }
        else                                  { carp $errput; }
    }

    # return the output
    return wantarray ? @output : join "\n", @output;
}

1;

__END__

=head1 NAME

Git::Repository - Perl interface to Git repositories

=head1 SYNOPSIS

    use Git::Repository;

    # start from an existing repository
    $r = Git::Repository->new( repository => $gitdir );

    # start from an existing working copy
    $r = Git::Repository->new( working_copy => $dir );

    # or init our own repository
    $r = Git::Repository->create( init => $dir, ... );

    # or clone from a URL
    $r = Git::Repository->create( clone => $url, ... );

    # run commands
    # - get the full output (no errput)
    $output = $r->run(@cmd);

    # - get the full output as a list of lines (no errput)
    @output = $r->run(@cmd);

    # - obtain a Git::Repository::Command object
    $cmd = $r->command(@cmd);

=head1 DESCRIPTION

C<Git::Repository> is a Perl interface to Git, allowing scripted
interactions with one or more repositories. It's a low-level interface,
allowing to call B<any> Git command, either I<porcelain> or I<plumbing>,
including bidirectional commands such as C<git commit-tree>.

Since it is a low-level interface, it doesn't provide any fancy way to
call Git commands. It is up to the programmer to setup any environment
variables (except C<GIT_DIR> and C<GIT_WORK_TREE>) that the underlying
Git command may need and use.

A C<Git::Repository> object simply provides context to the git commands
being run. Is it possible to call the  C<command()>and C<run()> methods
agains the class itself, and the context (typically I<current working
directory>) will be obtained from the options and environment.

=head1 METHODS

C<Git::Repository> supports the following methods:

=head2 new( %args )

Create a new C<Git::Repository> object, based on an existing Git repository.

Parameters are:

=over 4

=item repository => $gitdir

The location of the git repository (F<.git> directory or equivalent).

=item working_copy => $dir

The location of the git working copy (for a non-bare repository).

=back

At least one of the two parameters is required. Usually, one is enough,
as C<Git::Repository> can work out where the other directory (if any) is.

=head2 create( @cmd )

Runs a repository initializing command (like C<init> or C<clone>) and
returns a C<Git::Repository> object pointing to it. C<@cmd> can contain
a hashref with options (see L<Git::Repository::Command>.

This method runs the command and parses the first line as
C<Initialized empty Git repository in $dir> to find the repository path.

=head2 command( @cmd )

Runs the git sub-command and options, and returns a C<Git::Repository::Command>
object pointing to the sub-process running the command.

As described in the L<Git::Repository::Command> documentation, C<@cmd>
can also hold a hashref containing options for the command.

=head2 run( @cmd )

Runs the command and returns the output as a string in scalar context,
and as a list of lines in list context. Also accepts a hashref of options.

Lines are automatically C<chomp>ed.

If the git command printed anything on stderr, it will be printed as
warnings. If the git sub-process exited with status C<128> (fatal error),
C<run()> will C<die()>.

=head2 repo_path()

Returns the repository path.

=head2 wc_path()

Returns the working copy path.
Used as current working directory by C<Git::Repository::Command>.

=head2 wc_subdir()

Return the (relative) subdirectory path of the working copy.
If defined, will be used as current working directory by
C<Git::Repository::Command>, instead of C<wc_path>.

=head1 HOW-TO

=head2 Create a new repository

    my $r = Git::Repository->create( init => $dir );

=head2 Clone a repository

    my $r = Git::Repository->create( clone => $url => $dir );

=head2 Run a simple command

    $r->run( add => '.' );
    $r->run( commit => '-m', 'my commit message' );

=head2 Process normal and error output

The C<run()> command doesn't capture stderr: it only warns (or dies)
if something was printed on it. To be able to actually capture error
output, C<command()> must be used.

    my $cmd = $r->command( @cmd );
    my @errput = $cmd->{stderr}->getlines();
    $cmd->close;

C<run()> also captures all output at once, which can lead to unecessary
memory consumption when capturing the output of some really verbose
commands.

    my $cmd = $r->command( log => '--pretty=oneline', '--all' );
    my $log = $cmd->{stdout};
    while (<$log>) {
        ...;
    }
    $cmd->close;

Of course, as soon as one starts reading and writing to an external
process' communication handles, a risk of blocking exists.
I<Caveat emptor>.

=head2 Provide input on standard input

Use the C<input> option:

    my $commit = $r->run( 'commit-tree', $tree, '-p', $parent,
        { input => $message } );

=head2 Change the environment of a command

Use the C<env> option:

    $r->run(
        'commit', '-m', 'log message',
        {   env => {
                GIT_COMMITTER_NAME  => 'Git::Repository',
                GIT_COMMITTER_EMAIL => 'book@cpan.org',
            },
        },
    );

See L<Git::Repository::Command> for other available options.

=head1 OTHER PERL GIT WRAPPERS

A number of Perl git wrappers already exist. Why create a new one?

I have a lot of ideas of nice things to do with Git as a tool to
manipulate blobs, trees, and tags, that may or may not reprensent
version history of a project. A lot of those commands can output
huge amounts of data, which I need to be able to process in chunks.
Some of these commands also expect to receive input.

=head2 Git.pm

Git.pm is not on CPAN. It is usually packaged with Git, and installed with
the system Perl libraries. Not being on CPAN makes it harder to install
in any Perl. It makes it harder for a CPAN library to depend on it.

It doesn't allow calling C<git init> or C<git clone>.

The C<command_bidi_pipe> function especially has problems:
L<http://kerneltrap.org/mailarchive/git/2008/10/24/3789584>


=head2 Git::Class

Depends on Moose, which seems an unnecessary dependency for a simple
wrapper around Git.

Although it supports C<git init> and C<git clone>, it is mostly aimed at
porcelain commands, and provides no way to control bidirectional commands
(such as C<git commit-tree>).


=head2 Git::Wrapper

Doesn't support streams or bidirectional commands.


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

