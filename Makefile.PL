use strict;
use warnings;
use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Git::Repository',
    AUTHOR              => 'Philippe Bruhat (BooK) <book@cpan.org>',
    VERSION_FROM        => 'lib/Git/Repository.pm',
    ABSTRACT_FROM       => 'lib/Git/Repository.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'List::Util' => 0,
        'File::Spec' => 0,
        'File::Path' => 0,
        'IPC::Open3' => 0,
        'Cwd' => 0,
        'System::Command' => '1.01',
    },
    META_MERGE => {
        resources => {
            repository => 'http://github.com/book/Git-Repository',
        },
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Git-Repository-*' },
    LICENSE             => 'perl',
);
