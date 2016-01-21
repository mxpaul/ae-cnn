#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

use ae::cnn;
use AnyEvent;
use AnyEvent::Socket;
use Carp;

sub AE::cvt(;$){
	my $after = shift || 1;
	my $cv; 
	my $t = AE::timer $after,0, sub { $cv->croak('AE::cvt timed out'); };
	$cv = AE::cv sub { undef $t };
	return $cv;
}

my $host = '127.0.0.1';
my ($server_fh, $server_host, $server_port);

my $cv = AE::cv;
my $server_guard=tcp_server( $host, undef, sub{ }, $cv );
($server_fh, $server_host, $server_port) = $cv->recv;
BAIL_OUT "Can not start TCP server: $!" unless $server_fh;

{ # Make tcp_connect always timeout
	no warnings 'redefine';
	sub ae::cnn::tcp_connect($$$;$){ }
	#*ae::cnn::tcp_connect=*AnyEvent::Socket::tcp_connect;
}

my $complete_cv = AE::cvt;
my $cnn = ae::cnn->new( host => $server_host, port => $server_port, timeout => 0.01);
$cnn->on_connect(sub { $complete_cv->send(1); });
$cnn->on_connfail(sub { $complete_cv->send(0,@_); });
$cnn->connect;

(my $connected,undef,my $reason)  = $complete_cv->recv;
is($connected, 0, 'Connfail callback called after timeout');
like($reason, qr/timed out/i, 'Reason set when connection timed out');

undef $server_guard; # Now we will get connection refused instead of timeout
close($server_fh);
undef $cnn;
{ # Return original tcp_connect to test connection reset condition
	no warnings 'redefine';
	#sub ae::cnn::tcp_connect($$$;$){ }
	*ae::cnn::tcp_connect=*AnyEvent::Socket::tcp_connect;
}
$complete_cv = AE::cvt;
$cnn = ae::cnn->new( host => $server_host, port => $server_port, timeout => 2);
$cnn->on_connect(sub { $complete_cv->send(1); });
$cnn->on_connfail(sub { $complete_cv->send(0, @_); });
$cnn->connect;

($connected, undef, $reason) = $complete_cv->recv;
is($connected, 0, 'Connfail callback called after reset');
like($reason, qr/refused/i, 'Reason contains reset when connection refused');

done_testing;

