#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Hashids::Util;

plan tests => 2;

subtest 'consistent shuffle' => sub {
    plan tests => 7;
    my $res;

    $res = [ Hashids::Util::consistent_shuffle( '123', 'salt' ) ];
    is_deeply( $res, [qw(2 3 1)], 'shuffle 1' );
    $res = [ Hashids::Util::consistent_shuffle( 'abcdefghij', 'salt' ) ];
    is_deeply( $res, [qw(i a j e c b h d g f)], 'shuffle 2' );

    $res = [ Hashids::Util::consistent_shuffle( [ '1', '2', '3' ], 'salt' ) ];
    is_deeply( $res, [qw(2 3 1)], 'shuffle alphabet list 1' );
    $res = [ Hashids::Util::consistent_shuffle( [ 'a' .. 'j' ], 'salt' ) ];
    is_deeply( $res, [qw(i a j e c b h d g f)], 'shuffle alphabet list 2' );

    $res = [
        Hashids::Util::consistent_shuffle(
            [ 'a' .. 'j' ],
            [ split // => 'salt' ]
        )
    ];
    is_deeply( $res, [qw(i a j e c b h d g f)], 'shuffle with salt as list' );

    $res = [ Hashids::Util::consistent_shuffle( '', 'salt' ) ];
    is_deeply( $res, [''], 'shuffle with empty alphabet' );

    $res = [ Hashids::Util::consistent_shuffle( [ 'a' .. 'j' ], '' ) ];
    is_deeply( $res, [qw(a b c d e f g h i j)], 'shuffle with empty salt' );
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
