package Hashids;

our $VERSION = "0.08";

use Carp;
use Moo;
use POSIX ();

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
    default =>
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'
);

has seps   => ( is => 'rwp', init_arg => undef, default => 'cfhistuCFHISTU' );
has guards => ( is => 'rwp', init_arg => undef, default => '' );

sub BUILDARGS {
    my ( $class, @args ) = @_;
    unshift @args, 'salt' if @args % 2 == 1;

    +{@args};
}

sub BUILD {
    my $self = shift;

    my @alphabet = split //, $self->alphabet;
    my ( @seps, @guards );

    my $sepDiv   = 3.5;
    my $guardDiv = 12;

    # seps should contain only chars present in alphabet;
    # alphabet should not contain seps
    for my $sep ( split //, $self->seps ) {
        push @seps, $sep if grep {/$sep/} @alphabet;
        @alphabet = grep { !/$sep/ } @alphabet;
    }

    @seps = $self->_consistentShuffle( \@seps, $self->salt );

    if ( !@seps || ( @alphabet / @seps ) > $sepDiv ) {
        my $sepsLength = POSIX::ceil( @alphabet / $sepDiv );
        if ( $sepsLength == 1 ) {
            $sepsLength++;
        }
        if ( $sepsLength > @seps ) {
            my $diff = $sepsLength - @seps;
            push @seps => splice @alphabet, 0, $diff;
        }
        else {
            splice @seps, 0, $sepsLength;
        }
    }

    @alphabet = $self->_consistentShuffle( \@alphabet, $self->salt );
    my $guardCount = POSIX::ceil( @alphabet / $guardDiv );

    if ( @alphabet < 3 ) {
        @guards = splice @seps, 0, $guardCount;
    }
    else {
        @guards = splice @alphabet, 0, $guardCount;
    }

    $self->_set_alphabet( join '', @alphabet );
    $self->_set_seps( join '', @seps );
    $self->_set_guards( join '', @guards );
}

sub encrypt {
    my ( $self, @num ) = @_;

    return '' unless @num;
    map { return '' unless /^\d+$/ } @num;

    $self->_encode( \@num );
}

sub decrypt {
    my ( $self, $hash ) = @_;
    return unless $hash;
    $self->_decode($hash);
}

sub _encode {
    my ( $self, $num ) = @_;

    my @alphabet = split // => $self->alphabet;
    my @seps     = split // => $self->seps;
    my @guards   = split // => $self->guards;
    my $res      = '';

    my ( $i, $numHashInt, $sepsIndex );
    for ( $i = 0; $i != @$num; $i++ ) {
        $numHashInt += ( $num->[$i] % ( $i + 100 ) );
    }

    my $lottery = $res = $alphabet[ $numHashInt % @alphabet ];
    for ( $i = 0; $i != @$num; $i++ ) {
        my $n = $num->[$i];
        my $b = join '' => $lottery, $self->salt, @alphabet;

        @alphabet = $self->_consistentShuffle( \@alphabet, substr $b, 0,
            @alphabet );
        my $last = $self->_hash( $n, join '' => @alphabet );

        $res = join '' => $res, $last;

        if ( $i + 1 < @$num ) {
            $n %= ( ord($last) + $i );
            $sepsIndex = $n % @seps;
            $res = join '' => $res, $seps[$sepsIndex];
        }
    }

    my ( $guardIndex, $guard );
    if ( length $res < $self->minHashLength ) {
        $guardIndex = ( $numHashInt . +ord $res ) % @guards;
        $guard      = $guards[$guardIndex];

        $res = join '' => $guard, $res;

        if ( length $res < $self->minHashLength ) {
            $guardIndex = ( $numHashInt . +ord substr $res, 2 ) % @guards;
            $guard = $guards[$guardIndex];

            $res = join '' => $res, $guard;
        }
    }

    my $halfLength = @alphabet / 2;
    while ( length $res < $self->minHashLength ) {
        @alphabet = $self->_consistentShuffle( \@alphabet, \@alphabet );
        $res = join '' => splice @alphabet, $halfLength, 1, $res;

        my $excess = length $res - $self->minHashLength;
        if ( $excess > 0 ) {
            $res = substr $res, $excess / 2, $self->minHashLength;
        }
    }

    $res;
}

sub _decode {
    my ( $self, $hash ) = @_;

    return unless $hash;
    return unless defined wantarray;

    my $res  = [];
    my $orig = $hash;

    my $guards = $self->guards;
    {
        local $_ = $hash;
        eval "tr/$guards/ /";
        $hash = $_;
    }
    my @hash = split / / => $hash;

    my $i = 0;
    if ( @hash == 3 || @hash == 2 ) {
        $i = 1;
    }

    $hash = $hash[$i];
    if ( my $lottery = substr $hash, 0, 1 ) {
        $hash = substr $hash, 1;

        my $seps = $self->seps;
        {
            local $_ = $hash;
            eval "tr/$seps/ /";
            $hash = $_;
        }
        @hash = split / / => $hash;

        my $alphabet = $self->alphabet;
        for my $part (@hash) {
            my $b = join '' => $lottery, $self->salt, $alphabet;

            $alphabet = $self->_consistentShuffle( $alphabet, substr $b, 0,
                length $alphabet );
            push @$res, $self->_unhash( $part, $alphabet );
        }
    }

    return unless $self->Hashids::encrypt(@$res) eq $orig;

    wantarray ? @$res : @$res == 1 ? $res->[0] : $res;
}

sub _consistentShuffle {
    my ( $self, $alphabet, $salt ) = @_;

    return wantarray ? [''] : '' unless $alphabet;

    my @alphabet
        = ref $alphabet eq 'ARRAY' ? @$alphabet : split // => $alphabet;
    return wantarray ? @alphabet : join '', @alphabet unless $salt;
    my @salt = ref $salt eq 'ARRAY' ? @$salt : split // => $salt;

    my ( $int, $temp, $j );
    for ( my ( $i, $v, $p ) = ( $#alphabet, 0, 0 ); $i > 0; $i--, $v++ ) {
        $v %= @salt;
        $p += $int = ord $salt[$v];
        $j = ( $int + $v + $p ) % $i;

        @alphabet[ $j, $i ] = @alphabet[ $i, $j ];
    }

    wantarray ? @alphabet : join '', @alphabet;
}

sub _hash {
    my ( $self, $num, $alphabet ) = @_;

    my $hash = '';
    my @alphabet = split //, $alphabet;

    do {
        $hash = $alphabet[ $num % @alphabet ] . $hash;
        $num  = int( $num / @alphabet );
    } while ($num);

    $hash;
}

sub _unhash {
    my ( $self, $hash, $alphabet ) = @_;

    my $num = 0;
    my $pos;

    my @hash = split //, $hash;
    for ( my $i = 0; $i < @hash; $i++ ) {
        $pos = index $alphabet, $hash[$i];
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
    my $hash = $hashids->encrypt(123);          # 'YDx'
    my $number = $hashids->decrypt('YDx');      # 123

    # or a list
    $hash = $hashids->encrypt(1, 2, 3);         # 'eGtrS8'
    my @numbers = $hashids->decrypt('laHquq');  # (1, 2, 3)

    # also get results in an arrayref
    my $numbers = $hashids->decrypt('laHquq');  # [1, 2, 3]

=head1 DESCRIPTION

This is a port of the Hashids JavaScript library for Perl.

Hashids was designed for use in URL shortening, tracking stuff,
validating accounts or making pages private (through abstraction.)
Instead of showing items as C<1>, C<2>, or C<3>, you could show them as
C<b9iLXiAa>, C<EATedTBy>, and C<Aaco9cy5>.  Hashes depend on your salt
value.

B<IMPORTANT>: This implementation follows the v0.3.x API release of
hashids.js.  The previous API of hashids.js (v0.1.4) can be found in
Hashids version 0.08 and earlier releases; if you have code that depends
on this API version, please update it and use a tool like L<Carton> to
pin your Hashids install until your code is updated.

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
