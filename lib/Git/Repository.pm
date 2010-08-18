package Git::Repository;

use warnings;
use strict;
use 5.006;

use Carp;
use File::Spec;
use Cwd qw( cwd abs_path );
use Scalar::Util qw( looks_like_number );

use Git::Repository::Command;

our $VERSION = '1.09';

# a few simple accessors
for my $attr (qw( git_dir work_tree options )) {
    no strict 'refs';
    *$attr = sub { return ref $_[0] ? $_[0]{$attr} : () };
}

# backward compatible aliases
*repo_path = \&git_dir;
*wc_path   = \&work_tree;

# helper function
sub _abs_path {
    my ( $base, $path ) = @_;
    return abs_path(
        File::Spec->file_name_is_absolute($path)
        ? $path
        : File::Spec->catdir( $base, $path )
    );
}

#
# constructor-related methods
#

sub new {
    my ( $class, @arg ) = @_;

    # create the object
    my $self = bless {}, $class;

    # take out the option hash
    my %arg = grep { !( ref eq 'HASH' ? $self->{options} ||= $_ : 0 ) } @arg;
    my $options = $self->{options} ||= {};

    # ignore 'input' option during object creation
    my $input = delete $options->{input};

    # setup default options
    # accept older for backward compatibility
    my ($git_dir) = grep {defined} delete @arg{qw( git_dir repository )};
    my ($work_tree) = grep {defined} delete @arg{qw( work_tree working_copy )};

    croak "Unknown parameters: @{[keys %arg]}" if keys %arg;

    # compute the various paths
    my $cwd = defined $options->{cwd} ? $options->{cwd} : cwd();

    # if work_tree or git_dir are relative, they are relative to cwd
    -d ( $git_dir = _abs_path( $cwd, $git_dir ) )
        or croak "directory not found: $git_dir"
        if defined $git_dir;
    -d ( $work_tree = _abs_path( $cwd, $work_tree ) )
        or croak "directory not found: $work_tree"
        if defined $work_tree;

    # if no cwd option given, assume we want to work in work_tree
    $cwd = defined $options->{cwd} ? $options->{cwd}
         : defined $work_tree      ? $work_tree
         :                           cwd();

    # we'll always have to compute it if not defined
    $self->{git_dir}
        = _abs_path( $cwd,
        Git::Repository->run( qw( rev-parse --git-dir ), { cwd => $cwd } ) )
        if !defined $git_dir;

    # there are 4 possible cases
    if ( !defined $work_tree ) {

        # 1) no path defined: trust git with the values
        # $self->{git_dir} already computed

        # 2) only git_dir was given: trust it
        $self->{git_dir} = $git_dir if defined $git_dir;

        # in a non-bare repository, the work tree is just above the gitdir
        if ( $self->run(qw( config core.bare )) ne 'true' ) {
            $self->{work_tree}
                = _abs_path( $self->{git_dir}, File::Spec->updir );
        }
    }
    else {

        # 3) only work_tree defined:
        if ( !defined $git_dir ) {

            # $self->{git_dir} already computed

            # check work_tree is the top-level work tree, and not a subdir
            my $cdup = Git::Repository->run( qw( rev-parse --show-cdup ),
                { cwd => $cwd } );
            $self->{work_tree}
                = $cdup ? _abs_path( $work_tree, $cdup ) : $work_tree;
        }

        # 4) both path defined: trust the values
        else {
            $self->{git_dir}   = $git_dir;
            $self->{work_tree} = $work_tree;
        }
    }

    # sanity check
    my $gitdir
        = eval { _abs_path( $cwd, $self->run(qw( rev-parse --git-dir )) ) }
        || '';
    croak "fatal: Not a git repository: $self->{git_dir}"
        if $self->{git_dir} ne $gitdir;

    # put back the ignored option
    $options->{input} = $input if defined $input;

    return $self;
}

sub create {
    my ( $class, @args ) = @_;
    my @output = $class->run(@args);
    my $gitdir;

    # git init or clone until v1.7.1 (inclusive)
    if ( $output[0] =~ /^(?:Reinitialized existing|Initialized empty) Git repository in (.*)/ ) {
        $gitdir = $1;
    }

    # git clone after v1.7.1
    elsif ( $output[0] =~ /Cloning into (bare repository )?(.*)\.\.\./ ) {
        $gitdir = $1 ? $2 : File::Spec->catdir( $2, '.git' );
    }

    # some other command (no git repository created)
    else {return}

    return $class->new( git_dir => $gitdir, grep { ref eq 'HASH' } @args );
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

#
# version comparison methods
#

# NOTE: it doesn't make sense to try to cache the results of version():
# - yes, it will make faster benchmarks, but
# - the 'git' option allows to change the git binary anytime
# - version comparison is usually done once anyway
sub version {
    return ( $_[0]->run('--version') =~ /git version (.*)/g )[0];
}

sub _version_eq {
    my ( $v1, $v2 ) = @_;
    my @v1 = split /\./, $v1;
    my @v2 = split /\./, $v2;

    return '' if @v1 != @v2;
    $v1[$_] ne $v2[$_] and return '' for 0 .. $#v1;
    return 1;
}

sub _version_gt {
    my ( $v1, $v2 ) = @_;
    my @v1 = split /\./, $v1;
    my @v2 = split /\./, $v2;

    # skip to the first difference
    shift @v1, shift @v2 while @v1 && @v2 && $v1[0] eq $v2[0];
    ( $v1, $v2 ) = ( $v1[0] || 0, $v2[0] || 0 );

    # rcX is less than any number
    return looks_like_number($v1)
             ? looks_like_number($v2) ? $v1 > $v2 : 1
             : looks_like_number($v2) ? ''        : $v1 gt $v2;
}

# every op is a combination of eq and gt
sub version_eq { return _version_eq( $_[0]->version, $_[1] ); }
sub version_ne { return !_version_eq( $_[0]->version, $_[1] ); }
sub version_gt { return _version_gt( $_[0]->version, $_[1] ); }
sub version_le { return !_version_gt( $_[0]->version, $_[1] ); }

sub version_lt {
    my $v;
    return !_version_eq( $v = $_[0]->version, $_[1] )
        && !_version_gt( $v, $_[1] );
}

sub version_ge {
    my $v;
    return _version_eq( $v = $_[0]->version, $_[1] )
        || _version_gt( $v, $_[1] );
}

1;

__END__

=head1 NAME

Git::Repository - Perl interface to Git repositories

=head1 SYNOPSIS

    use Git::Repository;

    # start from an existing repository
    $r = Git::Repository->new( git_dir => $gitdir );

    # start from an existing working copy
    $r = Git::Repository->new( work_tree => $dir );

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

    # obtain version information
    my $version = $r->version();

    # compare current git version
    if ( $r->version_gt('1.6.5') ) {
        ...;
    }

=head1 DESCRIPTION

C<Git::Repository> is a Perl interface to Git, allowing scripted
interactions with one or more repositories. It's a low-level interface,
allowing to call B<any> Git command, either I<porcelain> or I<plumbing>,
including bidirectional commands such as C<git commit-tree>.

Since it is a low-level interface, it doesn't provide any fancy way to
call Git commands. It is up to the programmer to setup any environment
variables that the underlying Git command may need and use.

A C<Git::Repository> object simply provides context to the git commands
being run. Is it possible to call the  C<command()>and C<run()> methods
agains the class itself, and the context (typically I<current working
directory>) will be obtained from the options and environment.

The C<GIT_DIR> and C<GIT_WORK_TREE> environment variables are special:
if the command is run in the context of a C<Git::Repository> object, they
will be overriden by the object's C<git_dir> and C<work_tree> attributes,
respectively. It is however still possible to override them if necessary,
using the C<env> option.

=head1 METHODS

C<Git::Repository> supports the following methods:

=head2 new( %args, $options )

Create a new C<Git::Repository> object, based on an existing Git repository.

Parameters are:

=over 4

=item git_dir => $gitdir

The location of the git repository (F<.git> directory or equivalent).

For backward compatibility with versions 1.06 and before, C<repository>
is accepted in place of C<git_dir> (but the newer takes precedence).

=item work_tree => $dir

The location of the git working copy (for a non-bare repository).

If C<work_tree> actually points to a subdirectory of the work tree,
C<Git::Repository> will automatically recompute the proper value.

For backward compatibility with versions 1.06 and before, C<working_copy>
is accepted in place of C<work_tree> (but the newer takes precedence).

=back

At least one of the two parameters is required. Usually, one is enough,
as C<Git::Repository> can work out where the other directory (if any) is.

C<new()> also accepts a reference to an option hash, that will be
automatically used by C<Git::Repository::Command> when working with
the corresponding C<Git::Repository> instance.

So this:

    my $options = {
        git => '/path/to/some/other/git',
        env => {
            GIT_COMMITTER_EMAIL => 'book@cpan.org',
            GIT_COMMITTER_NAME  => 'Philippe Bruhat (BooK)',
        },
    };
    my $r = Git::Repository->new(
        work_tree => $dir,
        $options
    );

will be equivalent to having any option hash that will be passed to
C<run()> or C<command()> be pre-filled with these options.

It probably makes no sense to set the C<input> option in C<new()> or
C<create()>, but C<Git::Repository> won't stop you.
Note that on some systems, some git commands may close standard input
on startup, which will cause a SIGPIPE. C<Git::Repository::Command>
will raise an exception.

=head2 create( @cmd )

Runs a repository initializing command (like C<init> or C<clone>) and
returns a C<Git::Repository> object pointing to it. C<@cmd> can contain
a hashref with options (see L<Git::Repository::Command>.

This method runs the command and parses the first line to find the
repository path. Using the option I<-q> on such commands makes no sense,
as it will prevent C<create()> to parse their output.

C<create()> also accepts a reference to an option hash, that will be
used to setup the returned C<Git::Repository> instance.

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

=head2 git_dir()

Returns the repository path.

=head2 repo_path()

For backward compatibility with versions 1.06 and before, C<repo_path()>
it provided as an alias to C<git_dir()>.

=head2 work_tree()

Returns the working copy path.
Used as current working directory by C<Git::Repository::Command>.

=head2 wc_path()

For backward compatibility with versions 1.06 and before, C<wc_path()>
it provided as an alias to C<work_tree()>.

=head2 options()

Return the option hash that was passed to C<< Git::Repository->new() >>.

=head2 version()

Return the version of git, as given by C<git --version>.

=head2 Version-comparison "operators"

Git evolves very fast, and new features are constantly added to it.
To facilitate the creation of programs that can properly handle the
wide variety of Git versions seen in the wild, a number of version
comparison "operators" are available.

They are named C<version_I<op>> where I<op> is the equivalent of the Perl
operators C<lt>, C<gt>, C<le>, C<ge>, C<eq>, C<ne>. They return a boolean
value, obtained by comparing the version of the git binary and the
version string passed as parameter.

The methods are:

=over 4

=item version_lt( $version )

=item version_gt( $version )

=item version_le( $version )

=item version_ge( $version )

=item version_eq( $version )

=item version_ne( $version )

=back

Note that there are a small number of cases where the version comparison
operators will I<not> compare versions correctly for I<very old> versions of
Git. Typical example is C<1.0.0a gt 1.0.0> which should return true, but
doesn't. It actually only concerns cases when it is needed to compare
and the last significant bit of very close (and very old) version numbers.

However, this only concerns Git versions older than C<1.4.0-rc1> (June 2006).
It wasn't worth the trouble to try and correctly compare older version
numbers.

Other issues exist when comparing development version numbers with one
another. For example, C<1.7.1.1> is greater than both C<1.7.1.1.gc8c07>
and C<1.7.1.1.g5f35a>, and C<1.7.1> is lower than both. Obviously,
C<1.7.1.1.gc8c07> will compare as greater than C<1.7.1.1.g5f35a>
(asciibetically), but in fact these two version numbers cannot be
compared, as they are two siblings children of the commit tagged
C<v1.7.1>).

If one was to compute the set of all possible version numbers (as returned
by C<git --version>) for all git versions that can be compiled from each
commit in the F<git.git> repository, this would not be a totally ordered
set. Big deal.

=head1 HOW-TO

=head2 Create a new repository

    # git version 1.6.5 and above
    my $r = Git::Repository->create( init => $dir );

    # any older git will need two steps
    chdir $dir;
    my $r = Git::Repository->create( 'init' );

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
    my @errput = $cmd->stderr->getlines();
    $cmd->close;

C<run()> also captures all output at once, which can lead to unecessary
memory consumption when capturing the output of some really verbose
commands.

    my $cmd = $r->command( log => '--pretty=oneline', '--all' );
    my $log = $cmd->stdout;
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

=head2 Process the output of B<git log>

When creating a tool that needs to process the output of B<git log>,
you should always define precisely the expected format using the
I<--pretty> option, and choose a format that is easy to parse.

Assuming B<git log> will output the default format will eventually
lead to problems, for example when the user's git configuration defines
C<format.pretty> to be something else than the default of C<medium>.


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

