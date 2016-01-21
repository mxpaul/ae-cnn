package ae::cnn;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use AnyEvent::Socket;
#use Scalar::Util qw(openhandle);

our $VERSION=0.001;

sub new {
	my $class = shift;
	#warn Dumper \@_;
	my %opt = (
		auto_reconnect => 1,
		timeout        => 1,
		@_,
	);
	croak 'Need host' unless $opt{host};
	croak 'Need port' unless $opt{port} > 0;
	bless ( \%opt, $class);
}

BEGIN {
	no strict 'refs';
	# define connection callbacks setters
	for my $event ( qw (connect disconnect read connfail) ) {
		my $cb_name="on_$event";
		* $cb_name = sub {
			$_[0]->{$cb_name} = $_[1] or croak 'Need callback';
		};
	}
}

sub connect: method {
	my $self = shift;
	$self->{_conn_guard} = tcp_connect($self->{host},  $self->{port}, 
		sub { 
			undef $self->{_conn_timer};
			( $self->{_fd}, $self->{_local_host}, $self->{_local_port} )= @_;
			if ($self->{_fd}) {
				$self->_invoke_cb('on_connect');
				$self->_set_conn_readwatcher;
			} else {
				$self->_invoke_cb('on_connfail', $!);
			}	
		}, 
	);
	$self->{_conn_timer} = AE::timer $self->{timeout}, 0, sub {
		delete $self->{$_} for qw (_conn_timer _conn_guard) ;
		$self->_invoke_cb('on_connfail', 'Connection timed out');
	};
}

sub disconnect: method {
	my $self = shift;
	$self->_invoke_cb('on_disconnect');
	%$self = map { $_ => $self->{$_} } grep { /^_/} keys %$self;
	return;
}

sub _set_conn_readwatcher {
	my $self = shift;
	$self->{_read_watcher} = AE::io $self->{_fd}, 0, sub {
		my $read_bytes = sysread $self->{_fd}, my $rbuf, 2<<17,0;
		if ( $read_bytes ) {
			if ($self->{on_read}) { $self->{on_read}->($self, $rbuf)};
		} elsif( $read_bytes == 0) { # EOF
			#undef $self->{_read_watcher};
			#close $self->{_fd};
			croak 'Server disconneceted';
		} else { # Analyse errno
			croak 'Read error: '. $!;
		}
	};
}

sub write: method {
	my $self = shift;
	my $data = shift;
	#croak 'Have nothing to write to' unless $self->{_fd};
	#croak 'File descriptor closed' unless openhandle($self->{_fd});
	my $written_bytes = syswrite $self->{_fd}, $data, length $data, 0;
	if ($written_bytes == length $data) { # Success
	} elsif ( defined $written_bytes) { # Partial write, should queue rest of the data
		croak 'Partial write';
	} else {
		croak 'write error: ' . $!;
	}
}

sub _invoke_cb {
	my $self = shift;
	my $name = shift;
	$self->{$name}->($self,@_) if $self->{$name};
}

1;
