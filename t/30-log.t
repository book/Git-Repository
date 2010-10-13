use strict;
use warnings;
use Test::More;
use Git::Repository::Log;

# no need for git here
my @tests = (
    [   [   commit => '2bb91232215d1863c6b8cb3737d8d8ed952f0210',
            tree   => '23a9197db125bb757e80462639cd7a2b288a9473',
            parent => 'd747608fb582710f1d6885e0a94c585024ae44bc',
            author =>
                'Philippe Bruhat (BooK) <book@cpan.org> 1282408639 +0200',
            committer =>
                'Philippe Bruhat (BooK) <book@cpan.org> 1282408639 +0200',
            message => "    MANIFEST update\n",
            extra   => << 'EXTRA',
'diff --git a/MANIFEST b/MANIFEST
index 86a12a9..4766ee3 100644
--- a/MANIFEST
+++ b/MANIFEST
@@ -14,5 +14,8 @@ t/10-new_fail.t
 t/11-create.t
 t/20-simple.t
 t/22-backward.t
+t/25-mixins.t
+t/Git/Repository/Mixin/Hello.pm
+t/Git/Repository/Mixin/Hello2.pm
 t/pod-coverage.t
 t/pod.t
EXTRA
        ] => {
            commit => '2bb91232215d1863c6b8cb3737d8d8ed952f0210',
            tree   => '23a9197db125bb757e80462639cd7a2b288a9473',
            parent => ['d747608fb582710f1d6885e0a94c585024ae44bc'],
            author =>
                'Philippe Bruhat (BooK) <book@cpan.org> 1282408639 +0200',
            author_gmtime    => '1282408639',
            author_localtime => '1282415839',
            author_tz        => '+0200',
            author_name      => 'Philippe Bruhat (BooK)',
            author_email     => 'book@cpan.org',
            committer =>
                'Philippe Bruhat (BooK) <book@cpan.org> 1282408639 +0200',
            committer_name      => 'Philippe Bruhat (BooK)',
            committer_email     => 'book@cpan.org',
            committer_gmtime    => '1282408639',
            committer_localtime => '1282415839',
            committer_tz        => '+0200',
            message             => "    MANIFEST update\n",
            subject             => "MANIFEST update",
            body                => '',
            extra               => << 'EXTRA',
'diff --git a/MANIFEST b/MANIFEST
index 86a12a9..4766ee3 100644
--- a/MANIFEST
+++ b/MANIFEST
@@ -14,5 +14,8 @@ t/10-new_fail.t
 t/11-create.t
 t/20-simple.t
 t/22-backward.t
+t/25-mixins.t
+t/Git/Repository/Mixin/Hello.pm
+t/Git/Repository/Mixin/Hello2.pm
 t/pod-coverage.t
 t/pod.t
EXTRA
        }
    ],
    [   [   commit => 'f4ceeb0b81da0ae70388340f41dd574db585778b',
            tree   => '7a24e56ba5f15011e95dd397969000a87a141ba1',
            parent => '1c8f8d241bb94f4c10cc6639a23accd53b7ba93e',
            parent => '9adb8a6926b6a93a6aca057e6d01443f73464afa',
            author =>
                'Philippe Bruhat (BooK) <book@cpan.org> 1282050772 -0200',
            committer =>
                'Philippe Bruhat (BooK) <book@cpan.org> 1282050772 -0200',
            message => << 'MESSAGE',
    Merge branch 'master' into git-log
    
    Conflicts:
        lib/Git/Repository.pm
MESSAGE
            extra => '',
        ] => {
            commit => 'f4ceeb0b81da0ae70388340f41dd574db585778b',
            tree   => '7a24e56ba5f15011e95dd397969000a87a141ba1',
            parent => [
                '1c8f8d241bb94f4c10cc6639a23accd53b7ba93e',
                '9adb8a6926b6a93a6aca057e6d01443f73464afa'
            ],
            author =>
                'Philippe Bruhat (BooK) <book@cpan.org> 1282050772 -0200',
            author_gmtime    => '1282050772',
            author_localtime => '1282043572',
            author_tz        => '-0200',
            author_name      => 'Philippe Bruhat (BooK)',
            author_email     => 'book@cpan.org',
            committer =>
                'Philippe Bruhat (BooK) <book@cpan.org> 1282050772 -0200',
            committer_name      => 'Philippe Bruhat (BooK)',
            committer_email     => 'book@cpan.org',
            committer_gmtime    => '1282050772',
            committer_localtime => '1282043572',
            committer_tz        => '-0200',
            message             => << 'MESSAGE',
    Merge branch 'master' into git-log
    
    Conflicts:
        lib/Git/Repository.pm
MESSAGE
            subject => q{Merge branch 'master' into git-log},
            body    => << 'BODY',
Conflicts:
    lib/Git/Repository.pm
BODY
            extra => '',
        }
    ],
    [   [   commit => '940ca54b6b3ac6a3c03349c8b4515b5536064068',
            tree   => 'fb10bfa47f17e73b8575bbc8b9558453f987ea6f',
            parent => '3739c7e10ee6bc0b39c776bf43a86ee3f53f3d68',
            author =>
                'Aristotle Pagaltzis <pagaltzis@gmx.de> 1282387388 +0800',
            committer =>
                'Philippe Bruhat (BooK) <book@cpan.org> 1282389828 +0800',
            message => "    small POD copyedit\n",
            extra   => '',
        ] => {
            commit => '940ca54b6b3ac6a3c03349c8b4515b5536064068',
            tree   => 'fb10bfa47f17e73b8575bbc8b9558453f987ea6f',
            parent => ['3739c7e10ee6bc0b39c776bf43a86ee3f53f3d68'],
            author =>
                'Aristotle Pagaltzis <pagaltzis@gmx.de> 1282387388 +0800',
            author_name      => 'Aristotle Pagaltzis',
            author_email     => 'pagaltzis@gmx.de',
            author_gmtime    => '1282387388',
            author_localtime => '1282416188',
            author_tz        => '+0800',
            committer =>
                'Philippe Bruhat (BooK) <book@cpan.org> 1282389828 +0800',
            committer_name      => 'Philippe Bruhat (BooK)',
            committer_email     => 'book@cpan.org',
            committer_gmtime    => '1282389828',
            committer_localtime => '1282418628',
            committer_tz        => '+0800',
            message             => "    small POD copyedit\n",
            subject             => "small POD copyedit",
            body                => '',
            extra               => '',
        },
    ]
);
my @methods = qw( commit tree parent );

plan tests => 3 * @tests;

for my $t (@tests) {
    my ( $args, $expected ) = @$t;
    my $got = Git::Repository::Log->new(@$args);

    isa_ok( $got, 'Git::Repository::Log' );
    is_deeply( $got, $expected, "commit $args->[1]" );

    my $method = shift @methods;
    if ( $method eq 'parent' ) {
        is_deeply(
            [ $got->$method ],
            $expected->{$method},
            "$method accessor"
        );
    }
    else {
        is( $got->$method, $expected->{$method}, "$method accessor" );
    }
}

