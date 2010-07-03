use strict;
use warnings;
use Test::More;
use Scalar::Util qw( looks_like_number );
use Git::Repository;

plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_has_git('git');

# get the git version
my ($version) = Git::Repository->run('--version') =~ /git version (.*)/g;
diag "git version $version";

# other versions based on the current one
my @version = split /\./, $version;
my ( @lesser, @greater );
for ( 0 .. $#version ) {
    local $" = '.';
    my @v = @version;
    next if !looks_like_number( $v[$_] );
    $v[$_]++;
    push @greater, "@v";
    next if 0 > ( $v[$_] -= 2 );
    push @lesser, "@v";
}

# more complex comparisons
my @true = (
    [ '1.7.2.rc0.13.gc9eaaa', 'version_eq', '1.7.2.rc0.13.gc9eaaa' ],
    [ '1.7.2.rc0.13.gc9eaaa', 'version_ge', '1.7.2.rc0.13.gc9eaaa' ],
    [ '1.7.2.rc0.13.gc9eaaa', 'version_le', '1.7.2.rc0.13.gc9eaaa' ],
    [ '1.7.1',                'version_gt', '1.7.1.rc0' ],
    [ '1.7.1.rc1',            'version_gt', '1.7.1.rc0' ],
    [ '1.3.2',                'version_gt', '0.99' ],
    [ '1.7.2.rc0.13.gc9eaaa', 'version_gt', '1.7.0.4' ],
    [ '1.7.1.rc2',            'version_gt', '1.7.1.rc1' ],
    [ '1.7.2.rc0.1.g078e',    'version_gt', '1.7.2.rc0' ],
    [ '1.7.2.rc0.10.g1ba5c',  'version_gt', '1.7.2.rc0.1.g078e' ],
    [ '1.7.1.1',              'version_gt', '1.7.1.1.gc8c07' ],
    [ '1.7.1.1',              'version_gt', '1.7.1.1.g5f35a' ],
    [ '1.0.0b',               'version_gt', '1.0.0a' ],
    [ '1.0.3',                'version_gt', '1.0.0a' ],
    [ '1.7.0.4',              'version_ne', '1.7.2.rc0.13.gc9eaaa' ],
    [ '1.7.1.rc1',            'version_ne', '1.7.1.rc2' ],
    [ '1.0.0a',               'version_ne', '1.0.0' ],
    [ '1.4.0.rc1',            'version_le', '1.4.1' ],
    [ '1.0.0a', 'version_gt', '1.0.0', 'TODO' ], # will probably never be done
);

# operator reversal: $a op $b <=> $b rop $a
my %reverse = (
    version_eq => 'version_eq',
    version_ne => 'version_ne',
    version_ge => 'version_le',
    version_gt => 'version_lt',
    version_le => 'version_ge',
    version_lt => 'version_gt',
);
my %negate = (
    version_ne => 'version_eq',
    version_eq => 'version_ne',
    version_ge => 'version_lt',
    version_gt => 'version_le',
    version_le => 'version_gt',
    version_lt => 'version_ge',
);
@true = (
    @true,
    map { [ $_->[2], $reverse{ $_->[1] }, $_->[0], $_->[3] || () ] } @true
);

plan tests => 5 + 6 * @lesser + 6 * @greater + 2 * @true;

my $r = 'Git::Repository';

# version
is( Git::Repository->version(), $version, "git version $version" );

# version_eq
ok( $r->version_eq($version), "$version version_eq $version" );
ok( !$r->version_eq($_), "$version not version_eq $_" ) for @greater, @lesser;

# version_ne
ok( $r->version_ne($_), "$version version_ne $_" ) for @greater, @lesser;
ok( !$r->version_ne($version), "$version not version_ne $version" );

# version_gt
ok( $r->version_gt($_),  "$version version_gt $_" )     for @lesser;
ok( !$r->version_gt($_), "$version not version_gt $_" ) for @greater;

# version_le
ok( $r->version_lt($_),  "$version version_lt $_" )     for @greater;
ok( !$r->version_lt($_), "$version not version_lt $_" ) for @lesser;

# version_le
ok( $r->version_le($_), "$version version_le $_" ) for $version, @greater;
ok( !$r->version_le($_), "$version not version_le $_" ) for @lesser;

# version_ge
ok( $r->version_ge($_), "$version version_ge $_" ) for $version, @lesser;
ok( !$r->version_ge($_), "$version not version_ge $_" ) for @greater;

# test a number of special cases
my $dev;
{

    package Git::Repository::VersionFaker;
    our @ISA = qw( Git::Repository );
    sub run { return "git version $dev" }
}
$r = 'Git::Repository::VersionFaker';

for (@true) {
    ( $dev, my $meth, my $v, $TODO ) = @$_;
    local $TODO = $TODO ? 'version comparison not exhaustive' : '';
    ok( $r->$meth($v), "$dev $meth $v" );
    $meth = $negate{$meth};
    ok( !$r->$meth($v), "$dev not $meth $v" );
}

