use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Git::Repository',
    AUTHOR              => 'Philippe Bruhat (BooK) <book@cpan.org>',
    VERSION_FROM        => 'lib/Git/Repository.pm',
    ABSTRACT_FROM       => 'lib/Git/Repository.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
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
