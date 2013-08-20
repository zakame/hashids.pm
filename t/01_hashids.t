#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Exception;
BEGIN { use_ok("Hashids"); }

my $salt = "this is my salt";

subtest 'basics' => sub {
    can_ok( Hashids => "new" );
    my $hashids = Hashids->new();
    isa_ok( $hashids, 'Hashids' );

    is( $hashids->salt, '' );

    $hashids = Hashids->new( salt => $salt );
    is( $hashids->salt, $salt );

    subtest 'hash length' => sub {
        is( $hashids->minHashLength, 0 );

        my $minHashLength = 8;
        $hashids = Hashids->new( minHashLength => $minHashLength );
        is( $hashids->minHashLength, $minHashLength );

        $minHashLength = 'top lol';
        throws_ok {
            Hashids->new( minHashLength => $minHashLength );
        }
        qr/not a number/;

        done_testing();
    };

    subtest 'alphabet' => sub {
        is( $hashids->alphabet, 'x4689abdeA7kynopqrXgE5GBKLMjRz' );

        my $alphabet = join '' => ( 'a' .. 'z' );
        $hashids = Hashids->new( alphabet => $alphabet );
        is( $hashids->alphabet, 'adfhijlnoprtuvxyz' );

        $alphabet = "abc";
        throws_ok {
            Hashids->new( alphabet => $alphabet );
        }
        qr/must contain at least 4/;

        $alphabet = "abca";
        throws_ok {
            Hashids->new( alphabet => $alphabet );
        }
        qr/must contain unique/;

        done_testing();
    };

    subtest 'seps and guards' => sub {
        ok( $hashids->seps );
        ok( $hashids->guards );

        done_testing();
    };

    done_testing();
};

subtest 'internal functions' => sub {
    is( Hashids->_consistentShuffle( '123',        'salt' ), '231' );
    is( Hashids->_consistentShuffle( 'abcdefghij', 'salt' ), 'aichgfdebj' );

    is( Hashids->_hash( 123, 'abcdefghij' ), 'bcd' );
    is( Hashids->_unhash( 'bcd', 'abcdefghij' ), 123 );

    done_testing();
};

subtest 'simple encrypt/decrypt' => sub {
    my $hashids = Hashids->new( salt => $salt );

    is( $hashids->encrypt(),               '' );
    is( $hashids->encrypt('up the wazoo'), '' );

    my $plaintext = 123;
    my $encrypted = 'a79';
    is( $hashids->encrypt($plaintext), $encrypted );
    is( $hashids->decrypt($encrypted), $plaintext );

    $plaintext = 123456;
    $encrypted = 'AMyLz';
    is( $hashids->encrypt($plaintext), $encrypted );
    is( $hashids->decrypt($encrypted), $plaintext );

    done_testing();
};

subtest 'list encrypt/decrypt' => sub {
    my $hashids = Hashids->new( salt => $salt );

    my @plaintexts = ( 1, 2, 3 );
    my $encrypted = 'eGtrS8';
    is( $hashids->encrypt(@plaintexts), $encrypted );
    cmp_deeply( $hashids->decrypt($encrypted), \@plaintexts );

    @plaintexts = ( 123, 456, 789 );
    $encrypted = 'yn8t46hen';
    is( $hashids->encrypt(@plaintexts), $encrypted );
    cmp_deeply( $hashids->decrypt($encrypted), \@plaintexts );

    done_testing();
};

done_testing();
