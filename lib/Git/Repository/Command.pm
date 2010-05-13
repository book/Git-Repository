package Git::Repository::Command;

use strict;
use warnings;
use Carp;
use Cwd qw( cwd );
use IPC::Open3 qw( open3 );

# TODO - actually find the git binary

sub new {
    my ( $class, $r, @cmd ) = @_;

    # FIXME - check if $r is a Git::Repository object
    my ( $repo_path, $wc_path, $wc_subdir )
        = ( $r->repo_path, $r->wc_path, $r->wc_subdir );

    # setup %ENV (no blocks to preserve local)
    local $ENV{GIT_DIR} = $repo_path
        if defined $repo_path;
    local $ENV{GIT_WORK_TREE} = $wc_path
        if defined $repo_path && defined $wc_path;

    # chdir to the expected directory
    my $orig = cwd;
    my $dest
        = defined $wc_subdir && length $wc_subdir ? $wc_subdir
        : defined $wc_path   && length $wc_path   ? $wc_path
        :                                           undef;
    if ( defined $dest ) {
        chdir $dest or croak "Can't chdir to $dest: $!";
    }

    # start the command
    my ( $in, $out, $err );
    $err = Symbol::gensym;
    my $pid = open3( $in, $out, $err, 'git', @cmd );

    # FIXME - check open3 error conditions

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
    my ($in, $out, $err) = @{$self}{qw( stdin stdout stderr )};
    close $in  or carp "error closing stdin: $!";
    close $out or carp "error closoutg stdout: $!";
    close $err or carp "error closerrg stderr: $!";

    # and wait for the child
    waitpid $self->{pid}, 0;

    # we're done
    $self->{finished} = 1;

    # TODO check $?
}

1;

