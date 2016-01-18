#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'ae::cnn' ) || print "Bail out!\n";
}

diag( "Testing ae::cnn $ae::cnn::VERSION, Perl $], $^X" );
