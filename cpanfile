requires 'perl', '5.008001';

requires 'List::MoreUtils', '0.33';
requires 'Moo',            '1.003';
requires 'Scalar::Util',    '1.31';

on 'test' => sub {
    requires 'Test::More',       '0.98';
    requires 'Test::Exception',  '0.32';
};

