package main;
use strict;
use warnings;
use Carp;
use mop;

our $VERSION = "0.07";

class Hashids {
    has $!salt is ro          = '';
    has $!minHashLength is ro = 0;
    has $!alphabet is ro      = 'xcS4F6h89aUbideAI7tkynuopqrXCgTE5GBKHLMjfRsz';

    has $!chars is ro  = [];
    has $!seps is ro   = [];
    has $!guards is ro = [];

    method new ($class:) {
        unshift @_, 'salt' if @_ %2 == 1;
        $class->next::method(@_);
    }

    submethod BUILD {
        my $alphabet = $!alphabet;
        my @alphabet = split //, $alphabet;
        my @primes   = ( 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43 );
        my @indices  = ( 0, 4, 8, 12 );

        croak "'$!minHashLength' is not a number!"
            unless $!minHashLength =~ /^\d+$/;
        croak "'@alphabet' must not have spaces"
            if $alphabet =~ /\s/;
        croak "'@alphabet' must contain at least 4 characters"
            unless @alphabet >= 4;
        {
            my %u;
            croak "'@alphabet' must contain unique characters"
                if scalar grep { $u{$_}++ } @alphabet;
        }

        for my $prime (@primes) {
            if ( my $ch = $alphabet[ $prime - 1 ] ) {
                push $!seps, $ch;
                $alphabet =~ s/$ch//g;
            }
        }

        for my $index (@indices) {
            if ( my $sep = $!seps->[$index] ) {
                push $!guards, $sep;
                splice $!seps, $index, 1;
            }
        }

        $!chars = $self->_consistentShuffle( $alphabet, $!salt );
    }

    method encrypt (@num) {
        return '' unless @num;
        map { return '' unless /^\d+$/ } @num;
        $self->_encode( \@num );
    }

    method decrypt ($hash) {
        return unless $hash;
        $self->_decode($hash);
    }

    method _encode ( $num, $chars, $salt, $minHashLength ) {
        $chars         ||= $!chars;
        $salt          ||= $!salt;
        $minHashLength ||= $!minHashLength;

        my $res = '';
        my @seps = split //, $self->_consistentShuffle( $!seps, $num );
        my $lotteryChar = '';

        for ( my $i = 0; $i != @$num; $i++ ) {
            my $number = $num->[$i];

            unless ($i) {
                my $lotterySalt = join '-', @$num;
                for ( my $j = 0; $j != @$num; $j++ ) {
                    $lotterySalt .= '-' . ( $num->[$j] + 1 ) * 2;
                }

                ( $lotteryChar, undef ) = split //,
                    $self->_consistentShuffle( $chars, $lotterySalt ), 2;
                $res .= $lotteryChar;

                $chars =~ s/$lotteryChar//g;
                $chars = $lotteryChar . $chars;
            }

            $chars = $self->_consistentShuffle( $chars,
                ( ord($lotteryChar) & 12345 ) . $salt );
            $res .= $self->_hash( $number, $chars );

            if ( ( $i + 1 ) < @$num ) {
                my $index = ( $number + $i ) % @seps;
                $res .= $seps[$index];
            }
        }

        if ( length($res) < $minHashLength ) {
            my $firstIndex = 0;
            for ( my $i = 0; $i != @$num; $i++ ) {
                $firstIndex += ( $i + 1 ) * $num->[$i];
            }

            my $guardIndex = $firstIndex % $!guards;
            my $guard      = $!guards->[$guardIndex];

            $res = $guard . $res;
            if ( length($res) < $minHashLength ) {
                $guardIndex = ( $guardIndex + length($res) ) % $!guards;
                $guard      = $!guards->[$guardIndex];

                $res .= $guard;
            }
        }

        while ( length($res) < $minHashLength ) {
            my @pad = map {ord} reverse split // => $chars, 2;
            my $padLeft  = $self->_encode( \@pad, $chars, $salt );
            my $padRight = $self->_encode( \@pad, $chars, "@pad" );

            $res = $padLeft . $res . $padRight;
            my $excess = length($res) - $minHashLength;

            if ( $excess > 0 ) {
                $res = substr( $res, $excess / 2, $minHashLength );
            }

            $chars = $self->_consistentShuffle( $chars, $salt . $res );
        }

        $res;
    }

    method _decode ($hash) {
        return unless $hash;
        return unless defined wantarray;

        my $res = [];

        my $orig        = $hash;
        my $lotteryChar = '';
        my $splitIndex  = 0;

        my $chars  = $!chars;
        my $guards = $!guards;
        my $seps   = $!seps;

        for my $guard (@$guards) {
            $hash =~ s/$guard/ /g;
        }
        my @hashSplit = split / /, $hash;
        if ( @hashSplit == 3 or @hashSplit == 2 ) {
            $splitIndex = 1;
        }
        $hash = $hashSplit[$splitIndex];
        for my $sep (@$seps) {
            $hash =~ s/$sep/ /g;
        }

        my @subHash = split / /, $hash;
        for ( my $i = 0; $i != @subHash; $i++ ) {
            if ( my $subHash = $subHash[$i] ) {
                unless ($i) {
                    $lotteryChar = substr( $hash, 0, 1 );
                    $subHash = substr( $subHash, 1 );
                    $chars =~ s/$lotteryChar//;
                    $chars = $lotteryChar . $chars;
                }

                if ( $chars and $lotteryChar ) {
                    $chars = $self->_consistentShuffle( $chars,
                        ( ord($lotteryChar) & 12345 ) . $!salt );
                    push @$res, $self->_unhash( $subHash, $chars );
                }
            }
        }

        #return unless $self->Hashids::encrypt(@$res) eq $orig;
        return
            unless mop::get_meta('Hashids')->get_method('encrypt')
            ->execute( $self, $res ) eq $orig;

        wantarray ? @$res : @$res == 1 ? $res->[0] : $res;
    }

    method _consistentShuffle ( $alphabet, $salt ) {
        my $res = '';

        return $res unless $alphabet;

        if ( ref $alphabet eq 'ARRAY' ) {
            $alphabet = join '', @$alphabet;
        }
        if ( ref $salt eq 'ARRAY' ) {
            $salt = join '', @$salt;
        }

        my @alphabet = split //, $alphabet;
        my @salt     = split //, $salt;
        my @sort;

        push @salt, '' unless @salt;
        push @sort, ( ord || 0 ) for @salt;

        for ( my $i = 0; $i != @sort; $i++ ) {
            my $add = 1;
            for ( my $j = $i; $j != @sort + $i - 1; $j++ ) {
                my $next = ( $j + 1 ) % @sort;
                ($add)
                    ? ( $sort[$i] += $sort[$next] + ( $j * $i ) )
                    : ( $sort[$i] -= $sort[$next] );
                $add = !$add;
            }
            $sort[$i] = abs $sort[$i];
        }

        my $k = 0;
        while (@alphabet) {
            my $pos = $sort[$k];
            $pos %= @alphabet if $pos >= @alphabet;
            $res .= $alphabet[$pos];
            splice @alphabet, $pos, 1;

            $k = ++$k % @sort;
        }

        $res;
    }

    method _hash ( $num, $alphabet ) {
        my $hash = '';
        my @alphabet = split //, $alphabet;

        do {
            $hash = $alphabet[ $num % @alphabet ] . $hash;
            $num  = int( $num / @alphabet );
        } while ($num);

        $hash;
    }

    method _unhash ( $hash, $alphabet ) {
        my $num = 0;
        my $pos;

        my @hash = split //, $hash;
        for ( my $i = 0; $i < @hash; $i++ ) {
            $pos = index $alphabet, $hash[$i];
            $num += $pos * ( length($alphabet)**( @hash - $i - 1 ) );
        }

        $num;
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Hashids - generate short hashes from numbers

=head1 SYNOPSIS

    use Hashids;
    my $hashids = Hashids->new('this is my salt');

    # encrypt a single number
    my $hash = $hashids->encrypt(123);          # 'a79'
    my $number = $hashids->decrypt('a79');      # 123

    # or a list
    $hash = $hashids->encrypt(1, 2, 3);         # 'eGtrS8'
    my @numbers = $hashids->decrypt('eGtrS8');  # (1, 2, 3)

    # also get results in an arrayref
    my $numbers = $hashids->decrypt('eGtrS8');  # [1, 2, 3]

=head1 DESCRIPTION

This is a port of the Hashids JavaScript library for Perl.

Hashids was designed for use in URL shortening, tracking stuff,
validating accounts or making pages private (through abstraction.)
Instead of showing items as C<1>, C<2>, or C<3>, you could show them as
C<b9iLXiAa>, C<EATedTBy>, and C<Aaco9cy5>.  Hashes depend on your salt
value.

This implementation follows the v0.1.4 release of hashids.js.  The
current version of hashids.js (v0.3.0) uses a new algorithm, so the
hashes produced by this Perl implementation will probably I<not> decrypt
correctly on the new JavaScript version.  I will be implementing the new
algorithm very soon, and maybe probably allow some way to toggle between
algorithms.

=head1 METHODS

=over

=item  my $hashids = Hashids->new();

Make a new Hashids object.  This constructor accepts a few options:

=over

=item  salt => 'this is my salt'

Salt string, this should be unique per Hashid object.

=item  alphabet => 'abcdefghij'

Alphabet set to use.  This is optional as Hashids comes with a default
set suitable for URL shortening.

=item  minHashLength => 5

Minimum hash length.  Use this to control how long the generated hash
string should be.

=back

You can also construct with just a single argument for the salt:

    my $hashids = Hashids->new('this is my salt');

=item  my $hash = $hashids->encrypt($x, [$y, $z, ...]);

Encrypt a single number (or a list of numbers) into a hash string.

=item  my $number = $hashids->decrypt($hash);

Decrypt a hash string into its number (or numbers.)  Returns either a
simple scalar if it is a single number, an arrayref of numbers if it
decrypted a set, or C<undef> if given bad input.  Use L<ref> on the
result to ensure proper usage.

You can also retrieve the result as a proper list by assigning it to an
array variable, by doing so you will always get a list of one or more
numbers that are decrypted from the hash, or the empty list if none were
found:

    my @numbers = $hashids->decrypt($hash);

=back

=head1 SEE ALSO

L<Hashids|http://www.hashids.org>

=head1 LICENSE

Copyright (C) Zak B. Elep.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=head1 AUTHOR

Zak B. Elep E<lt>zakame@cpan.orgE<gt>

Original Hashids JavaScript library written by L<Ivan
Akimov|http://twitter.com/ivanakimov>

=head1 THANKS

Props to L<Jofell Gallardo|http://twitter.com/jofell> for pointing this
excellent project to me in the first place.

=cut

