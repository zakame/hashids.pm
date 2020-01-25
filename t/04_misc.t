#!/usr/bin/env perl
use strict;
use warnings;
use bignum;

use Test::More;
use Hashids;
use Hashids::Util;

plan tests => 2;

like( ref(222), qr/Math::Big/, 'bignum pragma is loaded' );

subtest 'should not enter into an infinite loop under bignum pragma' => sub {
    plan tests => 2;

    my $hashids = Hashids->new;
    is( $hashids->encode(222), 'LZg', 'encode under bignum pragma' );

    is( Hashids::Util::to_alphabet( 123, 'abcdefghij' ),
        'bcd', 'internal to_alphabet under bignum pragma' );
};
