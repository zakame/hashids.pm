package Hashids;

our $VERSION = "1.000002";

use Carp;
use Moo;
use POSIX ();
use Math::BigInt;

has salt => ( is => 'ro', default => '' );

has minHashLength => (
    is  => 'ro',
    isa => sub {
        croak "$_[0] is not a number!" unless $_[0] =~ /^\d+$/;
    },
    default => 0
);

has alphabet => (
    is  => 'rwp',
    isa => sub {
        croak "$_[0] must not have spaces"
            if $_[0] =~ /\s/;
        croak "$_[0] must contain at least 16 characters"
            if length $_[0] < 16;
        my %u;
        croak "$_[0] must contain unique characters"
            if grep { $u{$_}++ } split // => $_[0];
    },
    default => sub { join '' => 'a' .. 'z', 'A' .. 'Z', 1 .. 9, 0 }
);

has chars => ( is => 'rwp', init_arg => undef, default => sub { [] } );

has seps => (
    is       => 'rwp',
    init_arg => undef,
    default  => sub {
        my @seps = qw(c f h i s t u);
        [ @seps, map {uc} @seps ];
    },
);

has guards => ( is => 'rwp', init_arg => undef, default => sub { [] } );

sub BUILDARGS {
    my ( $class, @args ) = @_;
    unshift @args, 'salt' if @args % 2 == 1;

    +{@args};
}

sub BUILD {
    my $self = shift;

    my @alphabet = split // => $self->alphabet;
    my ( @seps, @guards );

    my $sepDiv   = 3.5;
    my $guardDiv = 12;

    # seps should contain only chars present in alphabet;
    # alphabet should not contain seps
    for my $sep ( @{ $self->seps } ) {
        push @seps, $sep if grep {/$sep/} @alphabet;
        @alphabet = grep { !/$sep/ } @alphabet;
    }

    @seps = _consistentShuffle( \@seps, $self->salt );

    if ( !@seps || ( @alphabet / @seps ) > $sepDiv ) {
        my $sepsLength = POSIX::ceil( @alphabet / $sepDiv );
        $sepsLength++ if $sepsLength == 1;
        if ( $sepsLength > @seps ) {
            push @seps => splice @alphabet, 0, $sepsLength - @seps;
        }
        # else {
        #     splice @seps, 0, $sepsLength;
        # }
    }

    @alphabet = _consistentShuffle( \@alphabet, $self->salt );
    my $guardCount = POSIX::ceil( @alphabet / $guardDiv );

    @guards
        = @alphabet < 3
        ? splice @seps, 0, $guardCount
        : splice @alphabet, 0, $guardCount;

    $self->_set_chars( \@alphabet );
    $self->_set_seps( \@seps );
    $self->_set_guards( \@guards );
}

sub encode {
    my ( $self, @num ) = @_;

    return '' unless @num;
    map { return '' unless /^\d+$/ } @num;

    @num = map { _bignum($_) } @num;

    $self->_encode( \@num );
}

sub decode {
    my ( $self, $hash ) = @_;
    return unless $hash;
    $self->_decode($hash);
}

sub encode_hex {
    my ( $self, $str ) = @_;

    return '' unless $str =~ /^[0-9a-fA-F]+$/;

    my @num;
    push @num, '1' . substr $str, 0, 11, '' while $str;

    # no warnings 'portable';
    @num = map { Math::BigInt->from_hex($_) } @num;

    $self->encode(@num);
}

sub decode_hex {
    my ( $self, $hash ) = @_;

    my @res = $self->decode($hash);

    # as_hex includes the leading 0x, so we use three instead of 1
    @res ? join '' => map { substr( _bignum($_)->as_hex, 3 ) } @res : '';
}

sub encrypt {
    shift->encode(@_);
}

sub decrypt {
    shift->decode(shift);
}

sub _encode {
    my ( $self, $num ) = @_;

    my @alphabet = @{ $self->chars };
    my @res;

    my $numHashInt = _bignum(0);
    for my $i ( 0 .. $#$num ) {
        $numHashInt->badd(
            _bignum( $num->[$i] )->bmod( _bignum( $i + 100 ) ) );
    }

    my $lottery = $res[0] = $alphabet[ _bignum($numHashInt)
        ->bmod( _bignum( scalar @alphabet ) )->numify ];

    for my $i ( 0 .. $#$num ) {
        my $n = _bignum( $num->[$i] );
        my @s = ( $lottery, split( // => $self->salt ), @alphabet )
            [ 0 .. @alphabet ];

        @alphabet = _consistentShuffle( \@alphabet, \@s );
        my $last = _hash( $n, \@alphabet );

        push @res => split // => $last;

        if ( $i + 1 < @$num ) {
            my $seps = $self->seps;
            $n->bmod( _bignum( ord($last) + $i ) );
            my $sepsIndex = _bignum($n)->bmod( _bignum( scalar @$seps ) );
            push @res, $seps->[ $sepsIndex->numify ];
        }
    }

    if ( @res < $self->minHashLength ) {
        my $guards     = $self->guards;
        my $guardIndex = _bignum($numHashInt)->badd( _bignum( ord $res[0] ) )
            ->bmod( _bignum( scalar @$guards ) );
        my $guard = $guards->[ $guardIndex->numify ];

        unshift @res, $guard;

        if ( @res < $self->minHashLength ) {
            $guardIndex = _bignum($numHashInt)->badd( _bignum( ord $res[2] ) )
                ->bmod( _bignum( scalar @$guards ) );
            $guard = $guards->[ $guardIndex->numify ];

            push @res, $guard;
        }
    }

    my $halfLength = int @alphabet / 2;
    while ( @res < $self->minHashLength ) {
        @alphabet = _consistentShuffle( \@alphabet, \@alphabet );
        @res = (
            @alphabet[ $halfLength .. $#alphabet ],
            @res, @alphabet[ 0 .. $halfLength - 1 ]
        );

        if ( ( my $excess = @res - $self->minHashLength ) > 0 ) {
            @res = splice @res, int $excess / 2, $self->minHashLength;
        }
    }

    join '' => @res;
}

sub _decode {
    my ( $self, $hash ) = @_;

    return unless $hash;
    return unless defined wantarray;

    my $res  = [];
    my $orig = $hash;

    my $guard = join '|', map {quotemeta} @{ $self->guards };
    my @hash = grep { !/^$/ } split /$guard/ => $hash;
    my $i = ( @hash == 3 || @hash == 2 ) ? 1 : 0;

    return unless defined( $hash = $hash[$i] );
    my $lottery = substr $hash, 0, 1;
    $hash = substr $hash, 1;

    my $sep = join '|', @{ $self->seps };
    @hash = grep { !/^$/ } split /$sep/ => $hash;

    my @alphabet = @{ $self->chars };
    for my $part (@hash) {
        my @s = ( $lottery, split( // => $self->salt ), @alphabet )
            [ 0 .. @alphabet ];

        @alphabet = _consistentShuffle( \@alphabet, \@s );
        push @$res => _unhash( $part, \@alphabet );
    }

    return unless $self->Hashids::encode(@$res) eq $orig;

    wantarray ? @$res : @$res == 1 ? $res->[0] : $res;
}

sub _consistentShuffle {
    my ( $alphabet, $salt ) = @_;

    return wantarray ? [''] : '' unless $alphabet;

    my @alphabet
        = ref $alphabet eq 'ARRAY' ? @$alphabet : split // => $alphabet;
    return wantarray ? @alphabet : join '', @alphabet unless $salt;
    my @salt = ref $salt eq 'ARRAY' ? @$salt : split //, $salt;

    for ( my ( $i, $v, $p ) = ( $#alphabet, 0, 0 ); $i > 0; $i--, $v++ ) {
        $p += my $int = ord $salt[ $v %= @salt ];
        my $j = ( $int + $v + $p ) % $i;

        @alphabet[ $j, $i ] = @alphabet[ $i, $j ];
    }

    wantarray ? @alphabet : join '', @alphabet;
}

sub _hash {
    my ( $num, $alphabet ) = @_;

    my $hash = '';
    my @alphabet
        = ref $alphabet eq 'ARRAY' ? @$alphabet : split // => $alphabet;

    $num = _bignum($num);
    do {
        $hash
            = $alphabet[ _bignum($num)->bmod( _bignum( scalar @alphabet ) )
            ->numify ]
            . $hash;
        $num->bdiv( _bignum( scalar @alphabet ) );
    } while ( $num->bcmp( _bignum(0) ) );

    $hash;
}

sub _unhash {
    my ( $hash, $alphabet ) = @_;

    my @alphabet
        = ref $alphabet eq 'ARRAY' ? @$alphabet : split // => $alphabet;

    my $num = _bignum(0);
    my $pos;
    my @hash = split // => $hash;
    for my $i ( 0 .. $#hash ) {
        ($pos) = grep { $alphabet[$_] eq $hash[$i] } 0 .. $#alphabet;
        $pos = defined $pos ? $pos : -1;
        $num->badd( _bignum($pos)
                ->bmul( _bignum( scalar @alphabet )->bpow( @hash - $i - 1 ) )
        );
    }

    $num->bstr;
}

sub _bignum {
    my $n = Math::BigInt->bzero();
    $n->round_mode('zero');
    return $n->badd("@{[shift]}");
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
    my $hash = $hashids->encode(123);          # 'YDx'
    my $number = $hashids->decode('YDx');      # 123

    # or a list
    $hash = $hashids->encode(1, 2, 3);         # 'eGtrS8'
    my @numbers = $hashids->decode('laHquq');  # (1, 2, 3)

    # also get results in an arrayref
    my $numbers = $hashids->decode('laHquq');  # [1, 2, 3]

=head1 DESCRIPTION

This is a port of the Hashids JavaScript library for Perl.

Hashids was designed for use in URL shortening, tracking stuff,
validating accounts or making pages private (through abstraction.)
Instead of showing items as C<1>, C<2>, or C<3>, you could show them as
C<b9iLXiAa>, C<EATedTBy>, and C<Aaco9cy5>.  Hashes depend on your salt
value.

B<IMPORTANT>: This implementation follows the v1.0.0 API release of
hashids.js.  An older API of hashids.js (v0.1.4) can be found in Hashids
version 0.08 and earlier releases; if you have code that depends on this
API version, please use a tool like L<Carton> to pin your Hashids
install to the older version.

This implementation is also compatible with the v0.3.x hashids.js API.

=head1 METHODS

=over

=item  my $hashids = Hashids->new();

Make a new Hashids object.  This constructor accepts a few options:

=over

=item  salt => 'this is my salt'

Salt string, this should be unique per Hashid object.

=item  alphabet => 'abcdefghij'

Alphabet set to use.  This is optional as Hashids comes with a default
set suitable for URL shortening.  Should you choose to supply a custom
alphabet, make sure that it is at least 16 characters long, has no
spaces, and only has unique characters.

=item  minHashLength => 5

Minimum hash length.  Use this to control how long the generated hash
string should be.

=back

You can also construct with just a single argument for the salt:

    my $hashids = Hashids->new('this is my salt');

=item  my $hash = $hashids->encode($x, [$y, $z, ...]);

Encode a single number (or a list of numbers) into a hash
string.

I<encrypt()> is an alias for this method, for compatibility with v0.3.x
hashids.js API.

=item  my $hash = $hashids->encode_hex('deadbeef');

Encode a hex string into a hash string.

=item  my $number = $hashids->decode($hash);

Decode a hash string into its number (or numbers.)  Returns either a
simple scalar if it is a single number, an arrayref of numbers if it
decrypted a set, or C<undef> if given bad input.  Use L<perlfunc/ref> on
the result to ensure proper usage.

You can also retrieve the result as a proper list by assigning it to an
array variable, by doing so you will always get a list of one or more
numbers that are decrypted from the hash, or the empty list if none were
found:

    my @numbers = $hashids->decode($hash);

I<decrypt()> is an alias for this method, for compatibility with v0.3.x
hashids.js API.

=item  my $hex_string = $hashids->decode_hex($hash);

Opposite of I<encode_hex()>.  Unlike I<decode()>, this will always
return a string, including the empty string if the hash is invalid.

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

Many thanks to L<C. A. Church|https://github.com/thisdroneeatspeople>
and L<Troy Morehouse|https://github.com/tmorehouse> for their fixes and
updates.

=cut
