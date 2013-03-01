use strict;
use warnings;

use Test::More;
use File::Spec;
use Cwd qw( cwd );
use Test::Git;
use Git::Repository 'Log';

has_git('1.5.1');

# test data
{
    my %commit = (
        '62986785ab0ea38cf05d5e63316b6603054773d1' => {
            tree    => 'f220c525c140f16f92e1b5f146ecfd52015be842',
            parent  => ['442da3f58f803a06f948192cb8fadb68588fc54b'],
            subject => 'commit sign',
            body    => '',
            extra   => '',
            gpgsig  => '-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.4.11 (GNU/Linux)

iEYEABECAAYFAlEDIX0ACgkQn1HmV7l/FKlCtgCgms7O2bBFaDQ18eVqDuZLr3Ol
ymEAoLdHJ9FRDENwKZsDD6XyhoDSAKYF
=NXob
-----END PGP SIGNATURE-----
'
        },
        '442da3f58f803a06f948192cb8fadb68588fc54b' => {
            tree   => 'be53133188aa1dc3184ae9880eaf69537ad3ed5d',
            parent => ['e7dc48c573c644902deda7be4dee9b5ae66b12c2'],
            subject =>
                "Merge tag 'signed' of /data/home/book/src/CPAN/Git-Repository/t/repo",
            body => "signed tag = tag signé

Conflicts:
\thello.txt
",
            extra    => '',
            mergetag => 'object e7dc48c573c644902deda7be4dee9b5ae66b12c2
type commit
tag signed
tagger Philippe Bruhat (BooK) <book@cpan.org> 1359158971 +0100

signed tag
-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.4.11 (GNU/Linux)

iEYEABECAAYFAlEDHrsACgkQn1HmV7l/FKkuQQCdG3wIAwOTnxC4LQ0nOdvdp8E0
YWsAn28+jo5C5RGY1UKo58Gz9/6QqUpf
=knDL
-----END PGP SIGNATURE-----
',
        },
        'e7dc48c573c644902deda7be4dee9b5ae66b12c2' => {
            tree    => 'b85525f0c29fb9fe53131730643d7e4feef3574e',
            parent  => ['ffbcf72a22a53c419f85f933c721492cd06df331'],
            subject => 'Hallå',
            body    => '',
            extra   => '',
        },
        '03710c6af0a29cc2a4601e709a1b1b60eefbe7d9' => {
            'tree'    => '8c3c7fbcd903744b20fd7567a1fcefa99133b5bc',
            'parent'  => ['ffbcf72a22a53c419f85f933c721492cd06df331'],
            'subject' => '',
            'body'    => '',
            'extra'   => '',
        },

        'ffbcf72a22a53c419f85f933c721492cd06df331' => {
            tree    => '4b825dc642cb6eb9a060e54bf8d69288fbee4904',
            parent  => [],
            subject => 'empty tree',
            body    => '',
            extra   => '',
        }
    );

    sub check_commit {
        my ($log) = @_;
        my $id = $log->commit;
        return if !exists $commit{$id};
        my $commit = $commit{$id};
        is( $log->tree, $commit->{tree}, "commit $id tree" );
        is_deeply( [ $log->parent ], $commit->{parent}, "commit $id parent" );
        is( $log->subject,  $commit->{subject},  "commit $id subject" );
        is( $log->body,     $commit->{body},     "commit $id body" );
        is( $log->extra,    $commit->{extra},    "commit $id extra" );
        is( $log->gpgsig,   $commit->{gpgsig},   "commit $id gpgsig" );
        is( $log->mergetag, $commit->{mergetag}, "commit $id mergetag" );
    }

    plan tests => 7 * scalar keys %commit;
}

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};

# first create a new empty repository
my $r = test_repository;

# now load the bundle
my @refs = $r->run(
    bundle => 'unbundle',
    File::Spec->catfile( cwd(), qw( t multiline.bundle ) )
);

# and update the refs
for my $line (@refs) {
    my ( $sha1, $ref ) = split / /, $line;
    $r->run( 'update-ref', $ref => $sha1 );
}

# test!
my $iter = $r->log;
while ( my $log = $iter->next ) {
    check_commit($log);
}

