package Git::Repository::Command;

use strict;
use warnings;
use Carp;
use Cwd qw( cwd );
use IPC::Open3 qw( open3 );
use Scalar::Util qw( blessed );

# CAN I HAS GIT?
sub _has_git {
    my ($binary) = @_;
    my ( $in, $out );
    my $err = Symbol::gensym;
    my $pid = eval { open3( $in, $out, $err, $binary, '--version' ); };
    waitpid $pid, 0;
    return !!<$out>;
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
        = $o                 && defined $o->{cwd} ? $o->{cwd}
        : defined $wc_path   && length $wc_path   ? $wc_path
        :                                           undef;
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
    print {$in} $o->{input} if exists $o->{input};

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

    # check $?
    @{$self}{qw( exit signal core )} = ( $? >> 8, $? & 127, $? & 128 );

    return $self;
}

1;
