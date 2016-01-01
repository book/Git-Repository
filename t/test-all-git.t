BEGIN {
    unless ( $ENV{EXTENDED_TESTING} ) {
        require Test::More;
        Test::More::plan( skip_all => 'these tests are for extended testing' );
    }

    # because Git supports so many environment variables starting with GIT_
    # I decided to pick something that Git won't use (so, not GIT_HOME...)
    unless ( $ENV{LOCAL_GIT_COLLECTION} ) {
        require Test::More;
        Test::More::plan( skip_all => 'use LOCAL_GIT_COLLECTION to point at your local collection of Git builds'
        );
    }
}

use strict;
use warnings;
use Test::More;
use Git::Repository;
use File::Spec;
use Config;

my $git_home = $ENV{LOCAL_GIT_COLLECTION};

my @versions;
{
    opendir my $DH, $git_home or die "Can't opendir $git_home";
    @versions = grep { /^\d/ } readdir $DH;
    closedir $DH
}

# the test script accepts a range of Git versions to test (min, max)
# the default it to test against all available versions
@versions =
  grep { !( $ARGV[0] && Git::Repository::_version_gt( $ARGV[0], $_ ) ) }
  grep { !( $ARGV[1] && Git::Repository::_version_gt( $_,       $ARGV[1] ) ) }
  sort {
    Git::Repository::_version_gt( $a, $b )
      || -Git::Repository::_version_gt( $b, $a )
  } @versions;

plan tests => scalar @versions;

# remove it to avoid infinite loops
delete $ENV{EXTENDED_TESTING};

my $path_sep = $Config::Config{path_sep} || ';';

my @fail;
for my $version (@versions) {
    local $ENV{PATH} = join $path_sep,
      File::Spec->catdir( $git_home, $version, 'bin' ), $ENV{PATH};
    close STDERR;    # don't let the inner prove spoil the output
    `prove -l t`;
    ok( $? == 0, $version );
    push @fail, $version if $?;
}

diag "Test suite failed with Git version:" if @fail;
diag join ' ', splice @fail, 0, 5 while @fail;
