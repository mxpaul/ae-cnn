#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

use ae::cnn;
use AnyEvent;
use AnyEvent::Socket;
use Carp;

my $host = '127.0.0.1';
my $message = 'Hello, World!';

my $cv = AE::cv;
my $complete_cv = AE::cv;

# Server always sends it's host and port to client
my ($server_fh,$server_host,$server_port);
my $guard=tcp_server( $host, undef,
	sub { # accept callback
		my ($fh, $host, $port) = @_;
		my $read_bytes = read $fh, my $rbuf, length $message, 0; 
		if ($read_bytes > 0 ) {
			is($read_bytes, length($message), 'Test should be rewritten if this fails');
		} elsif ( $read_bytes == 0) {
			croak 'Client closed connection with no data sent';
		} else {
			croak 'Server: read error from client: ' . $!;
		}
		$complete_cv->send($rbuf);
	},
	$cv, # prepare callback
);
($server_fh,$server_host,$server_port) = $cv->recv;
BAIL_OUT "Can not start TCP server: $!" unless $server_fh;

my $cnn = ae::cnn->new( host => $server_host, port => $server_port);
$cnn->on_connect(sub {
	my ($cnn) = shift; $cnn->write($message);
});
$cnn->connect;

my ($client_message) = $complete_cv->recv;
done_testing;

