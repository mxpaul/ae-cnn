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
		@_,
	);
	croak 'Need host' unless $opt{host};
	croak 'Need port' unless $opt{port} > 0;
	bless ( \%opt, $class);
}

sub on_connect{
	my $self = shift;
	my $cb   = shift or croak 'Need callback';
	$self->{on_connect} = $cb;
};
sub on_disconnect{
	my $self = shift;
	my $cb   = shift or croak 'Need callback';
	$self->{on_disconnect} = $cb;
};

sub disconnect {
	my $self = shift;
	if ($self->{on_disconnect}) {
		$self->{on_disconnect}->($self);
	}
	%$self = map { $_ => $self->{$_} } grep { /^_/} keys %$self;
	return;
}

sub connect {
	my $self = shift;
	tcp_connect($self->{host},  $self->{port}, sub { 
		( $self->{_fd}, $self->{_local_host}, $self->{_local_port} )= @_;
		if ($self->{_fd}) {
			if (ref $self->{on_connect}) {
				$self->{on_connect}->($self);
			}
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
		} else {
			croak 'Connect error: '. $!;
		}	
	});
}

sub on_read {
	my $self = shift;
	$self->{on_read} = shift or croak "Need callback";
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

1;
