use strict;
use warnings;
use Test::More;
use Git::Repository;
use Git::Repository::Util qw( cmp_git );
use File::Spec;

my $git_home = 'git-collection';

plan skip_all => 'these tests are for extended testing'
  if !$ENV{EXTENDED_TESTING};

plan skip_all => "set the $git_home directory/link to point at your local collection of Git builds"
  if !-d 'git-collection';

my @versions;
{
    opendir my $DH, $git_home or die "Can't opendir $git_home";
    @versions = grep { /^\d/ } readdir $DH;
    closedir $DH
}

# the test script accepts version specifications to limit the number
# of versions tested
my @spec = map {
    /-/
      ? do {    # range
        my ( $min, $max ) = split /-/;
        sub {
            !( $min      && Git::Repository::_version_gt( $min,  $_[0] ) )
              && !( $max && Git::Repository::_version_gt( $_[0], $max ) );
          }
      }
      : do {    # single item
        my $v = $_;
        sub { $_[0] eq $v }
      };
} @ARGV;

# the default it to test against all available versions
if (@spec) {
    @versions = grep {
        my $version = $_;
        my $ok;
        $ok += $_->($version) for @spec;
        $ok;
    } @versions;
}

# sort the versions to test
@versions = sort cmp_git @versions;

plan tests => scalar @versions;

# remove it to avoid infinite loops
delete $ENV{EXTENDED_TESTING};

my @fail;
for my $version (@versions) {
    local $ENV{PATH} = join $Config::Config{path_sep},
      File::Spec->catdir( $git_home, $version, 'bin' ), $ENV{PATH};
    close STDERR;    # don't let the inner prove spoil the output
    `prove -l t`;
    ok( $? == 0, $version );
    push @fail, $version if $?;
}

diag "Test suite failed with Git version:" if @fail;
diag join ' ', splice @fail, 0, 5 while @fail;
