requires 'perl', '5.008001';

requires 'Carp',               '1.26';
requires 'Moo',            '1.003000';
requires 'Math::BigInt',     '1.9993';

on 'test' => sub {
    requires 'Test::More',       '0.98';
    requires 'Test::Exception',  '0.32';
};

