requires 'perl', '5.008001';

requires 'List::MoreUtils',    '0.33';
requires 'Moo',            '1.003000';
requires 'Scalar::Util',       '1.27';

on 'test' => sub {
    requires 'Test::More',       '0.98';
    requires 'Test::Exception',  '0.32';
};

