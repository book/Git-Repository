use strict;
use warnings;
use 5.006;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Git::Repository',
    license             => 'perl',
    dist_author         => 'Philippe Bruhat (BooK) <book@cpan.org>',
    dist_version_from   => 'lib/Git/Repository.pm',
    requires => {
        'List::Util' => 0,
        'File::Spec' => 0,
        'File::Path' => 0,
        'IPC::Open3' => 0,
        'Cwd' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Git-Repository-*' ],
    meta_merge => {
        resources => {
            repository => 'http://github.com/book/Git-Repository',
        },
    },
    license => 'perl',
);

$builder->create_build_script();
