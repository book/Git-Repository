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

# MSWin32 support
use constant MSWin32 => $^O eq 'MSWin32';
if ( MSWin32 ) {
    require Socket;
    import Socket qw( AF_UNIX SOCK_STREAM PF_UNSPEC );
}

our $VERSION = '1.10';

# Trap the real STDIN/ERR/OUT file handles in case someone
# *COUGH* Catalyst *COUGH* screws with them which breaks open3
my ($REAL_STDIN, $REAL_STDOUT, $REAL_STDERR);
BEGIN {
    open $REAL_STDIN, "<&=".fileno(*STDIN);
    open $REAL_STDOUT, ">>&=".fileno(*STDOUT);
    open $REAL_STDERR, ">>&=".fileno(*STDERR);
}

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
my %binary;    # cache calls to _is_git
sub _is_git {
    my ($binary) = @_;

    # compute cache key:
    # - filename (path):     path
    # - absolute path (abs): empty string
    # - relative path (rel): dirname
    my $path = defined $ENV{PATH} && length( $ENV{PATH} ) ? $ENV{PATH} : '';
    my ( $type, $key )
        = ( File::Spec->splitpath($binary) )[2] eq $binary ? ( 'path', $path )
        : File::Spec->file_name_is_absolute($binary)       ? ( 'abs', '' )
        :                                                    ( 'rel', cwd() );

    # This relatively complex cache key scheme allows PATH or cwd to change
    # during the life of a program using Git::Repository, which is likely
    # to happen. On the other hand, it completely ignores the possibility
    # that any part of the cached path to a git binary could be a symlink
    # which target may also change during the life of the program.

    # check the cache
    return $binary{$type}{$key}{$binary}
        if exists $binary{$type}{$key}{$binary};

    # compute a list of candidate files (look in PATH if needed)
    my $git;
    if ( $type eq 'path' ) {
        my $path_sep = $Config::Config{path_sep} || ';';
        my @ext = (
            '', $^O eq 'MSWin32' ? ( split /\Q$path_sep\E/, $ENV{PATHEXT} ) : ()
        );
        ($git) = grep {-e}
            map {
            my $path = $_;
            map { File::Spec->catfile( $path, $_ ) } map {"$binary$_"} @ext
            }
            split /\Q$path_sep\E/, $path;
    }
    else {
        $git = File::Spec->rel2abs($binary);
    }

    # if we can't find any, we're done
    return $binary{$type}{$key}{$binary} = undef
        if !( defined $git && -x $git );

    # try to run it
    my $version;
    my ( $pid, $in, $out, $err ) = _spawn( $git, '--version' );
    if ($pid) {
        $version = <$out>;
        waitpid $pid, 0;
    }

    # does it really look like git?
    return $binary{$type}{$key}{$binary}
        = $version =~ /^git version \d/
            ? $type eq 'path'
                ? $binary    # leave the shell figure it out itself too
                : $git
            : undef;
}

sub new {
    my ( $class, @cmd ) = @_;

    # split the args
    my ($r, $o);
    @cmd = grep {
     !( ref eq 'HASH'                            ? $o ||= $_
      : blessed $_ && $_->isa('Git::Repository') ? $r ||= $_
      :                                          0 )
    } @cmd;
    $o ||= {};    # no options

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

    # get and check the git command
    my $git_cmd = defined $o->{git} ? $o->{git} : 'git';
    my $git = _is_git($git_cmd);

    croak "git binary '$git_cmd' not available or broken"
        if !defined $git;

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

    # spawn the command
    my ( $pid, $in, $out, $err ) = _spawn( $git, @cmd );

    # FIXME - better check open3 error conditions
    croak $@ if !defined $pid;

    # some input was provided
    if ( defined $o->{input} ) {
        local $SIG{PIPE}
            = sub { croak "Broken pipe when writing to: $git @cmd" };
        print {$in} $o->{input} if length $o->{input};
        if (MSWin32) { $in->flush; shutdown( $in, 2 ); }
        else         { $in->close; }
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
    if ( MSWin32 ) {
        $in->opened  and shutdown( $in,  2 ) || carp "error closing stdin: $!";
        $out->opened and shutdown( $out, 2 ) || carp "error closing stdout: $!";
        $err->opened and shutdown( $err, 2 ) || carp "error closing stderr: $!";
    }
    else {
        $in->opened  and $in->close  || carp "error closing stdin: $!";
        $out->opened and $out->close || carp "error closing stdout: $!";
        $err->opened and $err->close || carp "error closing stderr: $!";
    }

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

sub _spawn {
    my @cmd = @_;
    my ( $pid, $in, $out, $err );

    # save standard handles
    local *STDIN  = $REAL_STDIN;
    local *STDOUT = $REAL_STDOUT;
    local *STDERR = $REAL_STDERR;

    if (MSWin32) {

        # code from: http://www.perlmonks.org/?node_id=811650
        # discussion at: http://www.perlmonks.org/?node_id=811057
        local ( *IN_R,  *IN_W );
        local ( *OUT_R, *OUT_W );
        local ( *ERR_R, *ERR_W );
        _pipe( *IN_R,  *IN_W )  or croak "input pipe error: $^E";
        _pipe( *OUT_R, *OUT_W ) or croak "output pipe error: $^E";
        _pipe( *ERR_R, *ERR_W ) or croak "errput pipe error: $^E";

        $pid = eval { open3( '>&IN_R', '<&OUT_W', '<&ERR_W', @cmd ); };
        ( $in, $out, $err ) = ( *IN_W{IO}, *OUT_R{IO}, *ERR_R{IO} );
    }
    else {
        $err = Symbol::gensym;
        $pid = eval { open3( $in, $out, $err, @cmd ); };
    }

    return ( $pid, $in, $out, $err );
}

sub _pipe {
    socketpair( $_[0], $_[1], AF_UNIX(), SOCK_STREAM(), PF_UNSPEC() )
        or return undef;

    # turn off buffering
    $_[0]->autoflush(1);
    $_[1]->autoflush(1);

    # half-duplex
    shutdown( $_[0], 1 );    # No more writing for reader
    shutdown( $_[1], 0 );    # No more reading for writer

    return 1;
}

1;

__END__

=head1 NAME

Git::Repository::Command - Command objects for running git

=head1 SYNOPSIS

    use Git::Repository::Command;

    # invoke an external git command, and return an object
    $cmd = Git::Repository::Command->new(@cmd);

    # a Git::Repository object can provide more context
    $cmd = Git::Repository::Command->new( $r, @cmd );

    # options can be passed as a hashref
    $cmd = Git::Repository::Command->new( $r, @cmd, \%option );

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

Note that C<close()> is automatically called when the
C<Git::Repository::Command> object is destroyed.
Annoyingly, this means that in the following example C<$fh> will be
closed when you tried to use it:

    my $fh = Git::Repository::Command->new( @cmd )->stdout;

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

=head1 ACKNOWLEDGEMENTS

The Win32 implementation owes a lot to two people. First, Olivier Raginel
(BABAR), for providing me with a test platform with Git and Strawberry
Perl installed, which I could use at any time. Many thanks go also to
Chris Williams (BINGOS) for pointing me towards perlmonks posts by ikegami
that contained crucial elements to a working MSWin32 implementation.

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

