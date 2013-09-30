use mop;

class SubClassTest extends Hashids {
    has $!extra_number is ro = die "'$!extra_number' is required";

    method new ($class:) {
        $class->next::method( salt => 'I want peppers', @_ );
    }

    method encrypt (@args) {
        unshift @args, $!extra_number;
        $self->next::method(@args);
    }
}

1;
