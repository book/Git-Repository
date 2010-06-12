package Git::Repository::Command;

use strict;
use warnings;
use Carp;
use Cwd qw( cwd );
use IPC::Open3 qw( open3 );
use Scalar::Util qw( blessed );
use File::Spec;
use IO::Handle;
use Config;

# CAN I HAS GIT?
sub _has_git {
    my ($binary) = @_;

    # compute a list of candidate files (if relative, look in PATH)
    # if we can't find any, we're done
    my $path_sep = $Config::Config{path_sep} || ';';
    return
        if !grep {-x} File::Spec->file_name_is_absolute($binary)
            || ( File::Spec->splitpath($binary) )[1]
        ? $binary
        : map { File::Spec->catfile( $_, $binary ) }
            split /\Q$path_sep\E/, ( $ENV{PATH} || '' );

    # try to run it
    my ( $in, $out );
    my $err = Symbol::gensym;
    my $pid = eval { open3( $in, $out, $err, $binary, '--version' ); };
    waitpid $pid, 0;
    my $version = <$out>;

    # does it really look like git?
    return $version =~ /^git version \d/;
}

my %binary;    # cache calls to _has_git

sub new {
    my ( $class, @cmd ) = @_;

    # split the args
    my ($r, $o);
    @cmd = grep {
     !( ref eq 'HASH'                            ? $o ||= $_
      : blessed $_ && $_->isa('Git::Repository') ? $r ||= $_
      :                                          0 )
    } @cmd;

    # get and check the git command
    my $git = defined $o->{git} ? $o->{git} : 'git';
    $binary{$git} = _has_git($git)
        if !exists $binary{$git};

    croak "git binary '$git' not available or broken"
        if !$binary{$git};

    # get some useful paths
    my ( $repo_path, $wc_path ) = ( $r->repo_path, $r->wc_path)
        if $r;

    # setup %ENV (no blocks to preserve local)
    local $ENV{GIT_DIR} = $repo_path
        if defined $repo_path;
    local $ENV{GIT_WORK_TREE} = $wc_path
        if defined $repo_path && defined $wc_path;

    # chdir to the expected directory
    my $orig = cwd;
    my $dest
        = defined $o->{cwd}                   ? $o->{cwd}
        : defined $wc_path && length $wc_path ? $wc_path
        :                                       undef;
    if ( defined $dest ) {
        chdir $dest or croak "Can't chdir to $dest: $!";
    }

    # turn us into a dumb terminal
    local $ENV{TERM};
    delete $ENV{TERM};

    # update the environment (no block to preserve local)
    local @ENV{ keys %{ $o->{env} } } = values %{ $o->{env} }
        if exists $o->{env};

    # start the command
    my ( $in, $out, $err );
    $err = Symbol::gensym;
    my $pid = eval { open3( $in, $out, $err, $git, @cmd ); };

    # FIXME - better check open3 error conditions
    croak $@ if !defined $pid;

    # some input was provided
    if ( exists $o->{input} ) {
        print {$in} $o->{input};
        $in->close;
    }

    # chdir back to origin
    if ( defined $dest ) {
        chdir $orig or croak "Can't chdir back to $orig: $!";
    }

    # create the object
    return bless {
        pid    => $pid,
        stdin  => $in,
        stdout => $out,
        stderr => $err,
    }, $class;
}

sub close {
    my ($self) = @_;

    # close all pipes
    my ( $in, $out, $err ) = @{$self}{qw( stdin stdout stderr )};
    $in->opened  and $in->close  || carp "error closing stdin: $!";
    $out->opened and $out->close || carp "error closing stdout: $!";
    $err->opened and $err->close || carp "error closing stderr: $!";

    # and wait for the child
    waitpid $self->{pid}, 0;

    # check $?
    @{$self}{qw( exit signal core )} = ( $? >> 8, $? & 127, $? & 128 );

    return $self;
}

sub DESTROY {
    my ($self) = @_;
    $self->close if !exists $self->{exit};
}

1;

__END__

=head1 NAME

Git::Repository::Command - Command objects for running git

=head1 SYNOPSIS

    use Git::Repository::Command;

    # invoke an external git command, and return an object
    $cmd = Git::Repository::Command->(@cmd);

    # a Git::Repository object can provide more context
    $cmd = Git::Repository::Command->( $r, @cmd );

    # options can be passed as a hashref
    $cmd = Git::Repository::Command->( $r, @cmd, \%option );

    # $cmd is basically a hash
    $cmd->{stdin};     # filehandle to the process' stdin (write)
    $cmd->{stdout};    # filehandle to the process' stdout (read)
    $cmd->{stderr};    # filehandle to the process' stdout (read)
    $cmd->{pid};       # pid of the child process

    # done!
    $cmd->close();

    # exit information
    $cmd->{exit};      # exit status
    $cmd->{signal};    # signal
    $cmd->{core};      # core dumped? (boolean)

=head1 DESCRIPTION

C<Git::Repository::Command> is a class that actually launches a B<git>
commands, allowing to interact with it through its C<STDIN>, C<STDOUT>
and C<STDERR>.

This module is meant to be invoked through C<Git::Repository>.

=head1 METHODS

C<Git::Repository::Command> supports the following methods:

=head2 new( @cmd )

Runs a B<git> command with the parameters in C<@cmd>.

If C<@cmd> contains a C<Git::Repository> object, it is used to provide
context to the B<git> command.

If C<@cmd> contains a hash reference, it is taken as an I<option> hash.
The recognized keys are:

=over 4

=item C<git>

The actual git binary to run. By default, it is just C<git>.

=item cwd

The I<current working directory> in which the git command will be run.

=item C<env>

A hashref containing key / values to add to the git command environment.

=item C<input>

A string that is send to the git command standard input, which is then closed.

=back

The hash returned by C<new()> has the following keys:

    $cmd->{stdin};     # filehandle to the process' stdin (write)
    $cmd->{stdout};    # filehandle to the process' stdout (read)
    $cmd->{stderr};    # filehandle to the process' stdout (read)
    $cmd->{pid};       # pid of the child process

=head2 close()

Close all pipes to the child process, and collects exit status, etc.

This adds the following keys to the hash:

    $cmd->{exit};      # exit status
    $cmd->{signal};    # signal
    $cmd->{core};      # core dumped? (boolean)

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

