use strict;
use warnings;
use Test::More;
use Test::Git;
use Git::Repository;
use Scalar::Util 'refaddr';

has_git();

plan tests => my $tests;

# the expected output
my $V = "git version " . Git::Repository->version . "\n";
my @C = split /^/m, << 'EOC';
user.name=Philippe Bruhat (BooK)
user.email=book@cpan.org
EOC
my $file = File::Spec->catfile(qw( t config ));

# record destruction
my @destroyed;
my $addr;
{
    my $destroy = \&Git::Repository::Command::DESTROY;
    *Git::Repository::Command::DESTROY = sub {
        diag "DESTROY $_[0]";
        push @destroyed, refaddr $_[0];
        $destroy->(@_);
    };
}

# test various scope situations and object destruction time
# test 1
BEGIN { $tests += 3 }
{
    my $cmd = Git::Repository::Command->new('--version');
    $addr = refaddr $cmd;
    my $fh = $cmd->stdout;
    my $v  = <$fh>;
    is( $v, $V, 'scope: { $cmd; $fh }' );
}
is( scalar @destroyed, 1, "A single Command object was destroyed" );
is( pop @destroyed, $addr, "... expected object was destroyed" );

# test 2
BEGIN { $tests += 4 }
{
    my $cmd
        = Git::Repository::Command->new( config => "--file=$file", '--list' );
    $addr = refaddr $cmd;
    {
        my $fh = $cmd->stdout;
        my $c0 = <$fh>;
        is( $c0, $C[0], 'scope: { $cmd { $fh } { $fh } }' );
    }
    {
        my $fh = $cmd->stdout;
        my $c1 = <$fh>;
        is( $c1, $C[1], 'scope: { $cmd { $fh } { $fh } }' );
    }
}
is( scalar @destroyed, 1, "A single Command object was destroyed" );
is( pop @destroyed, $addr, "... expected object was destroyed" );

# test 3
BEGIN { $tests += 1 }
{
    local $TODO = 'Scope issues with Git::Repository::Command';
    my $fh = Git::Repository::Command->new('--version')->stdout;
    my $v  = <$fh>;
    is( $v, $V, 'scope: { $fh = $cmd->fh }' );
}
is( scalar @destroyed, 1, "A single Command object was destroyed" );

# test 4
BEGIN { $tests += 1 }
Git::Repository::Command->new('--version');
is( scalar @destroyed, 1, "A single Command object was destroyed" );

