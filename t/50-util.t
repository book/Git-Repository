use strict;
use warnings;
use Test::More;

use Git::Repository::Util qw( cmp_git );

plan tests => 1;

is_deeply(
    [
        sort cmp_git qw(
          1.7.4.rc1 1.9.3 1.7.0.rc0 2.0.0.rc2 1.2.3 1.8.3.4 1.7.1.3 1.8.2.1
          2.3.0.rc1 2.0.0.rc1 1.7.12.rc0 1.6.3.rc1 1.4.3.3 2.0.3
          )
    ],
    [
        qw(
          1.2.3 1.4.3.3 1.6.3.rc1 1.7.0.rc0 1.7.1.3 1.7.4.rc1 1.7.12.rc0
          1.8.2.1 1.8.3.4 1.9.3 2.0.0.rc1 2.0.0.rc2 2.0.3 2.3.0.rc1
          )
    ],
    'cmp_git'
);
