# NAME

Hashids - generate short hashes from numbers

# SYNOPSIS

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

# DESCRIPTION

This is a port of the Hashids JavaScript library for Perl.

Hashids was designed for use in URL shortening, tracking stuff,
validating accounts or making pages private (through abstraction.)
Instead of showing items as `1`, `2`, or `3`, you could show them as
`b9iLXiAa`, `EATedTBy`, and `Aaco9cy5`.  Hashes depend on your salt
value.

# METHODS

- my $hashids = Hashids->new();

    Make a new Hashids object.  This constructor accepts a few options:

    - salt => 'this is my salt'

        Salt string, this should be unique per Hashid object.

    - alphabet => 'abcdefghij'

        Alphabet set to use.  This is optional as Hashids comes with a default
        set suitable for URL shortening.

    - minHashLength => 5

        Minimum hash length.  Use this to control how long the generated hash
        string should be.

    You can also construct with just a single argument for the salt:

        my $hashids = Hashids->new('this is my salt');

- my $hash = $hashids->encrypt($x, \[$y, $z, ...\]);

    Encrypt a single number (or a list of numbers) into a hash string.

- my $number = $hashids->decrypt($hash);

    Decrypt a hash string into its number (or numbers.)  Returns either a
    simple scalar if it is a single number, an arrayref of numbers if it
    decrypted a set, or `undef` if given bad input.  Use [ref](http://search.cpan.org/perldoc?ref) on the
    result to ensure proper usage.

    You can also retrieve the result as a proper list by assigning it to an
    array variable, by doing so you will always get a list of one or more
    numbers that are decrypted from the hash, or the empty list if none were
    found:

        my @numbers = $hashids->decrypt($hash);

# SEE ALSO

[Hashids](http://www.hashids.org)

# LICENSE

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

# AUTHOR

Zak B. Elep <zakame@cpan.org>

Original Hashids JavaScript library written by [Ivan Akimov](http://twitter.com/ivanakimov)

# THANKS

Props to [Jofell Gallardo](http://twitter.com/jofell) for pointing this
excellent project to me in the first place.
