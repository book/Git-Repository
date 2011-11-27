use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Temp qw( tempfile );
use Git::Repository;
use constant MSWin32 => $^O eq 'MSWin32';

has_git('1.4.0');

# setup fake git
my $W = my $V = my $version = Git::Repository->version;
$V =~ s/\.(\d+)\./.@{[$1+1]}./;
$W =~ s/\.(\d+)\./.@{[$1+2]}./;
my $o = { git => fake_git('1.2.3') };    # small one
my $O = { git => fake_git($W) };         # big one

# setup tests (that will fail if the real git is called)
my @true = (
    [ version_eq => '1.2.3',   $o ],     # small
    [ version_ne => $version,  $o ],
    [ version_lt => '1.2.3.5', $o ],
    [ version_le => '1.2.3',   $o ],
    [ version_le => '1.2.3.5', $o ],
    [ version_eq => $W,       $O ],      # big
    [ version_ne => $version, $O ],
    [ version_gt => $version, $O ],
    [ version_ge => $V,       $O ],
    [ version_ge => $W,       $O ],
);

plan tests => 2 + 3 * @true;

# use options in version()
is( Git::Repository->version($o), '1.2.3', "version() options (small git)" );
is( Git::Repository->version($O), $W,      "version() options (big git)" );

# use options in version_eq()
for my $t (@true) {
    my ( $method, @args ) = @$t;
    ok( Git::Repository->$method(@args), "$method() options" );
    ok( Git::Repository->$method( reverse @args ),
        "$method() options (any order)" );
    ok( Git::Repository->$method( @args, 'bonk' ),
        "$method() options (with bogus extra args)"
    );
}

# helper routine to build a fake fit binary
sub fake_git {
    my ($version) = @_;
    my ( $fh, $filename ) =
      tempfile( DIR => 't', UNLINK => 1, MSWin32 ? ( SUFFIX => '.bat' ) : () );
    print {$fh} MSWin32 ? << "WIN32" : << "UNIX";
\@echo git version $version
WIN32
#!$^X
print "git version $version\\n"
UNIX
    close $fh;
    chmod 0755, $filename;
    return $filename;
}

