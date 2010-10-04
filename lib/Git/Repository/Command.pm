package Git::Repository::Command;

use strict;
use warnings;
use 5.006;

use Carp;
use Cwd qw( cwd );
use IO::Handle;
use IPC::Open3 qw( open3 );
use Scalar::Util qw( blessed );
use File::Spec;
use Config;

our $VERSION = '1.07';

# a few simple accessors
for my $attr (qw( pid stdin stdout stderr exit signal core )) {
    no strict 'refs';
    *$attr = sub { return $_[0]{$attr} };
}
for my $attr (qw( cmdline )) {
    no strict 'refs';
    *$attr = sub { return @{ $_[0]{$attr} } };
}

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

    # keep changes to the environment local
    local %ENV = %ENV;

    # possibly useful paths
    my ( $git_dir, $work_tree );

    # a Git::Repository object will give more context
    if ($r) {

        # get some useful paths
        ( $git_dir, $work_tree, my $repo_o )
            = ( $r->git_dir, $r->work_tree, $r->options );

        # merge the option hashes
        $o = {
            %$repo_o, %$o,
            exists $repo_o->{env} && exists $o->{env}
            ? ( env => { %{ $repo_o->{env} }, %{ $o->{env} } } )
            : ()
        };

        # setup our %ENV
        delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
        $ENV{GIT_DIR}       = $git_dir;
        $ENV{GIT_WORK_TREE} = $work_tree
            if defined $work_tree;
    }

    # chdir to the expected directory
    my $orig = cwd;
    my $dest
        = defined $o->{cwd}                       ? $o->{cwd}
        : defined $work_tree && length $work_tree ? $work_tree
        :                                           undef;
    if ( defined $dest ) {
        chdir $dest or croak "Can't chdir to $dest: $!";
    }

    # turn us into a dumb terminal
    delete $ENV{TERM};

    # update the environment
    @ENV{ keys %{ $o->{env} } } = values %{ $o->{env} }
        if exists $o->{env};

    # start the command
    my ( $in, $out, $err );
    $err = Symbol::gensym;
    my $pid = eval { open3( $in, $out, $err, $git, @cmd ); };

    # FIXME - better check open3 error conditions
    croak $@ if !defined $pid;

    # some input was provided
    if ( defined $o->{input} ) {
        local $SIG{PIPE}
            = sub { croak "Broken pipe when writing to: $git @cmd" };
        print {$in} $o->{input} if length $o->{input};
        $in->close;
    }

    # chdir back to origin
    if ( defined $dest ) {
        chdir $orig or croak "Can't chdir back to $orig: $!";
    }

    # create the object
    return bless {
        cmdline => [ $git, @cmd ],
        pid     => $pid,
        stdin   => $in,
        stdout  => $out,
        stderr  => $err,
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

    # $cmd is basically a hash, with keys / accessors
    $cmd->stdin();     # filehandle to the process' stdin (write)
    $cmd->stdout();    # filehandle to the process' stdout (read)
    $cmd->stderr();    # filehandle to the process' stdout (read)
    $cmd->pid();       # pid of the child process

    # done!
    $cmd->close();

    # exit information
    $cmd->exit();      # exit status
    $cmd->signal();    # signal
    $cmd->core();      # core dumped? (boolean)

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

=item C<cwd>

The I<current working directory> in which the git command will be run.

=item C<env>

A hashref containing key / values to add to the git command environment.

=item C<input>

A string that is send to the git command standard input, which is then closed.

Using the empty string as C<input> will close the git command standard input
without writing to it.

Using C<undef> as C<input> will not do anything. This behaviour provides
a way to modify options inherited from C<new()> or a hash populated by
some other part of the program.

On some systems, some git commands may close standard input on startup,
which will cause a SIGPIPE when trying to write to it. This will raise
an exception.

=back

If the C<Git::Repository> object has its own option hash, it will be used
to provide default values that can be overriden by the actual option hash
passed to C<new()>.

If several option hashes are passed to C<new()>, only the first one will
be used.

The C<Git::Repository::Command> object returned by C<new()> has a 
number of attributes defined (see below).


=head2 close()

Close all pipes to the child process, and collects exit status, etc.
and defines a number of attributes (see below).


=head2 Accessors

The attributes of a C<Git::Repository::Command> object are also accessible
through a number of accessors.

The object returned by C<new()> will have the following attributes defined:

=over 4

=item cmdline()

Return the command-line actually executed, as a list of strings.

=item pid()

The PID of the underlying B<git> command.

=item stdin()

A filehandle opened in write mode to the child process' standard input.

=item stdout()

A filehandle opened in read mode to the child process' standard output.

=item stderr()

A filehandle opened in read mode to the child process' standard error output. 

=back

After the call to C<close()>, the following attributes will be defined:

=over 4

=item exit()

The exit status of the underlying B<git> command.

=item core()

A boolean value indicating if the command dumped core.

=item signal()

The signal, if any, that killed the command.

=back

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

