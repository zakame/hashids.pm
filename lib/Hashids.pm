package Hashids;

use Carp 'croak';
use POSIX 'ceil';
use Hashids::Util ':all';
use Moo;
use namespace::clean;

our $VERSION = "1.001001";

has salt => ( is => 'ro', default => '' );

has minHashLength => (
    is  => 'ro',
    isa => sub {
        croak "$_[0] must be a positive number" unless $_[0] =~ /^[0-9]+$/;
    },
    default => 0
);

has alphabet => (
    is  => 'rwp',
    isa => sub {
        local $_ = shift;
        croak "$_ must not have spaces" if /\s/;
        croak "$_ must contain at least 16 characters" if 16 > length;
        my %u;
        croak "$_ must contain unique characters"
            if any { $u{$_}++ } split //;
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

around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;
    unshift @args, 'salt' if @args % 2 == 1;

    $class->$orig(@args);
};

sub BUILD {
    my $self = shift;

    croak "salt must be shorter than or of equal length to alphabet"
        if length $self->salt > length $self->alphabet;

    my @alphabet = split // => $self->alphabet;
    my ( @seps, @guards );

    my $sepDiv   = 3.5;
    my $guardDiv = 12;

    # seps should contain only chars present in alphabet;
    # alphabet should not contain seps
    for my $sep ( @{ $self->seps } ) {
        push @seps, $sep if any {/$sep/} @alphabet;
        @alphabet = grep { !/$sep/ } @alphabet;
    }

    @seps = consistent_shuffle( \@seps, $self->salt );

    if ( !@seps || ( @alphabet / @seps ) > $sepDiv ) {
        my $sepsLength = ceil( @alphabet / $sepDiv );
        $sepsLength++ if $sepsLength == 1;
        if ( $sepsLength > @seps ) {
            push @seps => splice @alphabet, 0, $sepsLength - @seps;
        }
    }

    @alphabet = consistent_shuffle( \@alphabet, $self->salt );
    my $guardCount = ceil( @alphabet / $guardDiv );

    @guards
        = @alphabet < 3
        ? splice @seps, 0, $guardCount
        : splice @alphabet, 0, $guardCount;

    $self->_set_chars( \@alphabet );
    $self->_set_seps( \@seps );
    $self->_set_guards( \@guards );
}

sub encode_hex {
    my ( $self, $str ) = @_;

    return '' unless $str =~ /^[0-9a-fA-F]+$/;

    my @num;
    push @num, '1' . substr $str, 0, 11, '' while $str;

    # no warnings 'portable';
    @num = map { bignum(0)->from_hex($_) } @num;

    $self->encode(@num);
}

sub decode_hex {
    my ( $self, $hash ) = @_;

    my @res = $self->decode($hash);

    # as_hex includes the leading 0x, so we use three instead of 1
    @res ? join '' => map { substr( bignum($_)->as_hex, 3 ) } @res : '';
}

sub encrypt {
    shift->encode(@_);
}

sub decrypt {
    shift->decode(shift);
}

sub encode {
    my ( $self, @num ) = @_;

    return '' unless @num;
    map { return '' unless defined and /^[0-9]+$/ } @num;

    my $num = [ map { bignum($_) } @num ];

    my @alphabet = @{ $self->chars };
    my @res;

    my $numHashInt = bignum(0);
    for my $i ( 0 .. $#$num ) {
        $numHashInt += $num->[$i] % ( $i + 100 );
    }

    my $lottery = $res[0] = $alphabet[ $numHashInt % @alphabet ];

    for my $i ( 0 .. $#$num ) {
        my $n = bignum( $num->[$i] );
        my @s = ( $lottery, split( // => $self->salt ), @alphabet )
            [ 0 .. @alphabet ];

        @alphabet = consistent_shuffle( \@alphabet, \@s );
        my $last = to_alphabet( $n, \@alphabet );

        push @res => split // => $last;

        if ( $i + 1 < @$num ) {
            $n %= ord($last) + $i;
            my $sepsIndex = $n % @{ $self->seps };
            push @res, $self->seps->[$sepsIndex];
        }
    }

    if ( @res < $self->minHashLength ) {
        my $guards     = $self->guards;
        my $guardIndex = ( $numHashInt + ord $res[0] ) % @$guards;
        my $guard      = $guards->[$guardIndex];

        unshift @res, $guard;

        if ( @res < $self->minHashLength ) {
            $guardIndex = ( $numHashInt + ord $res[2] ) % @$guards;
            $guard      = $guards->[$guardIndex];

            push @res, $guard;
        }
    }

    my $halfLength = int @alphabet / 2;
    while ( @res < $self->minHashLength ) {
        @alphabet = consistent_shuffle( \@alphabet, \@alphabet );
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

sub decode {
    my ( $self, $hash ) = @_;

    return unless $hash;
    return unless defined wantarray;

    my $res  = [];
    my $orig = $hash;

    my $guard = join '|', map {quotemeta} @{ $self->guards };
    my @hash = grep { $_ ne '' } split /$guard/ => $hash;
    my $i = ( @hash == 3 || @hash == 2 ) ? 1 : 0;

    return unless defined( $hash = $hash[$i] );
    my $lottery = substr $hash, 0, 1;
    $hash = substr $hash, 1;

    my $sep = join '|', @{ $self->seps };
    @hash = grep { $_ ne '' } split /$sep/ => $hash;

    my @alphabet = @{ $self->chars };
    for my $part (@hash) {
        my @s = ( $lottery, split( // => $self->salt ), @alphabet )
            [ 0 .. @alphabet ];

        @alphabet = consistent_shuffle( \@alphabet, \@s );
        push @$res => from_alphabet( $part, \@alphabet );
    }

    return unless $self->Hashids::encode(@$res) eq $orig;

    wantarray ? @$res : @$res == 1 ? $res->[0] : $res;
}

1;
__END__

=encoding utf-8

=for stopwords minHashLength

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

=head2 new

    my $hashids = Hashids->new();

Make a new Hashids object.  This constructor accepts a few options:

    my $hashids = Hashids->new(
        salt          => 'this is my salt',
        alphabet      => 'abcdefghijklmnop',
        minHashLength => 8
    );

=over

=item  salt

Salt string, this should be unique per Hashids object.  Must be either
as long or shorter than the alphabet length, as a longer salt string
than the alphabet introduces false collisions.

=item  alphabet

Alphabet set to use.  This is optional as Hashids comes with a default
set suitable for URL shortening.  Should you choose to supply a custom
alphabet, make sure that it is at least 16 characters long, has no
spaces, and only has unique characters.

=item  minHashLength

Minimum hash length.  Use this to control how long the generated hash
string should be.

=back

You can also construct with just a single argument for the salt, leaving
the alphabet and minHashLength at their defaults:

    my $hashids = Hashids->new('this is my salt');

=head2 encode

    my $hash = $hashids->encode($x, [$y, $z, ...]);

Encode a single number (or a list of numbers) into a hash string.

=head2 encrypt

Alias for L</encode>, for compatibility with v0.3.x hashids.js API.

=head2 encode_hex

    my $hash = $hashids->encode_hex('deadbeef');

Encode a hex string into a hash string.

=head2 decode

    my $number = $hashids->decode($hash);

Decode a hash string into its number (or numbers.)  Returns either a
simple scalar if it is a single number, an arrayref of numbers if it
decrypted a set, or C<undef> if given bad input.  Use L<perlfunc/ref> on
the result to ensure proper usage.

You can also retrieve the result as a proper list by assigning it to an
array variable, by doing so you will always get a list of one or more
numbers that are decrypted from the hash, or the empty list if none were
found:

    my @numbers = $hashids->decode($hash);

=head2 decrypt

Alias for this L</decode>, for compatibility with v0.3.x hashids.js API.

=head2 decode_hex

    my $hex_string = $hashids->decode_hex($hash);

Opposite of L</encode_hex>.  Unlike L</decode>, this will always return
a string, including the empty string if the hash is invalid.

=head1 SEE ALSO

L<Hashids|http://www.hashids.org>

=head1 LICENSE

The MIT License (MIT)

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
