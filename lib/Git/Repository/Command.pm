package Git::Repository::Command;

use strict;
use warnings;
use 5.006;

use Carp;
use Cwd qw( cwd );
use IO::Handle;
use Scalar::Util qw( blessed );
use File::Spec;
use System::Command;

our @ISA = qw( System::Command );

# a few simple accessors
for my $attr (qw( pid stdin stdout stderr exit signal core )) {
    no strict 'refs';
    *$attr = sub { return $_[0]{$attr} };
}
for my $attr (qw( cmdline )) {
    no strict 'refs';
    *$attr = sub { return @{ $_[0]{$attr} } };
}

sub _which {
    my @pathext = ('');
    push @pathext,
        $^O eq 'MSWin32' ? split ';', $ENV{PATHEXT}
      : $^O eq 'cygwin'  ? qw( .com .exe .bat )
      :                    ();

    for my $path ( File::Spec->path ) {
        for my $ext (@pathext) {
            my $binary = File::Spec->catfile( $path, $_[0] . $ext );
            return $binary if -x $binary && !-d _;
        }
    }

    # not found
    return undef;
}

# CAN I HAS GIT?
my %binary;    # cache calls to _is_git
sub _is_git {
    my ( $binary, @args ) = @_;
    my $args = join "\0", @args;

    # git option might be an arrayref containing an executable with arguments
    # Best that can be done is to check if the first part is executable
    # and use the arguments as part of the cache key

    # compute cache key:
    # - filename (path-rel): $CWD \0 $PATH
    # - filename (path):     $PATH
    # - absolute path (abs): empty string
    # - relative path (rel): dirname
    my $path = defined $ENV{PATH} && length( $ENV{PATH} ) ? $ENV{PATH} : '';
    my ( $type, $key ) =
        ( File::Spec->splitpath($binary) )[2] eq $binary
      ? grep( !File::Spec->file_name_is_absolute($_), File::Spec->path )
          ? ( 'path-rel', join "\0", cwd(), $path )
          : ( 'path', $path )
      : File::Spec->file_name_is_absolute($binary) ? ( 'abs', '' )
      :                                              ( 'rel', cwd() );

    # This relatively complex cache key scheme allows PATH or cwd to change
    # during the life of a program using Git::Repository, which is likely
    # to happen. On the other hand, it completely ignores the possibility
    # that any part of the cached path to a git binary could be a symlink
    # which target may also change during the life of the program.

    # check the cache
    return $binary{$type}{$key}{$binary}{$args}
        if exists $binary{$type}{$key}{$binary}{$args};

    # compute a list of candidate files (look in PATH if needed)
    my $git = $type =~ /^path/
      ? _which($binary)
      : File::Spec->rel2abs($binary);
    $git = File::Spec->rel2abs($git)
      if defined $git && $type eq 'path-rel';

    # if we can't find any, we're done
    return $binary{$type}{$key}{$binary} = undef
        if !( defined $git && -x $git );

    # try to run it
    my $cmd = System::Command->new( $git, @args, '--version' );
    my $version = do { local $/ = "\n"; $cmd->stdout->getline; } || '';
    $cmd->close;

    # does it really look like git?
    return $binary{$type}{$key}{$binary}{$args}
        = $version =~ /^git version \d/
            ? $type eq 'path'
                ? $binary    # leave the shell figure it out itself too
                : $git
            : undef;
}

sub new {
    my ( $class, @cmd ) = @_;

    # split the args
    my (@r, @o);
    @cmd =    # take out the first Git::Repository in $r, and options in @o
        grep !( blessed $_ && $_->isa('Git::Repository') ? push @r, $_ : 0 ),
        grep !( ref eq 'HASH'                            ? push @o, $_ : 0 ),
        @cmd;

    # wouldn't know what to do with more than one Git::Repository object
    croak "Too many Git::Repository objects given: @r" if @r > 1;
    my $r = shift @r;

    # keep changes to the environment local
    local %ENV = %ENV;

    # a Git::Repository object will give more context
    if ($r) {

        # pick up repository options
        unshift @o, $r->options;

        # get some useful paths
        my ( $git_dir, $work_tree ) = ( $r->git_dir, $r->work_tree );
        unshift @o, { cwd => $work_tree }
            if defined $work_tree && length $work_tree;

        # setup our %ENV
        delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
        $ENV{GIT_DIR}       = $git_dir;
        $ENV{GIT_WORK_TREE} = $work_tree
            if defined $work_tree;
    }

    # pick up the modified PATH, if any
    exists $_->{env} and exists $_->{env}{PATH} and $ENV{PATH} = $_->{env}{PATH}
      for @o;

    # extract and process the 'fatal' option
    push @o, {
        fatal => {
            128 => 1,    # fatal
            129 => 1,    # usage
            map s/^-// ? ( $_ => '' ) : ( $_ => 1 ),
            map /^!0$/ ? ( 1 .. 255 ) : $_,
            map ref() ? @$_ : $_, grep defined, map $_->{fatal}, @o
        }
    };

    # get and check the git command
    my $git_cmd = ( map { exists $_->{git} ? $_->{git} : () } @o )[-1];

    # git option might be an arrayref containing an executable with arguments
    # (e.g. [ qw( /usr/bin/sudo -u nobody git ) ] )
    ( $git_cmd, my @args )
        = defined $git_cmd ? ref $git_cmd ? @$git_cmd : ($git_cmd) : ('git');
    my $git = _is_git($git_cmd, @args);

    croak sprintf "git binary '%s' not available or broken",
        join( ' ', $git_cmd, @args )    # show the full command given
        if !defined $git;

    # turn us into a dumb terminal
    delete $ENV{TERM};

    # spawn the command and re-bless the object in our class
    return bless System::Command->new( $git, @args, @cmd, @o ), $class;
}

sub final_output {
    my ($self, @cb) = @_;

    # get output / errput
    my $input_record_separator =
        exists $self->options->{input_record_separator}
        ? $self->options->{input_record_separator}
        : "\n";
    my ( @output, @errput );
    $self->loop_on(
        input_record_separator => $input_record_separator,
        stdout => sub { chomp( my $o = shift ); push @output, $o; },
        stderr => sub { chomp( my $e = shift ); push @errput, $e; },
    );

    # done with it
    $self->close;

    # fatal exit codes set by the 'fatal' option
    # when working with fatal => '!0' it's helpful to be able to show the exit status
    # so that specific exit codes can be made non-fatal if desired.
    if ( $self->options->{fatal}{ $self->exit } ) {
        croak join( "\n", @errput ) || 'fatal: unknown git error, exit status '.$self->exit;
    }

    # something else's wrong
    if ( @errput && !$self->options->{quiet} ) { carp join "\n", @errput; }

    # process the output with the optional callbacks
    for my $cb (@cb) {
        @output = map $cb->($_), @output;
    }

    # return the output
    return wantarray ? @output : join "\n", @output;
}

1;

__END__

=head1 NAME

Git::Repository::Command - Command objects for running git

=pod

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

    # cut to the chase
    my ( $pid, $in, $out, $err ) = Git::Repository::Command->spawn(@cmd);


=head1 DESCRIPTION

L<Git::Repository::Command> is a class that actually launches a B<git>
commands, allowing to interact with it through its C<STDIN>, C<STDOUT>
and C<STDERR>.

This class is a subclass of L<System::Command>, meant to be invoked
through L<Git::Repository>.

=head1 METHODS

As a subclass of L<System::Command>,
L<Git::Repository::Command> supports the following methods:

=head2 new

    Git::Repository::Command->new( @cmd );

Runs a B<git> command with the parameters in C<@cmd>.

If C<@cmd> contains a L<Git::Repository> object, it is used to provide
context to the B<git> command.

If C<@cmd> contains one or more hash reference, they are taken as
I<option> hashes. The recognized keys are:

=over 4

=item C<git>

The actual git binary to run. By default, it is just C<git>.

In case the C<git> to be run is actually a command with parameters
(e.g. when using B<sudo> or another command executer), the option value
should be an array reference with the command and parameters, like this:

    { git => [qw( sudo -u nobody git )] }

=item C<cwd>

The I<current working directory> in which the git command will be run.
(C<chdir()> will be called just before launching the command.)

If not provided, it will default to the root of the Git repository work
tree (if the repository is bare, then no C<chdir()> will be performed).

=item C<env>

A hashref containing key / values to add to the git command environment.

=item C<fatal>

An arrayref containing a list of exit codes that will be considered
fatal by C<final_output()>.

Prepending the value with C<-> will make it non-fatal, which can be
useful to override a default. The string C<"!0"> can be used as a
shortcut for C<[ 1 .. 255 ]>.

If several option hashes have the C<fatal> key, the lists of exit codes
will be combined, with the values provided last taking precedence (when
using a combination of positive / negative values).

The generated list always contains C<128> and C<129>; to make them
non-fatal, just add C<-128> and C<-129> to the list provided to the
C<fatal> option.

=item C<input>

A string that is send to the git command standard input, which is then closed.

Using the empty string as C<input> will close the git command standard input
without writing to it.

Using C<undef> as C<input> will not do anything. This behaviour provides
a way to modify options inherited from C<new()> or a hash populated by
some other part of the program.

On some systems, some git commands may close standard input on startup,
which will cause a C<SIGPIPE> when trying to write to it. This will raise
an exception.

=item C<quiet>

Boolean option to control the output of warnings.

If true, methods such as C<final_output()> will not warn when Git outputs
messages on C<STDERR>.

=item C<input_record_separator>

A string which the C<$/> special variable is set to during the command
execution.

This is mostly useful when passing the C<-z> option to a Git command so that it
output lines separated by the NUL character and you want to get it line by line,
like this:

    my @files = $git->run(
        qw/ls-tree -r --name-only -z HEAD/,
        { input_record_separator => "\0" },
    );

=back

If the L<Git::Repository> object has its own option hash, it will be used
to provide default values that can be overridden by the actual option hash
passed to C<new()>.

If several option hashes are passed to C<new()>, they will all be merged,
keys in later hashes taking precedence over keys in earlier hashes.

The L<Git::Repository::Command> object returned by C<new()> has a
number of attributes defined (see below).


=head2 close

    $cmd->close();

Close all pipes to the child process, and collects exit status, etc.
and defines a number of attributes (see below).

=head2 final_output

    $cmd->final_output( @callbacks );

Collect all the output, and terminate the command.

Returns the output as a string in scalar context,
or as a list of lines in list context. Also accepts a hashref of options.

Lines are automatically C<chomp>ed.

If C<@callbacks> is provided, the code references will be applied
successively to each line of output. The line being processed is in C<$_>,
but the coderef must still return the result string.

If the Git command printed anything on stderr, it will be printed as
warnings. If the git sub-process exited with a status code listed in
the C<fatal> option, it will C<die()>. The defaults fatal exit codes
are C<128> (fatal error), and C<129> (usage message).


=head2 Accessors

The attributes of a L<Git::Repository::Command> object are also accessible
through a number of accessors.

The object returned by C<new()> will have the following attributes defined:

=over 4

=item cmdline

Return the command-line actually executed, as a list of strings.

=item pid

The PID of the underlying B<git> command.

=item stdin

A filehandle opened in write mode to the child process' standard input.

=item stdout

A filehandle opened in read mode to the child process' standard output.

=item stderr

A filehandle opened in read mode to the child process' standard error output.

=back

Regarding the handles to the child git process, note that in the
following code:

    my $fh = Git::Repository::Command->new( @cmd )->stdout;

C<$fh> is opened and points to the output of the git subcommand, while
the anonymous L<Git::Repository::Command> object has been destroyed.

After the call to C<close()>, the following attributes will be defined:

=over 4

=item exit

The exit status of the underlying B<git> command.

=item core

A boolean value indicating if the command dumped core.

=item signal

The signal, if any, that killed the command.

=back

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 ACKNOWLEDGEMENTS

The core of L<Git::Repository::Command> has been moved into its own
distribution: L<System::Command>. Proper Win32 support is now delegated
to that module.

Before that, the Win32 implementation owed a lot to two people.
First, Olivier Raginel (BABAR), who provided me with a test platform
with Git and Strawberry Perl installed, which I could use at any time.
Many thanks go also to Chris Williams (BINGOS) for pointing me towards
perlmonks posts by ikegami that contained crucial elements to a working
MSWin32 implementation.

In the end, it was Christian Walder (MITHALDU) who helped me finalize
Win32 support for L<System::Command> through a quick round of edit
(on my Linux box) and testing (on his Windows box) during the Perl QA
Hackathon 2013 in Lancaster.

=head1 COPYRIGHT

Copyright 2010-2016 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
