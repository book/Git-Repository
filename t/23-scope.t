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
{
    no strict 'refs';
    for my $suffix ( '', '::Reaper' ) {
        my $class = "Git::Repository::Command$suffix";
        my $destroy = *{"$class\::DESTROY"}{CODE};
        *{"$class\::DESTROY"} = sub {
            diag "DESTROY $_[0]";
            push @destroyed, refaddr $_[0];
            $destroy->(@_) if $destroy;
        };
    }
}

# test various scope situations and object destruction time
my ( $cmd_addr, $reap_addr );

# test 1
BEGIN { $tests += 5 }
{
    my $cmd = Git::Repository::Command->new('--version');
    $cmd_addr  = refaddr $cmd;
    $reap_addr = refaddr $cmd->{reaper};
    my $fh = $cmd->stdout;
    my $v  = <$fh>;
    is( $v,                $V, 'scope: { $cmd; $fh }' );
    is( scalar @destroyed, 0,  "Destroyed no object yet" );
}
is( scalar @destroyed, 2,          "Destroyed 2 objects" );
is( shift @destroyed,  $cmd_addr,  "... command object was destroyed" );
is( shift @destroyed,  $reap_addr, "... reaper object was destroyed" );
@destroyed = ();

# test 2
BEGIN { $tests += 6 }
{
    my $cmd
        = Git::Repository::Command->new( config => "--file=$file", '--list' );
    $cmd_addr  = refaddr $cmd;
    $reap_addr = refaddr $cmd->{reaper};
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
    is( scalar @destroyed, 0, "Destroyed no object yet" );
}
is( scalar @destroyed, 2,          "Destroyed 2 objects" );
is( shift @destroyed,  $cmd_addr,  "... command object was destroyed" );
is( shift @destroyed,  $reap_addr, "... reaper object was destroyed" );
@destroyed = ();

# test 3
BEGIN { $tests += 3 }
{
    my $fh = Git::Repository::Command->new('--version')->stdout;
    is( scalar @destroyed, 1, "Destroyed 1 object (command)" );
    @destroyed = ();
    my $v = <$fh>;
    is( $v, $V, 'scope: { $fh = cmd->fh }' );
}
is( scalar @destroyed, 1, "Destroyed 1 object (reaper)" );
@destroyed = ();

# test 4
BEGIN { $tests += 1 }
Git::Repository::Command->new('--version');
is( scalar @destroyed, 2, "Destroyed 2 objects (command + reaper)" );
@destroyed = ();

# test 5
BEGIN { $tests += 5 }
{
    my $fh;
    {
        my $cmd = Git::Repository::Command->new('--version');
        $cmd_addr  = refaddr $cmd;
        $reap_addr = refaddr $cmd->{reaper};
        $fh        = $cmd->stdout;
    }
    is( scalar @destroyed, 1,         "Destroyed 1 object (command)" );
    is( shift @destroyed,  $cmd_addr, "... command object was destroyed" );
    @destroyed = ();
    my $v = <$fh>;
    is( $v, $V, 'scope: { $fh = $cmd->fh }; $fh }' );
}
is( scalar @destroyed, 1,          "Destroyed 1 objects (reaper)" );
is( shift @destroyed,  $reap_addr, "... reaper object was destroyed" );
@destroyed = ();

