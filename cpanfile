requires 'perl', '5.008001';

requires 'Carp',                  '0';
requires 'Exporter',           '5.57';
requires 'List::Util',            '0';
requires 'Moo',            '1.003000';
requires 'Math::BigInt',   '1.999813';
requires 'namespace::clean',   '0.27';
requires 'POSIX',                 '0';

on 'test' => sub {
    requires 'Test::More',       '0.98';
    requires 'Test::Exception',  '0.32';
};

