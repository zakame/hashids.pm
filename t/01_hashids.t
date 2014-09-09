#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Hashids;

plan tests => 6;

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
            'gjklmnopqrvwxyzABDEGJKLMNOPQRVWXYZ1234567890',
            'default alphabet'
        );

        my $alphabet = join '' => ( 'a' .. 'z' );
        $hashids = Hashids->new( alphabet => $alphabet );
        is( $hashids->alphabet, 'degjklmnopqrvwxyz', 'custom alphabet' );

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
        plan tests => 2;

        ok( $hashids->seps,   'has seps' );
        ok( $hashids->guards, 'has guards' );
    };
};

subtest 'internal functions' => sub {
    plan tests => 9;

    is( Hashids->_consistentShuffle( '123', 'salt' ), '231', 'shuffle 1' );
    is( Hashids->_consistentShuffle( 'abcdefghij', 'salt' ),
        'iajecbhdgf', 'shuffle 2' );

    is( Hashids->_consistentShuffle( [ '1', '2', '3' ], 'salt' ),
        '231', 'shuffle alphabet list 1' );
    is( Hashids->_consistentShuffle( [ 'a' .. 'j' ], 'salt' ),
        'iajecbhdgf', 'shuffle alphabet list 2' );

    my @res = Hashids->_consistentShuffle( '123', 'salt' );
    is_deeply( \@res, [qw( 2 3 1 )], 'shuffle returns a list' );

    is( Hashids->_consistentShuffle( [ 'a' .. 'j' ], [qw( s a l t )] ),
        'iajecbhdgf', 'shuffle with salt as list' );

    is( Hashids->_hash( 123, 'abcdefghij' ), 'bcd', 'internal hash' );
    is( Hashids->_unhash( 'bcd', 'abcdefghij' ), 123, 'internal unhash' );

    subtest '_hash/_unhash with list' => sub {
        plan tests => 2;

        my @alphabet = qw(a b c d e f g h i j);
        is( Hashids->_hash( 123, \@alphabet ), 'bcd', 'internal hash' );
        is( Hashids->_unhash( 'bcd', \@alphabet ), 123, 'internal unhash' );
    };
};

subtest 'simple encrypt/decrypt' => sub {
    plan tests => 6;

    my $hashids = Hashids->new( salt => $salt );

    is( $hashids->encrypt(),               '', 'no encrypt' );
    is( $hashids->encrypt('up the wazoo'), '', 'bad encrypt' );

    my $plaintext = 123;
    my $encrypted = 'YDx';
    is( $hashids->encrypt($plaintext), $encrypted, 'encrypt 1' );
    is( $hashids->decrypt($encrypted), $plaintext, 'decrypt 1' );

    $plaintext = 123456;
    $encrypted = '4DLz6';
    is( $hashids->encrypt($plaintext), $encrypted, 'encrypt 2' );
    is( $hashids->decrypt($encrypted), $plaintext, 'decrypt 2' );
};

subtest 'encrypt with minHashLength' => sub {
    plan tests => 2;

    my $hashids = Hashids->new( salt => $salt, minHashLength => 15 );

    my $plaintext = 123;
    my $encrypted = 'V34xpAYDx0mQNvl';
    is( $hashids->encrypt($plaintext), $encrypted, 'encrypt minHashLength' );
    is( $hashids->decrypt($encrypted), $plaintext, 'decrypt minHashLength' );
};

subtest 'list encrypt/decrypt' => sub {
    plan tests => 7;

    my $hashids = Hashids->new( salt => $salt );

    can_ok( $hashids, qw/encrypt decrypt/ );

    my @plaintexts = ( 1, 2, 3 );
    my $encrypted = 'laHquq';
    is( $hashids->encrypt(@plaintexts), $encrypted, 'encrypt list 1' );
    is_deeply( scalar $hashids->decrypt($encrypted),
        \@plaintexts, 'decrypt list 1' );

    @plaintexts = ( 123, 456, 789 );
    $encrypted = 'Z8gi1DIx6';
    is( $hashids->encrypt(@plaintexts), $encrypted, 'encrypt list 2' );
    is_deeply( scalar $hashids->decrypt($encrypted),
        \@plaintexts, 'decrypt list 2' );

    subtest 'decrypted return as list' => sub {
        plan tests => 2;

        my @single = $hashids->decrypt('YDx');
        is_deeply( \@single, [123], 'decrypted as list (single value)' );

        my @result = $hashids->decrypt($encrypted);
        is_deeply( \@result, \@plaintexts, 'decrypted as list (multi)' );
    };

    subtest 'list encrypt/decrypt with minHashLength' => sub {
        plan tests => 2;

        $hashids = Hashids->new( salt => $salt, minHashLength => 16 );
        $encrypted = 'j1DAZ8gi1DIx6Glx';

        is( $hashids->encrypt(@plaintexts),
            $encrypted, 'encrypt list with minHashLength' );

        my @result = $hashids->decrypt($encrypted);
        is_deeply( \@result, \@plaintexts,
            'decrypted as list (minHashLength)' );
    };
};

subtest 'work with counting numbers only' => sub {
    my $hashids = Hashids->new();

    plan tests => 4;

    is( $hashids->encrypt(12.3), '', 'not an integer' );
    is( $hashids->encrypt(-1),   '', 'not a positive integer' );
    is( $hashids->encrypt( 123, 45.6 ), '', 'no integer in list' );
    is( $hashids->encrypt( -1, -2, 3 ), '', 'negative integers in list' );
};
