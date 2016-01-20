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

# Server always sends it's host and port to client
my ($server_fh,$server_host,$server_port);
my $guard=tcp_server( $host, undef,
	sub { # accept callback
		my ($fh, $host, $port) = @_;
		syswrite $fh, "$server_host:$server_port\015\012";
	},
	$cv, # prepare callback
);
($server_fh,$server_host,$server_port) = $cv->recv;
BAIL_OUT "Can not start TCP server: $!" unless $server_fh;

my $cnn = ae::cnn->new( host => $server_host, port => $server_port);
my $expected_read="$server_host:$server_port\015\012";
$cnn->on_read($cv = AE::cv);
$cnn->connect;
(undef, my $actual_read) = $cv->recv;
is($actual_read, $expected_read, "Server reply passed to on_read callback");

$cnn->on_disconnect( $cv  = AE::cv );
$cnn->disconnect;
$cv->recv;

done_testing;

