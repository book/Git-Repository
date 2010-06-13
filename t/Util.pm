use strict;
use warnings;
use Git::Repository;

sub git_minimum_version {
    my $min = shift;
    my @min = split /\./, $min;

    # no git
    return if !Git::Repository::Command::_has_git('git');

    # test version
    my ($version) = Git::Repository->run('--version') =~ /git version (.*)/g;
    my @ver = split /\./, $version;
    return (
        $ver[0] > $min[0]
            || (
            $ver[0] == $min[0]
            && ( $ver[1] > $min[1]
                || ( $ver[1] == $min[1] && $ver[2] >= $min[2] ) )
            )
    );

}

1;

