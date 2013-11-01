use strict;
use warnings;
use Test::More;
use File::Find;

my @modules;
find( sub { push @modules, $File::Find::name if /\.pm$/ }, 'lib' );

plan tests => scalar @modules;

@modules = reverse sort map { s!/!::!g; s/\.pm$//; s/^lib:://; $_ } @modules;

# load in isolation
local $ENV{PERL5LIB} = join $Config::Config{path_sep} || ';', @INC;
for my $module (@modules) {
    `$^X -M$module -e1`;
    is( $? >> 8, 0, "perl -M$module -e1" );
}
