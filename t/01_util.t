#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Hashids::Util;

plan tests => 2;

subtest 'consistent shuffle' => sub {
    plan tests => 8;

    is( Hashids::Util::consistent_shuffle( '123', 'salt' ),
        '231', 'shuffle 1' );
    is( Hashids::Util::consistent_shuffle( 'abcdefghij', 'salt' ),
        'iajecbhdgf', 'shuffle 2' );

    is( Hashids::Util::consistent_shuffle( [ '1', '2', '3' ], 'salt' ),
        '231', 'shuffle alphabet list 1' );
    is( Hashids::Util::consistent_shuffle( [ 'a' .. 'j' ], 'salt' ),
        'iajecbhdgf', 'shuffle alphabet list 2' );

    my @res = Hashids::Util::consistent_shuffle( '123', 'salt' );
    is_deeply( \@res, [qw( 2 3 1 )], 'shuffle returns a list' );

    is( Hashids::Util::consistent_shuffle( [ 'a' .. 'j' ], [qw( s a l t )] ),
        'iajecbhdgf',
        'shuffle with salt as list'
    );

    is( Hashids::Util::consistent_shuffle( '', 'salt' ),
        '', 'shuffle with empty alphabet' );

    is( Hashids::Util::consistent_shuffle( [ 'a' .. 'j' ], '' ),
        'abcdefghij', 'shuffle with empty salt' );
};

subtest 'alphabet conversion' => sub {
    plan tests => 3;

    is( Hashids::Util::to_alphabet( 123, 'abcdefghij' ),
        'bcd', 'internal to_alphabet' );
    is( Hashids::Util::from_alphabet( 'bcd', 'abcdefghij' ),
        123, 'internal from_alphabet' );

    subtest 'to/from alphabet with list' => sub {
        plan tests => 2;

        my @alphabet = qw(a b c d e f g h i j);
        is( Hashids::Util::to_alphabet( 123, \@alphabet ),
            'bcd', 'internal to_alphabet' );
        is( Hashids::Util::from_alphabet( 'bcd', \@alphabet ),
            123, 'internal from_alphabet' );
    };
};
