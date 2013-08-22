#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Hashids;

plan tests => 4;

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
        plan tests => 4;

        is( $hashids->alphabet,
            'x4689abdeA7kynopqrXgE5GBKLMjRz',
            'default alphabet'
        );

        my $alphabet = join '' => ( 'a' .. 'z' );
        $hashids = Hashids->new( alphabet => $alphabet );
        is( $hashids->alphabet, 'adfhijlnoprtuvxyz', 'custom alphabet' );

        $alphabet = "abc";
        throws_ok {
            Hashids->new( alphabet => $alphabet );
        }
        qr/must contain at least 4/, 'at least 4 chars';

        $alphabet = "abca";
        throws_ok {
            Hashids->new( alphabet => $alphabet );
        }
        qr/must contain unique/, 'must have unique chars';
    };

    subtest 'seps and guards' => sub {
        plan tests => 2;

        ok( $hashids->seps,   'has seps' );
        ok( $hashids->guards, 'has guards' );
    };
};

subtest 'internal functions' => sub {
    plan tests => 4;

    is( Hashids->_consistentShuffle( '123', 'salt' ), '231', 'shuffle 1' );
    is( Hashids->_consistentShuffle( 'abcdefghij', 'salt' ),
        'aichgfdebj', 'shuffle 2' );

    is( Hashids->_hash( 123, 'abcdefghij' ), 'bcd', 'internal hash' );
    is( Hashids->_unhash( 'bcd', 'abcdefghij' ), 123, 'internal unhash' );
};

subtest 'simple encrypt/decrypt' => sub {
    plan tests => 6;

    my $hashids = Hashids->new( salt => $salt );

    is( $hashids->encrypt(),               '', 'no encrypt' );
    is( $hashids->encrypt('up the wazoo'), '', 'bad encrypt' );

    my $plaintext = 123;
    my $encrypted = 'a79';
    is( $hashids->encrypt($plaintext), $encrypted, 'encrypt 1' );
    is( $hashids->decrypt($encrypted), $plaintext, 'decrypt 1' );

    $plaintext = 123456;
    $encrypted = 'AMyLz';
    is( $hashids->encrypt($plaintext), $encrypted, 'encrypt 2' );
    is( $hashids->decrypt($encrypted), $plaintext, 'decrypt 2' );
};

subtest 'list encrypt/decrypt' => sub {
    plan tests => 6;

    my $hashids = Hashids->new( salt => $salt );

    can_ok( $hashids, qw/encrypt decrypt/ );

    my @plaintexts = ( 1, 2, 3 );
    my $encrypted = 'eGtrS8';
    is( $hashids->encrypt(@plaintexts), $encrypted, 'encrypt list 1' );
    is_deeply( scalar $hashids->decrypt($encrypted),
        \@plaintexts, 'decrypt list 1' );

    @plaintexts = ( 123, 456, 789 );
    $encrypted = 'yn8t46hen';
    is( $hashids->encrypt(@plaintexts), $encrypted, 'encrypt list 2' );
    is_deeply( scalar $hashids->decrypt($encrypted),
        \@plaintexts, 'decrypt list 2' );

    subtest 'decrypted return as list' => sub {
        plan tests => 2;

        my @single = $hashids->decrypt('a79');
        is_deeply( \@single, [123], 'decrypted as list (single value)' );

        my @result = $hashids->decrypt($encrypted);
        is_deeply( \@result, \@plaintexts, 'decrypted as list (multi)' );
    };
};
