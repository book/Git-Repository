#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Git::Repository' );
}

diag( "Testing Git::Repository $Git::Repository::VERSION, Perl $], $^X" );
