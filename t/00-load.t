use strict;
use warnings;
use Test::More;
use File::Find;

my @modules;
find( sub { push @modules, $File::Find::name if /\.pm$/ }, 'blib/lib' );

plan tests => scalar @modules;

use_ok($_)
    for reverse sort map { s!/!::!g; s/\.pm$//; s/^blib::lib:://; $_ }
    @modules;

diag("Tested Git::Repository $Git::Repository::VERSION, Perl $], $^X" );

