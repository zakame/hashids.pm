#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Hashids;
use Math::BigInt;

plan tests => 11;

my $salt = "this is my salt";

subtest 'basics' => sub {
    plan tests => 8;

    can_ok( Hashids => "new" );
    my $hashids = Hashids->new();
    isa_ok( $hashids, 'Hashids' );

    is( $hashids->salt, '', 'no salt' );

    $hashids = Hashids->new( salt => $salt );
    is( $hashids->salt, $salt, 'low salt' );

    $hashids->new($salt);
    is( $hashids->salt, $salt, 'single-arg constructor' );

    subtest 'hash length' => sub {
        plan tests => 3;

        is( $hashids->minHashLength, 0, 'default minHashLength' );

        my $minHashLength = 8;
        $hashids = Hashids->new( minHashLength => $minHashLength );
        is( $hashids->minHashLength, $minHashLength, 'set minHashLength' );

        $minHashLength = 'top lol';
        throws_ok {
            Hashids->new( minHashLength => $minHashLength );
        }
        qr/not a number/, 'invalid minHashLength';
    };

    subtest 'alphabet' => sub {
        plan tests => 5;

        is( $hashids->alphabet,
            join( '' => ( 'a' .. 'z', 'A' .. 'Z', 1 .. 9, 0 ) ),
            'default alphabet'
        );

        my $alphabet = join '' => ( 'a' .. 'z' );
        $hashids = Hashids->new( alphabet => $alphabet );
        is( $hashids->alphabet, $alphabet, 'custom alphabet' );

        $alphabet = "abc";
        throws_ok {
            Hashids->new( alphabet => $alphabet );
        }
        qr/must contain at least 16/, 'at least 16 chars';

        $alphabet = "gjklmnopqrvwxyzABDEGJKLMNOPQRVWXYZ1234567890g";
        throws_ok {
            Hashids->new( alphabet => $alphabet );
        }
        qr/must contain unique/, 'must have unique chars';

        $alphabet = "ab cd";
        throws_ok {
            Hashids->new( alphabet => $alphabet );
        }
        qr/must not have spaces/, 'no spaces allowed';

    };

    subtest 'chars, seps, and guards' => sub {
        plan tests => 3;

        ok( $hashids->chars,  'has chars' );
        ok( $hashids->seps,   'has seps' );
        ok( $hashids->guards, 'has guards' );
    };
};

subtest 'internal functions' => sub {
    plan tests => 9;

    is( Hashids::_consistentShuffle( '123', 'salt' ), '231', 'shuffle 1' );
    is( Hashids::_consistentShuffle( 'abcdefghij', 'salt' ),
        'iajecbhdgf', 'shuffle 2' );

    is( Hashids::_consistentShuffle( [ '1', '2', '3' ], 'salt' ),
        '231', 'shuffle alphabet list 1' );
    is( Hashids::_consistentShuffle( [ 'a' .. 'j' ], 'salt' ),
        'iajecbhdgf', 'shuffle alphabet list 2' );

    my @res = Hashids::_consistentShuffle( '123', 'salt' );
    is_deeply( \@res, [qw( 2 3 1 )], 'shuffle returns a list' );

    is( Hashids::_consistentShuffle( [ 'a' .. 'j' ], [qw( s a l t )] ),
        'iajecbhdgf', 'shuffle with salt as list' );

    is( Hashids::_hash( 123, 'abcdefghij' ), 'bcd', 'internal hash' );
    is( Hashids::_unhash( 'bcd', 'abcdefghij' ), 123, 'internal unhash' );

    subtest '_hash/_unhash with list' => sub {
        plan tests => 2;

        my @alphabet = qw(a b c d e f g h i j);
        is( Hashids::_hash( 123, \@alphabet ), 'bcd', 'internal hash' );
        is( Hashids::_unhash( 'bcd', \@alphabet ), 123, 'internal unhash' );
    };
};

subtest 'simple encode/decode' => sub {
    plan tests => 6;

    my $hashids = Hashids->new( salt => $salt );

    is( $hashids->encode(),               '', 'no encode' );
    is( $hashids->encode('up the wazoo'), '', 'bad encode' );

    my $plaintext = 123;
    my $encoded   = 'YDx';
    is( $hashids->encode($plaintext), $encoded,   'encode 1' );
    is( $hashids->decode($encoded),   $plaintext, 'decode 1' );

    $plaintext = 123456;
    $encoded   = '4DLz6';
    is( $hashids->encode($plaintext), $encoded,   'encode 2' );
    is( $hashids->decode($encoded),   $plaintext, 'decode 2' );

};

subtest 'encode with minHashLength' => sub {
    plan tests => 2;

    my $hashids = Hashids->new( salt => $salt, minHashLength => 15 );

    my $plaintext = 123;
    my $encoded   = 'V34xpAYDx0mQNvl';
    is( $hashids->encode($plaintext), $encoded,   'encode minHashLength' );
    is( $hashids->decode($encoded),   $plaintext, 'decode minHashLength' );
};

subtest 'list encode/decode' => sub {
    plan tests => 7;

    my $hashids = Hashids->new( salt => $salt );

    can_ok( $hashids, qw/encode decode/ );

    my @plaintexts = ( 1, 2, 3 );
    my $encoded = 'laHquq';
    is( $hashids->encode(@plaintexts), $encoded, 'encode list 1' );
    is_deeply( scalar $hashids->decode($encoded),
        \@plaintexts, 'decode list 1' );

    @plaintexts = ( 123, 456, 789 );
    $encoded = 'Z8gi1DIx6';
    is( $hashids->encode(@plaintexts), $encoded, 'encode list 2' );
    is_deeply( scalar $hashids->decode($encoded),
        \@plaintexts, 'decode list 2' );

    subtest 'decode return as list' => sub {
        plan tests => 2;

        my @single = $hashids->decode('YDx');
        is_deeply( \@single, [123], 'decode as list (single value)' );

        my @result = $hashids->decode($encoded);
        is_deeply( \@result, \@plaintexts, 'decode as list (multi)' );
    };

    subtest 'list encode/decode with minHashLength' => sub {
        plan tests => 2;

        $hashids = Hashids->new( salt => $salt, minHashLength => 16 );
        $encoded = 'j1DAZ8gi1DIx6Glx';

        is( $hashids->encode(@plaintexts),
            $encoded, 'encode list with minHashLength' );

        my @result = $hashids->decode($encoded);
        is_deeply( \@result, \@plaintexts, 'decode as list (minHashLength)' );
    };
};

subtest 'work with counting numbers only' => sub {
    my $hashids = Hashids->new();

    plan tests => 4;

    is( $hashids->encode(12.3), '', 'not an integer' );
    is( $hashids->encode(-1),   '', 'not a positive integer' );
    is( $hashids->encode( 123, 45.6 ), '', 'no integer in list' );
    is( $hashids->encode( -1, -2, 3 ), '', 'negative integers in list' );
};

subtest 'encode hex strings' => sub {
    plan tests => 4;

    my $hashids = Hashids->new( salt => $salt );

    my $plaintext = 'deadbeef';
    my $encoded   = 'kRNrpKlJ';
    is( $hashids->encode_hex($plaintext), $encoded,   'encode hex string' );
    is( $hashids->decode_hex($encoded),   $plaintext, 'decode hex string' );

    is( $hashids->encode_hex('invalid'), '', 'invalid encode hex string' );
    is( $hashids->decode_hex('invalid'), '', 'invalid decode hex string' );
};

subtest 'work with custom alphabets' => sub {
    plan tests => 4;

    # also tests for regex meta chars and alphabets with mostly seps
    my $alphabet = 'cfhistuCFHISTU+-*/';
    my $hashids = Hashids->new( salt => $salt, alphabet => $alphabet );

    my @plaintext = ( 1, 2, 3 );
    my $encoded = '+-H/u/+';
    is( $hashids->encode(@plaintext), $encoded, 'encode with mostly seps' );

    my @result = $hashids->decode($encoded);
    is_deeply( \@result, \@plaintext, 'decode with mostly seps' );

    # test for alphabet with no seps
    $alphabet = 'abdegjklmnop+-*/';
    $hashids = Hashids->new( salt => $salt, alphabet => $alphabet );

    $encoded = 'olb*do';
    is( $hashids->encode(@plaintext), $encoded, 'encode with no seps' );
    @result = $hashids->decode($encoded);
    is_deeply( \@result, \@plaintext, 'decode with no seps' );
};

subtest 'v0.3.0 hashids.js API compatibility' => sub {
    plan tests => 6;

    my $hashids = Hashids->new( salt => $salt );

    is( $hashids->encrypt(),               '', 'no encrypt' );
    is( $hashids->encrypt('up the wazoo'), '', 'bad encrypt' );

    my $plaintext = 123;
    my $encrypted = 'YDx';
    is( $hashids->encrypt($plaintext), $encrypted, 'encrypt 1' );
    is( $hashids->decrypt($encrypted), $plaintext, 'decrypt 1' );

    my @plaintexts = ( 1, 2, 3 );
    $encrypted = 'laHquq';
    is( $hashids->encrypt(@plaintexts), $encrypted, 'encrypt 2' );
    my @result = $hashids->decrypt($encrypted);
    is_deeply( \@result, \@plaintexts, 'decrypt 2' );
};

subtest 'test encode/decode series comparison' => sub {
    plan tests => 1002;

    my $hashids = Hashids->new('fdfs42842f');

    foreach ( 0 .. 1000 ) {
        my $new = $hashids->encode($_);
        is( $hashids->decode($new), $_, "encode/decode val $_" );
    }

    # test array of hashes that start with zero
    my @arr     = ( 99, 111, 599, 811, 955 );
    my $encoded = $hashids->encode(@arr);
    my @decoded = $hashids->decode($encoded);

    is_deeply( \@decoded, \@arr, 'known array series' );
};

subtest 'BigInt and 2^53+1 support' => sub {

    # bignum keys are strings so that 32-bit perls can read them
    my %bignums = (
        '9_007_199_254_740_992'     => 'mNWyy8yjQYE',
        '9_007_199_254_740_993'     => 'n6WOO7OkrgY',
        '18_014_398_509_481_984'    => '7KpVVxJ6pOy',
        '18_014_398_509_481_985'    => '8LMKKyYqMOg',
        '1_152_921_504_606_846_976' => 'YkZM1Vrj77o0'
    );

    plan tests => scalar( keys %bignums ) * 2 + 1;

    my $hashids = Hashids->new;
    for my $bignum ( keys %bignums ) {
        my $bigint = Math::BigInt->new($bignum);
        is( $hashids->encode( $bigint->bstr ),
            $bignums{$bignum}, "encode bignum $bignum" );
        is( $hashids->decode( $bignums{$bignum} ),
            $bigint, "decode bignum $bignum" );
    }

    subtest 'BigInt bounds' => sub {
        my %big6 = (
            '666_666_666_666'         => 'Lg8j28K8w',
            '6_666_666_666_666'       => 'L2jqVjD3v',
            '66_666_666_666_666'      => 'L7q3Gkq5Mw',
            '666_666_666_666_666'     => 'L982g6zWEQv',
            '6_666_666_666_666_666'   => 'LA4V2Z0BAQw',
            '66_666_666_666_666_666'  => 'LglKVmY922Mv',
            '666_666_666_666_666_666' => 'LVwzmqgWko3w',
        );

        plan tests => scalar( keys %big6 ) * 2;

        for my $bignum ( keys %big6 ) {
            my $bigint = Math::BigInt->new($bignum);
            is( $hashids->encode( $bigint->bstr ),
                $big6{$bignum}, "encode bignum $bignum" );
            is( $hashids->decode( $big6{$bignum} ),
                $bigint, "decode bignum $bignum" );
        }
    };
};
