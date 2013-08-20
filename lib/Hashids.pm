package Hashids;
use 5.008005;
use strict;
use warnings;
use utf8;

our $VERSION = "0.03";

use Moo;
use Scalar::Util 'looks_like_number';
use List::MoreUtils 'firstidx';

has salt => ( is => 'ro', default => '' );
has minHashLength => (
    is  => 'ro',
    isa => sub {
        die "$_[0] is not a number!" unless looks_like_number $_[0];
    },
    default => sub {0}
);

has alphabet => (
    is      => 'rwp',
    default => sub {'xcS4F6h89aUbideAI7tkynuopqrXCgTE5GBKHLMjfRsz'}
);
has seps   => ( is => 'rwp', default => sub { [] } );
has guards => ( is => 'rwp', default => sub { [] } );

sub BUILDARGS {
    my ( $class, @args ) = @_;
    unshift @args, 'salt' if @args % 2 == 1;

    return {@args};
}

sub BUILD {
    my $self = shift;

    my @alphabet = split //, $self->alphabet;

    die "@alphabet must contain at least 4 characters"
        unless @alphabet >= 4;
    {
        my %u;
        die "@alphabet must contain unique characters"
            if scalar grep { $u{$_}++ } @alphabet;
    }

    # probably in _build_seps
    my @primes = ( 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43 );
    for my $prime (@primes) {
        if ( my $ch = $alphabet[ $prime - 1 ] ) {
            my $seps = $self->seps;
            push @$seps, $ch;
            $self->_set_seps($seps);

            # inefficient, I think...
            my $alphabet = $self->alphabet;
            $alphabet =~ s/$ch/ /g;
            $self->_set_alphabet($alphabet);
        }
    }

    # this too, in _build_guards
    my @sepIndices = ( 0, 4, 8, 12 );
    for my $index (@sepIndices) {
        my $seps = $self->seps;
        if ( my $sep = $seps->[$index] ) {
            my $guards = $self->guards;
            push @$guards, $sep;
            $self->_set_guards($guards);

            # ewww
            my $s = $self->seps;
            splice @$s, $index, 1;
            $self->_set_seps($s);
        }
    }

    # another inefficiency
    my $alphabet = $self->alphabet;
    $alphabet =~ s/\s//g;
    $self->_set_alphabet(
        $self->_consistentShuffle( $alphabet, $self->salt ) );
}

sub encrypt {
    my ( $self, @num ) = @_;

    return '' unless @num;
    map { return '' unless looks_like_number $_ } @num;

    $self->_encode( \@num );
}

sub decrypt {
    my ( $self, $hash ) = @_;
    return unless $hash;
    $self->_decode($hash);
}

sub _encode {
    my ( $self, $num, $alphabet, $salt, $minHashLength ) = @_;

    $alphabet      ||= $self->alphabet;
    $salt          ||= $self->salt;
    $minHashLength ||= $self->minHashLength;

    my $res = '';
    my @seps = split //, $self->_consistentShuffle( $self->seps, $num );
    my $lotteryChar = '';

    for ( my $i = 0; $i != @$num; $i++ ) {
        my $number = $num->[$i];

        unless ($i) {
            my $lotterySalt = join '-', @$num;
            for ( my $j = 0; $j != @$num; $j++ ) {
                $lotterySalt .= '-' . ( $num->[$j] + 1 ) * 2;
            }

            my @lottery = split //,
                $self->_consistentShuffle( $alphabet, $lotterySalt );
            $res .= $lotteryChar = $lottery[0];

            $alphabet =~ s/$lotteryChar//g;
            $alphabet = $lotteryChar . $alphabet;
        }

        $alphabet = $self->_consistentShuffle( $alphabet,
            ( ord($lotteryChar) & 12345 ) . $salt );
        $res .= $self->_hash( $number, $alphabet );

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

        my $guards     = $self->guards;
        my $guardIndex = $firstIndex % @$guards;
        my $guard      = $guards->[$guardIndex];

        $res = join '', $guard, $res;
        if ( length($res) < $minHashLength ) {
            $guardIndex = ( $guardIndex + length($res) ) % @$guards;
            $guard      = $guards->[$guardIndex];

            $res .= $guard;
        }
    }

    while ( length($res) < $minHashLength ) {
        my @alphabet = split //, $alphabet;
        my @pad = ( ord( $alphabet[1] ), ord( $alphabet[0] ) );
        my $padLeft = $self->_encode( \@pad, $alphabet, $salt );
        my $padRight = $self->_encode( \@pad, $alphabet, join( '', @pad ) );

        $res = join '', $padLeft, $res, $padRight;
        my $excess = length($res) - $minHashLength;

        if ( $excess > 0 ) {
            $res = substr( $res, $excess / 2, $minHashLength );
        }

        $alphabet
            = $self->_consistentShuffle( $alphabet, join( '', $salt, $res ) );
    }

    $res;
}

sub _decode {
    my ( $self, $hash ) = @_;

    my $res = [];

    if ($hash) {
        my $orig        = $hash;
        my $alphabet    = '';
        my $lotteryChar = '';

        my $guards = $self->guards;
        for my $guard (@$guards) {
            $hash =~ s/$guard/ /g;
        }
        my @hashSplit = split / /, $hash;

        my $i = 0;
        if ( @hashSplit == 3 or @hashSplit == 2 ) {
            $i = 1;
        }

        $hash = $hashSplit[$i];

        my $seps = $self->seps;
        for my $sep (@$seps) {
            $hash =~ s/$sep/ /g;
        }

        my @hash = split / /, $hash;

        for ( my $i = 0; $i != @hash; $i++ ) {
            my $subHash = $hash[$i];
            if ($subHash) {
                unless ($i) {
                    $lotteryChar = substr( $hash, 0, 1 );
                    $subHash = substr( $subHash, 1 );
                    my $sa = $self->alphabet;
                    $sa =~ s/$lotteryChar//;
                    $alphabet = $lotteryChar . $sa;
                }

                if ( $alphabet and $lotteryChar ) {
                    $alphabet = $self->_consistentShuffle( $alphabet,
                        ( ord($lotteryChar) & 12345 ) . $self->salt );
                    push @$res, $self->_unhash( $subHash, $alphabet );

                }
            }
        }

        if ( $self->encrypt(@$res) ne $orig ) {
            $res = [];
        }
    }

    @$res == 1 ? $res->[0] : $res;
}

sub _consistentShuffle {
    my ( $self, $alphabet, $salt ) = @_;

    my $res = '';

    if ( ref $alphabet eq 'ARRAY' ) {
        $alphabet = join '', @$alphabet;
    }
    if ( ref $salt eq 'ARRAY' ) {
        $salt = join '', @$salt;
    }

    if ($alphabet) {
        my @alphabet = split //, $alphabet;
        my @salt     = split //, $salt;
        my @sort;

        push @salt, '' unless @salt;

        push @sort, ( ord || 0 ) for @salt;

        for ( my $i = 0; $i != @sort; $i++ ) {
            my $add = 1;
            for ( my $k = $i; $k != @sort + $i - 1; $k++ ) {
                my $next = ( $k + 1 ) % @sort;
                ($add)
                    ? ( $sort[$i] += $sort[$next] + ( $k * $i ) )
                    : ( $sort[$i] -= $sort[$next] );
                $add = !$add;
            }
            $sort[$i] = abs $sort[$i];
        }

        my $i = 0;
        while (@alphabet) {
            my $pos = $sort[$i];
            $pos %= @alphabet if $pos >= @alphabet;
            $res .= $alphabet[$pos];
            splice @alphabet, $pos, 1;

            $i = ++$i % @sort;
        }
    }

    $res;
}

sub _hash {
    my ( $self, $num, $alphabet ) = @_;

    my $hash = '';
    my @alphabet = split //, $alphabet;

    do {
        $hash = join '', $alphabet[ $num % @alphabet ], $hash;
        $num = int( $num / @alphabet );
    } while ($num);

    $hash;
}

sub _unhash {
    my ( $self, $hash, $alphabet ) = @_;

    my $num = 0;
    my $pos;

    my @hash = split //, $hash;
    for ( my $i = 0; $i < @hash; $i++ ) {
        $pos = firstidx { $_ eq $hash[$i] } split //, $alphabet;
        $num += $pos * ( length($alphabet)**( @hash - $i - 1 ) );
    }

    $num;
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
    my $numbers = $hashids->decrypt('eGtrS8');  # [1, 2, 3]

=head1 DESCRIPTION

This is a port of the Hashids JavaScript library for Perl.

Hashids was designed for use in URL shortening, tracking stuff,
validating accounts or making pages private (through abstraction.)
Instead of showing items as C<1>, C<2>, or C<3>, you could show them as
C<b9iLXiAa>, C<EATedTBy>, and C<Aaco9cy5>.  Hashes depend on your salt
value.

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
simple scalar if it is a single number, or an arrayref of numbers if it
decrypted a set.  Use L<ref> on the result to ensure proper usage.

=back

=head1 SEE ALSO

L<Hashids|http://www.hashids.org>

=head1 LICENSE

Copyright (C) Zak B. Elep.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=head1 AUTHOR

Zak B. Elep E<lt>zakame@cpan.orgE<gt>

Original Hashids JavaScript library written by L<Ivan
Akimov|http://twitter.com/ivanakimov>

=head1 THANKS

Props to L<Jofell Gallardo|http://twitter.com/jofell> for pointing this
excellent project to me in the first place.

=cut

