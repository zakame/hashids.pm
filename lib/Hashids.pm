package Hashids;
use 5.008005;
use strict;
use warnings;
use utf8;

our $VERSION = "0.01";

use Moo;
use Scalar::Util 'looks_like_number';

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
        else {
            last;
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

            # smell
            my $lottery
                = $self->_consistentShuffle( $alphabet, $lotterySalt );
            $res .= $lotteryChar = ( split //, $lottery )[0];

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

        # ugly, must refactor
        for ( my $i = 0; $i != @sort; $i++ ) {
            my $add = 1;
            for ( my $k = $i; $k != @sort + $i - 1; $k++ ) {
                my $next = ( $k + 1 ) % @sort;
                if ($add) {
                    $sort[$i] += $sort[$next] + ( $k * $i );
                }
                else {
                    $sort[$i] -= $sort[$next];
                }
                $add = !$add;
            }
            $sort[$i] = abs $sort[$i];
        }

        my $i = 0;
        while (@alphabet) {
            my $pos = $sort[$i];
            if ( $pos >= @alphabet ) {
                $pos %= @alphabet;
            }
            $res .= $alphabet[$pos];
            splice @alphabet, $pos, 1;

            $i = ++$i % @sort;
        }
    }

    $res;
}

sub _hash {
    my ( $self, $num, $alphabet ) = @_;

    # we do too much splits, refactor?
    my $hash = '';
    my @alphabet = split //, $alphabet;

    do {
        $hash = join '', $alphabet[ $num % @alphabet ], $hash;
        $num = int( $num / @alphabet );
    } while ($num);

    $hash;
}

1;
__END__

=encoding utf-8

=head1 NAME

Hashids - generate short hashes from numbers

=head1 SYNOPSIS

    use Hashids;

=head1 DESCRIPTION

Hashids is ...

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

=cut

