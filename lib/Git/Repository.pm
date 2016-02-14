package Git::Repository;

use warnings;
use strict;
use 5.006;

use Carp;
use File::Spec;
use Cwd qw( cwd realpath );

use Git::Repository::Command;
use Git::Repository::Util qw( _version_eq _version_gt );

# helper function
sub _abs_path {
    my ( $path, $base ) = @_;
    my $abs_path = File::Spec->rel2abs( $path, $base );

    # normalize, but don't die on Win32 if the path doesn't exist
    eval { $abs_path = realpath($abs_path); };
    return $abs_path;
}

use namespace::clean;

# a few simple accessors
for my $attr (qw( git_dir work_tree options )) {
    no strict 'refs';
    *$attr = sub { return ref $_[0] ? $_[0]{$attr} : () };
}

# backward compatible aliases
sub repo_path {
    croak "repo_path() is obsolete, please use git_dir() instead";
}
sub wc_path {
    croak "wc_path() is obsolete, please use work_tree() instead";
}

#
# support for loading plugins
#
sub import {
    my ( $class, @plugins ) = @_;

    for my $plugin (@plugins) {
        ( $plugin, my @names ) = @$plugin if ref $plugin;
        $plugin
            = substr( $plugin, 0, 1 ) eq '+'
            ? substr( $plugin, 1 )
            : "Git::Repository::Plugin::$plugin";
        eval "use $plugin; 1;" or croak $@;
        $plugin->install(@names);
    }
}

#
# constructor-related methods
#

sub new {
    my ( $class, @arg ) = @_;

    # create the object
    my $self = bless {}, $class;

    # take out the option hash
    my ( $options, %arg );
    {
        my @o;
        %arg = grep !( ref eq 'HASH' ? push @o, $_ : 0 ), @arg;
        croak "Too many option hashes given: @o" if @o > 1;
        $options = $self->{options} = shift @o || {};
    }

    # ignore 'input' and 'fatal' options during object creation
    my $input = delete $options->{input};
    my $fatal = delete $options->{fatal};

    # die if deprecated parameters are given
    croak "repository is obsolete, please use git_dir instead"
        if defined delete $arg{repository};
    croak "working_copy is obsolete, please use work_tree instead"
        if defined delete $arg{working_copy};

    # setup default options
    my $git_dir   = delete $arg{git_dir};
    my $work_tree = delete $arg{work_tree};

    croak "Unknown parameters: @{[keys %arg]}" if keys %arg;

    # compute the various paths
    my $cwd = defined $options->{cwd} ? $options->{cwd} : cwd();

    # if work_tree or git_dir are relative, they are relative to cwd
    -d ( $git_dir = _abs_path( $git_dir, $cwd ) )
        or croak "directory not found: $git_dir"
        if defined $git_dir;
    -d ( $work_tree = _abs_path( $work_tree, $cwd ) )
        or croak "directory not found: $work_tree"
        if defined $work_tree;

    # if no cwd option given, assume we want to work in work_tree
    $cwd = defined $options->{cwd} ? $options->{cwd}
         : defined $work_tree      ? $work_tree
         :                           cwd();

    # we'll always have to compute it if not defined
    $self->{git_dir} = _abs_path(
        Git::Repository->run(
            qw( rev-parse --git-dir ),
            { %$options, cwd => $cwd }
        ),
        $cwd
    ) if !defined $git_dir;

    # there are 4 possible cases
    if ( !defined $work_tree ) {

        # 1) no path defined: trust git with the values
        # $self->{git_dir} already computed

        # 2) only git_dir was given: trust it
        $self->{git_dir} = $git_dir if defined $git_dir;

        # in a non-bare repository, the work tree is just above the gitdir
        if ( $self->run(qw( config --bool core.bare )) ne 'true' ) {
            $self->{work_tree}
                = _abs_path( File::Spec->updir, $self->{git_dir} );
        }
    }
    else {

        # 3) only work_tree defined:
        if ( !defined $git_dir ) {

            # $self->{git_dir} already computed

            # check work_tree is the top-level work tree, and not a subdir
            my $cdup = Git::Repository->run( qw( rev-parse --show-cdup ),
                { %$options, cwd => $cwd } );
            $self->{work_tree}
                = $cdup ? _abs_path( $cdup, $work_tree ) : $work_tree;
        }

        # 4) both path defined: trust the values
        else {
            $self->{git_dir}   = $git_dir;
            $self->{work_tree} = $work_tree;
        }
    }

    # sanity check
    my $gitdir
        = eval { _abs_path( $self->run(qw( rev-parse --git-dir )), $cwd ) }
        || '';
    croak "fatal: Not a git repository: $self->{git_dir}"
        if $self->{git_dir} ne $gitdir;

    # put back the ignored option
    $options->{input} = $input if defined $input;
    $options->{fatal} = $fatal if defined $fatal;

    return $self;
}

# create() is now fully deprecated
sub create {
    croak "create() is deprecated, see Git::Repository::Tutorial for better alternatives";
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

    # split the args to get the optional callbacks
    my @cb;
    @cmd = grep { ref eq 'CODE' ? !push @cb, $_ : 1 } @cmd;

    local $Carp::CarpLevel = 1;

    # run the command (pass the instance if called as an instance method)
    my $command
        = Git::Repository::Command->new( ref $self ? $self : (), @cmd );

    # return the output or die
    return $command->final_output(@cb);
}

#
# version comparison methods
#

# NOTE: it doesn't make sense to try to cache the results of version():
# - yes, it will make faster benchmarks, but
# - the 'git' option allows to change the git binary anytime
# - version comparison is usually done once anyway
sub version {
    return (
        shift->run( '--version', grep { ref eq 'HASH' } @_ )
            =~ /git version (.*)/g )[0];
}

# every op is a combination of eq and gt
sub version_eq {
    my ( $r, $v, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    return _version_eq( $r->version(@o), $v );
}

sub version_ne {
    my ( $r, $v, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    return !_version_eq( $r->version(@o), $v );
}

sub version_gt {
    my ( $r, $v, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    return _version_gt( $r->version(@o), $v );
}

sub version_le {
    my ( $r, $v, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    return !_version_gt( $r->version(@o), $v );
}

sub version_lt {
    my ( $r, $v2, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    my $v1 = $r->version(@o);
    return !_version_eq( $v1, $v2 ) && !_version_gt( $v1, $v2 );
}

sub version_ge {
    my ( $r, $v2, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    my $v1 = $r->version(@o);
    return _version_eq( $v1, $v2 ) || _version_gt( $v1, $v2 );
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

    # start from a repository reachable from the current directory
    $r = Git::Repository->new();

    # or init our own repository first
    Git::Repository->run( init => $dir, ... );
    $r = Git::Repository->new( work_tree => $dir );

    # or clone from a URL first
    Git::Repository->run( clone => $url, $dir, ... );
    $r = Git::Repository->new( work_tree => $dir );

    # provide an option hash for Git::Repository::Command
    # (see Git::Repository::Command for all available options)
    $r = Git::Repository->new( ..., \%options );

    # run commands
    # - get the full output (no errput) passing options for this command only
    $output = $r->run( @cmd, \%options );

    # - get the full output as a list of lines (no errput), with options
    @output = $r->run( @cmd, \%options );

    # - process the output with callbacks
    $output = $r->run( @cmd, sub {...} );
    @output = $r->run( @cmd, sub {...} );

    # - obtain a Git::Repository::Command object
    #   (see Git::Repository::Command for details)
    $cmd = $r->command( @cmd, \%options );

    # obtain version information
    my $version = $r->version();

    # compare current git version
    if ( $r->version_gt('1.6.5') ) {
        ...;
    }

=head1 DESCRIPTION

L<Git::Repository> is a Perl interface to Git, for scripted interactions
with repositories. It's a low-level interface that allows calling any Git
command, whether I<porcelain> or I<plumbing>, including bidirectional
commands such as C<git commit-tree>.

A L<Git::Repository> object simply provides context to the git commands
being run. It is possible to call the  C<command()> and C<run()> methods
against the class itself, and the context (typically I<current working
directory>) will be obtained from the options and environment.

As a low-level interface, it provides no sugar for particular Git
commands. Specifically, it will not prepare environment variables that
individual Git commands may need or use.

However, the C<GIT_DIR> and C<GIT_WORK_TREE> environment variables are
special: if the command is run in the context of a L<Git::Repository>
object, they will be overridden by the object's C<git_dir> and
C<work_tree> attributes, respectively. It is however still possible to
override them if necessary, using the C<env> option.

L<Git::Repository> requires at least Git 1.5.0, and is expected to support
any later version.

See L<Git::Repository::Tutorial> for more code examples.

=head1 CONSTRUCTOR

=head2 new

    Git::Repository->new( %args, $options );

Create a new L<Git::Repository> object, based on an existing Git repository.

Parameters are:

=over 4

=item git_dir => $gitdir

The location of the git repository (F<.git> directory or equivalent).

For backward compatibility with versions 1.06 and before, C<repository>
is accepted in place of C<git_dir> (but the newer name takes precedence).

=item work_tree => $dir

The location of the git working copy (for a non-bare repository).

If C<work_tree> actually points to a subdirectory of the work tree,
L<Git::Repository> will automatically recompute the proper value.

For backward compatibility with versions 1.06 and before, C<working_copy>
is accepted in place of C<work_tree> (but the newer name takes precedence).

=back

If none of the parameter is given, L<Git::Repository> will find the
appropriate repository just like Git itself does. Otherwise, one of
the parameters is usually enough,
as L<Git::Repository> can work out where the other directory (if any) is.

C<new()> also accepts a reference to an option hash which will be used
as the default by L<Git::Repository::Command> when working with the
corresponding L<Git::Repository> instance.

So this:

    my $r = Git::Repository->new(
        # parameters
        work_tree => $dir,
        # options
        {   git => '/path/to/some/other/git',
            env => {
                GIT_COMMITTER_EMAIL => 'book@cpan.org',
                GIT_COMMITTER_NAME  => 'Philippe Bruhat (BooK)',
            },
        }
    );

is equivalent to explicitly passing the option hash to each
C<run()> or C<command()> call.
The documentation for L<Git::Repository::Command> lists all
available options.

Note that Git::Repository and L<Git::Repository::Command> take
great care in finding the option hash wherever it may be in C<@_>,
and to merge multiple option hashes if more than one is provided.

It probably makes no sense to set the C<input> option in C<new()>,
but L<Git::Repository> won't stop you.
Note that on some systems, some git commands may close standard input
on startup, which will cause a C<SIGPIPE>. L<Git::Repository::Command>
will raise an exception.

To create a Git repository and obtain a L<Git::Repository> object
pointing to it, simply do it in two steps:

    # run a clone or init command without an instance,
    # using options like cwd
    Git::Repository->run( ... );
    
    # obtain a Git::Repository instance
    # on the resulting repository
    $r = Git::Repository->new( ... );


=head1 METHODS

=begin Pod::Coverage

    create
    repo_path
    wc_path

=end Pod::Coverage


L<Git::Repository> supports the following methods:

=head2 command

    Git::Repository->command( @cmd );
    $r->command( @cmd );

Runs the git sub-command and options, and returns a L<Git::Repository::Command>
object pointing to the sub-process running the command.

As described in the L<Git::Repository::Command> documentation, C<@cmd>
may also contain a hashref containing options for the command.

=head2 run

    Git::Repository->run( @cmd );
    $r->run( @cmd );

Runs the command and returns the output as a string in scalar context,
or as a list of lines in list context. Also accepts a hashref of options.

Lines are automatically C<chomp>ed.

In addition to the options hashref supported by L<Git::Repository::Command>,
the parameter list can also contain code references, that will be applied
successively to each line of output. The line being processed is in C<$_>,
but the coderef must still return the result string (like C<map>).

If the git command printed anything on stderr, it will be printed as
warnings. For convenience, if the git sub-process exited with status
C<128> (fatal error), or C<129> (usage message), C<run()> will C<die()>.
The exit status values for which C<run()> dies can be modified using
the C<fatal> option (see L<Git::Repository::Command> for details).

The exit status of the command that was just run is accessible as usual
using C<<< $? >> 8 >>>. See L<perlvar> for details about C<$?>.

=head2 git_dir

Returns the repository path.

=head2 work_tree

Returns the working copy path.
Used as current working directory by L<Git::Repository::Command>.

=head2 options

Return the option hash that was passed to C<< Git::Repository->new() >>.

=head2 version

Return the version of git, as given by C<git --version>.

=head2 Version-comparison "operators"

Git evolves very fast, and new features are constantly added.
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

All those methods also accept an option hash, just like the others.

Note that in the C<git.git> repository, several commits have multiple
tags (e.g. C<v1.0.1> and C<v1.0.2> point respectively to C<v1.0.0a>
and C<v1.0.0b>). Pre-1.0.0 versions also have non-standard formats like
C<0.99.9j> or C<1.0rc2>. As of Git::Repository 1.317, the comparison code
converts all version numbers to an internal format before performing
a simple string comparison.

`git --version` appeared in version C<0.99.7>. Before that, there is no
way to know which version of Git one is dealing with.

Prior to C<1.4.0-rc1> (June 2006), compiling a development version of git
would lead C<git --version> to output C<1.x-GIT> (with C<x> in C<0 .. 3>),
which would make comparing versions that are very close a futile exercise.

Other issues exist when comparing development version numbers with one
another. For example, C<1.7.1.1> is greater than both C<1.7.1.1.gc8c07>
and C<1.7.1.1.g5f35a>, and C<1.7.1> is less than both. Obviously,
C<1.7.1.1.gc8c07> will compare as greater than C<1.7.1.1.g5f35a>
(asciibetically), but in fact these two version numbers cannot be
compared, as they are two siblings children of the commit tagged
C<v1.7.1>). For practical purposes, the version-comparison methods
declares them equal.

If one were to compute the set of all possible version numbers (as returned
by C<git --version>) for all git versions that can be compiled from each
commit in the F<git.git> repository, the result would not be a totally ordered
set. Big deal.

Also, don't be too precise when requiring the minimum version of Git that
supported a given feature. The precise commit in git.git at which a given
feature was added doesn't mean as much as the release branch in which that
commit was merged.

=head1 PLUGIN SUPPORT

L<Git::Repository> intentionally has only few methods.
The idea is to provide a lightweight wrapper around git, to be used
to create interesting tools based on Git.

However, people will want to add extra functionality to L<Git::Repository>,
the obvious example being a C<log()> method that returns simple objects
with useful attributes.

Taking the hypothetical C<Git::Repository::Plugin::Hello> module which
source code is listed in the previous reference, the methods it provides
would be loaded and used as follows:

    use Git::Repository qw( Hello );

    my $r = Git::Repository->new();
    print $r->hello();
    print $r->hello_gitdir();

It's possible to load only a selection of methods from the plugin:

    use Git::Repository [ Hello => 'hello' ];

    my $r = Git::Repository->new();
    print $r->hello();

    # dies: Can't locate object method "hello_gitdir"
    print $r->hello_gitdir();

If your plugin lives in another namespace than C<Git::Repository::Plugin::>,
just prefix the fully qualified class name with a C<+>. For example:

    use Git::Repository qw( +MyGit::Hello );

See L<Git::Repository::Plugin> about how to create a new plugin.

=head1 ACKNOWLEDGEMENTS

Thanks to Todd Rinaldo, who wanted to add more methods to
L<Git::Repository>, which made me look for a solution that would preserve
the minimalism of L<Git::Repository>. The C<::Plugin> interface is what
I came up with.

=head1 OTHER PERL GIT WRAPPERS (a.k.a. SEE ALSO)

(This section was written in June 2010. The other Git wrappers have
probably evolved since that time.)

A number of Perl git wrappers already exist. Why create a new one?

I have a lot of ideas of nice things to do with Git as a tool to
manipulate blobs, trees, and tags, that may or may not represent
revision history of a project. A lot of those commands can output
huge amounts of data, which I need to be able to process in chunks.
Some of these commands also expect to receive input.

What follows is a short list of "missing features" that I was looking
for when I looked at the existing Git wrappers on CPAN. They are the
"rational" reason for writing my own (the real reason being of course
"I thought it would be fun, and I enjoyed doing it").

Even though it works well for me and others, L<Git::Repository> has its
own shortcomings: it I<is> a I<low-level interface to Git commands>,
anything complex requires you to deal with input/output handles,
it provides no high-level interface to generate actual Git commands
or process the output of commands (but have a look at the plugins), etc.
One the following modules may therefore be better suited for your needs,
depending on what you're trying to achieve.

=head2 Git.pm

Git.pm was not on CPAN in 2010. It is packaged with Git, and installed
with the system Perl libraries. Not being on CPAN made it harder to
install in any Perl. It made it harder for a CPAN library to depend on it.

It doesn't allow calling C<git init> or C<git clone>.

The C<command_bidi_pipe> function especially has problems:
L<http://kerneltrap.org/mailarchive/git/2008/10/24/3789584>

The L<Git> module from git.git was packaged as a CPAN distribution by
MSOUTH in June 2013.

=head2 Git::Class

L<Git::Class>
depends on Moose, which seems an unnecessary dependency for a simple
wrapper around Git. The startup penalty could become significant for
command-line tools.

Although it supports C<git init> and C<git clone>
(and has methods to call any Git command), it is mostly aimed at
porcelain commands, and provides no way to control bidirectional commands
(such as C<git commit-tree>).


=head2 Git::Wrapper

L<Git::Wrapper>
doesn't support streams or bidirectional commands.

=head2 Git::Sub

(This description was added for completeness in May 2013.)

L<Git::Sub> appeared in 2013, as a set of Git-specific L<System::Sub>
functions. It provide a nice set of C<git::> functions, and has some
limitations (due to the way L<System::Sub> itself works) which don't
impact most Git commands.

L<Git::Sub> doesn't support working with streams.

=head2 Git::Raw

(This description was added for completeness in September 2014,
upon request of the author of L<Git::Raw>.)

L<Git::Raw>
provides bindings to L<libgit2|https://libgit2.github.io/>, a pure C
implementation of the Git core methods. Most of the functions provided by
libgit2 are available. If you have complex workflows, or even if speed is of
the essence, this may be a more attractive solution than shelling out to git.

=head1 BUGS

Since version 1.17, L<Git::Repository> delegates the actual command
execution to L<System::Command>, which has better support for Win32
since version 1.100.

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

=head1 COPYRIGHT

Copyright 2010-2016 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
