package Git::Repository::Log;

use strict;
use warnings;

our $VERSION = '1.00';

# a few simple accessors
for my $attr (
    qw(
    commit tree
    author author_name author_email
    committer committer_name committer_email
    author_localtime author_tz author_gmtime
    committer_localtime committer_tz committer_gmtime
    message subject body
    extra
    )
    )
{
    no strict 'refs';
    *$attr = sub { return $_[0]{$attr} };
}
for my $attr (qw( parent )) {
    no strict 'refs';
    *$attr = sub { return @{ $_[0]{$attr} } };
}

sub new {
    my ( $class, @args ) = @_;
    my $self = bless {}, $class;

    # pick up key/values from the list
    while ( my ( $key, $value ) = splice @args, 0, 2 ) {
        if ( $key eq 'parent' ) {
            push @{ $self->{$key} }, $value;
        }
        else {
            $self->{$key} = $value;
        }
    }

    # special case
    $self->{commit} = (split /\s/, $self->{commit} )[0];

    # compute other keys
    (my $message = $self->{message} ) =~ s/^    //gm;
    @{$self}{qw( subject body )} = split /\n/m, $message, 2;
    $self->{body} =~ s/\A\s//gm;

    # author and committer details
    for my $who (qw( author committer )) {
        $self->{$who} =~ /(.*) <(.*)> (.*) (([-+])(..)(..))/;
        my @keys = ( "${who}_name", "${who}_email", "${who}_gmtime",
            "${who}_tz" );
        @{$self}{@keys} = ( $1, $2, $3, $4 );
        $self->{"${who}_localtime"} = $self->{"${who}_gmtime"}
            + ( $5 eq '-' ? -1 : 1 ) * ( $6 * 3600 + $7 * 60 );
    }

    return $self;
}

1;

__END__

