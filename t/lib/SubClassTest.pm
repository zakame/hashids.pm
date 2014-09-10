package SubClassTest;
use Moo;
extends 'Hashids';

has extra_number => ( is => 'ro', required => 1 );
has '+salt' => ( default => sub {'I want peppers'} );

around encode => sub {
    my ( $orig, $self, @args ) = @_;
    $self->$orig( $self->extra_number, @args );
};

1;
