#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

use ae::cnn;
use AnyEvent;
use AnyEvent::Socket;

my $host = '127.0.0.1';

my $cv = AE::cv;
my $guard=tcp_server( $host, undef, sub{ }, $cv );
my ($server,$server_host,$server_port,) = $cv->recv;
BAIL_OUT "Can not start TCP server: $!" unless $server;

#diag "Host: $server_host";
my $cnn = ae::cnn->new( host => $server_host, port => $server_port);
ok $cnn, 'Non-empty object';
$cnn->on_connect( $cv  = AE::cv );
$cnn->connect;
my ($passed_cnn) = $cv->recv;
is( $passed_cnn, $cnn, 'Connection object passed to on_connect callback');
$cnn->on_disconnect( $cv  = AE::cv );
$cnn->disconnect;
$cv->recv;

done_testing;

