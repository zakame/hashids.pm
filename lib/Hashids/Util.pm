package Hashids::Util;

use strict;
use warnings;

our ( @EXPORT_OK, %EXPORT_TAGS );

BEGIN {
    use Exporter 'import';
    @EXPORT_OK = qw(consistent_shuffle to_alphabet from_alphabet any bignum);
    %EXPORT_TAGS = ( all => \@EXPORT_OK );
}

use List::Util 'reduce';
use Math::BigInt;

use namespace::clean -except => [qw(import)];

sub consistent_shuffle {
    my ( $alphabet, $salt ) = @_;

    return ('') unless $alphabet;

    my @alphabet
        = ref $alphabet eq 'ARRAY' ? @$alphabet : split // => $alphabet;
    return @alphabet unless $salt;
    my @salt = ref $salt eq 'ARRAY' ? @$salt : split //, $salt;

    for ( my ( $i, $v, $p ) = ( $#alphabet, 0, 0 ); $i > 0; $i--, $v++ ) {
        $p += my $int = ord $salt[ $v %= @salt ];
        my $j = ( $int + $v + $p ) % $i;

        @alphabet[ $j, $i ] = @alphabet[ $i, $j ];
    }

    @alphabet;
}

sub to_alphabet {
    my ( $num, $alphabet ) = @_;

    my $hash = '';
    my @alphabet
        = ref $alphabet eq 'ARRAY' ? @$alphabet : split // => $alphabet;

    $num = bignum($num);
    do {
        $hash = $alphabet[ $num % @alphabet ] . $hash;
        $num /= @alphabet;
    } while ( $num != 0 );

    $hash;
}

sub from_alphabet {
    my ( $hash, $alphabet ) = @_;

    my @alphabet
        = ref $alphabet eq 'ARRAY' ? @$alphabet : split // => $alphabet;

    my $num = reduce { bignum($a) * @alphabet + $b }
    map { index join( '' => @alphabet ), $_ } split // => $hash;

    "$num";
}

sub any (&@) {                 ## no critic (ProhibitSubroutinePrototypes)
    my $f = shift;
    for (@_) {
        return 1 if $f->();
    }
    0;
}

sub bignum {
    my $n = Math::BigInt->bzero();
    $n->round_mode('zero');
    $n->badd("@{[shift]}");
}

1;
__END__

=encoding utf-8

=for stopwords arrayrefs bignum

=head1 NAME

Hashids::Util - Shuffling and conversion functions for Hashids

=head1 SYNOPSIS

    use Hashids::Util
        qw( consistent_shuffle to_alphabet from_alphabet any bignum );

=head1 DESCRIPTION

C<Hashids::Util> provides utility functions for L<Hashids> for
consistent shuffling of alphabets, conversion of numbers to hash
strings, and others.  These are originally included as private
functions, but are now provided here as a separate module as they can be
general enough to be used in other code.

C<Hashids::Util> does not export any functions by default.

=head1 FUNCTIONS

=head2 consistent_shuffle

    my @shuffled_alphabet = consistent_shuffle( $alphabet, $salt );

Given an alphabet and salt, produce a shuffled alphabet.  Both alphabet
and salt can be either strings or arrayrefs of characters.

=head2 to_alphabet

    my $hash = to_alphabet( $num, $alphabet );

Produce a hash string given a number and alphabet.  The given alphabet
may be a string or an arrayref of characters.

=head2 from_alphabet

    my $num = from_alphabet( $hash, $alphabet );

Produce a number from the given hash string and alphabet.  The given
alphabet may be a string or arrayref of characters.

=head2 any

    print "At least one non-negative value"
    any { $_ >= 0 } @list_of_numbers;

Returns a true value if any item in the given list meets the given
criterion.  Returns false otherwise.  Adapted from
L<List::MoreUtils::PP>.

=head2 bignum

   my $bignum = bignum( '1_152_921_504_606_846_976' );

Construct a L<Math::BigInt> scalar from the given number.

=head1 SEE ALSO

L<Hashids>

=head1 AUTHOR

Zak B. Elep E<lt>zakame@cpan.orgE<gt>

=cut
