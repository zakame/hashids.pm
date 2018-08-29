[![Build Status](https://travis-ci.org/zakame/hashids.pm.svg?branch=master)](https://travis-ci.org/zakame/hashids.pm) [![Coverage Status](https://img.shields.io/coveralls/zakame/hashids.pm/master.svg?style=flat)](https://coveralls.io/r/zakame/hashids.pm?branch=master) [![MetaCPAN Release](https://badge.fury.io/pl/Hashids.svg)](https://metacpan.org/release/Hashids) [![Build Status](https://img.shields.io/appveyor/ci/zakame/hashids-pm/master.svg?logo=appveyor)](https://ci.appveyor.com/project/zakame/hashids-pm/branch/master)
# NAME

Hashids - generate short hashes from numbers

# SYNOPSIS

    use Hashids;
    my $hashids = Hashids->new('this is my salt');

    # encrypt a single number
    my $hash = $hashids->encode(123);          # 'YDx'
    my $number = $hashids->decode('YDx');      # 123

    # or a list
    $hash = $hashids->encode(1, 2, 3);         # 'laHquq'
    my @numbers = $hashids->decode('laHquq');  # (1, 2, 3)

    # also get results in an arrayref
    my $numbers = $hashids->decode('laHquq');  # [1, 2, 3]

# DESCRIPTION

This is a port of the Hashids JavaScript library for Perl.

Hashids was designed for use in URL shortening, tracking stuff,
validating accounts or making pages private (through abstraction.)
Instead of showing items as `1`, `2`, or `3`, you could show them as
`b9iLXiAa`, `EATedTBy`, and `Aaco9cy5`.  Hashes depend on your salt
value.

**IMPORTANT**: This implementation follows the v1.0.0 API release of
hashids.js.  An older API of hashids.js (v0.1.4) can be found in Hashids
version 0.08 and earlier releases; if you have code that depends on this
API version, please use a tool like [Carton](https://metacpan.org/pod/Carton) to pin your Hashids
install to the older version.

This implementation is also compatible with the v0.3.x hashids.js API.

# METHODS

## new

    my $hashids = Hashids->new();

Make a new Hashids object.  This constructor accepts a few options:

    my $hashids = Hashids->new(
        salt          => 'this is my salt',
        alphabet      => 'abcdefghijklmnop',
        minHashLength => 8
    );

- salt

    Salt string, this should be unique per Hashids object.  Must be either
    as long or shorter than the alphabet length, as a longer salt string
    than the alphabet introduces false collisions.

- alphabet

    Alphabet set to use.  This is optional as Hashids comes with a default
    set suitable for URL shortening.  Should you choose to supply a custom
    alphabet, make sure that it is at least 16 characters long, has no
    spaces, and only has unique characters.

- minHashLength

    Minimum hash length.  Use this to control how long the generated hash
    string should be.

You can also construct with just a single argument for the salt, leaving
the alphabet and minHashLength at their defaults:

    my $hashids = Hashids->new('this is my salt');

## encode

    my $hash = $hashids->encode($x, [$y, $z, ...]);

Encode a single number (or a list of numbers) into a hash string.

## encrypt

Alias for ["encode"](#encode), for compatibility with v0.3.x hashids.js API.

## encode\_hex

    my $hash = $hashids->encode_hex('deadbeef');

Encode a hex string into a hash string.

## decode

    my $number = $hashids->decode($hash);

Decode a hash string into its number (or numbers.)  Returns either a
simple scalar if it is a single number, an arrayref of numbers if it
decrypted a set, or `undef` if given bad input.  Use ["ref" in perlfunc](https://metacpan.org/pod/perlfunc#ref) on
the result to ensure proper usage.

You can also retrieve the result as a proper list by assigning it to an
array variable, by doing so you will always get a list of one or more
numbers that are decrypted from the hash, or the empty list if none were
found:

    my @numbers = $hashids->decode($hash);

## decrypt

Alias for this ["decode"](#decode), for compatibility with v0.3.x hashids.js API.

## decode\_hex

    my $hex_string = $hashids->decode_hex($hash);

Opposite of ["encode\_hex"](#encode_hex).  Unlike ["decode"](#decode), this will always return
a string, including the empty string if the hash is invalid.

# SEE ALSO

[Hashids](http://www.hashids.org)

# LICENSE

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

# AUTHOR

Zak B. Elep <zakame@cpan.org>

Original Hashids JavaScript library written by [Ivan
Akimov](http://twitter.com/ivanakimov)

# THANKS

Props to [Jofell Gallardo](http://twitter.com/jofell) for pointing this
excellent project to me in the first place.

Many thanks to [C. A. Church](https://github.com/thisdroneeatspeople)
and [Troy Morehouse](https://github.com/tmorehouse) for their fixes and
updates.
