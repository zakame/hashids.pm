#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

use File::Spec;
use File::Basename;
use lib File::Spec->catdir( dirname(__FILE__), 'lib' );
use SubClassTest;

plan tests => 4;

my $subclass = SubClassTest->new( extra_number => 123 );
isa_ok( $subclass, 'SubClassTest' );
isa_ok( $subclass, 'Hashids' );

my $plaintext = 456;
my $encrypted = 'GoBu7d';

is( $subclass->encrypt($plaintext), $encrypted, 'subclass encrypted' );
is_deeply(
    scalar $subclass->decrypt($encrypted),
    [ $subclass->extra_number, $plaintext ],
    'subclass decrypted'
);
