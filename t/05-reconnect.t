#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

use ae::cnn;
use AnyEvent;
use AnyEvent::Socket;
use Carp;
use Test::LeakTrace;

sub AE::cvt(;$){
	my $after = shift || 1;
	my $cv; 
	my $t = AE::timer $after,0, sub { $cv->croak('AE::cvt timed out'); };
	$cv = AE::cv sub { undef $t };
	return $cv;
}

my $host = '127.0.0.1';
#######################################################################
# Case 1. Reconnect after connection reset
#######################################################################
my ($server_fh, $server_host, $server_port);
# Set up
my $cv = AE::cvt;
my $server_guard=tcp_server( $host, undef, sub{ }, $cv );
($server_fh, $server_host, $server_port) = $cv->recv;
close $server_fh; # We have free port, stop the server and try to connect
undef $server_guard;

# Test case
my $complete_cv = AE::cvt;
my $cnn = ae::cnn->new( host => $server_host, port => $server_port, timeout => 0.01);
$cnn->on_connect(sub { $complete_cv->send(1); });
$cnn->connect;

$cv = AE::cvt;
$server_guard=tcp_server( $server_host, $server_port, sub{ }, $cv );
($server_fh, $server_host, $server_port) = $cv->recv;

(my $connected)  = $complete_cv->recv;
is($connected, 1, 'Reconnect leads to connected state after server started');
# Tear down
close $server_fh;
undef $server_guard;

#######################################################################
# Case 2. Reconnect after connection timed out
#######################################################################
# Set up
$cv = AE::cvt;
$server_guard=tcp_server( $server_host, $server_port, sub{ }, $cv );
($server_fh, $server_host, $server_port) = $cv->recv;

# Test case
$complete_cv= AE::cvt 1;
$cnn = ae::cnn->new( host => $server_host, port => $server_port, timeout => 0.00001);
$cnn->on_connfail($complete_cv);
$cnn->connect;
$complete_cv->recv;
$cnn->on_connfail(undef);

$cnn->timeout(2);
$complete_cv= AE::cvt 1;
$cnn->on_connect($complete_cv);
$complete_cv->recv;
ok 'Reconnected after timeout';

# Tear down
close $server_fh;
undef $server_guard;

#######################################################################
# Case 3. Ensure many reconnects are possible and there is no leaks
#######################################################################
# Set up
$cv = AE::cvt;
$server_guard=tcp_server( $server_host, $server_port, sub{ }, $cv );
($server_fh, $server_host, $server_port) = $cv->recv;
# Test case
no_leaks_ok { 
	$complete_cv= AE::cvt 10;
	my $count = 0;
	$cnn->on_connect( sub {
		return $complete_cv->send if $count++ > 1000;
		$cnn->reconnect;
	});
	$cnn->reconnect;
	$complete_cv->recv;
} "No leaks after many reconnects";
# Tear down
close $server_fh;
undef $server_guard;

done_testing();
