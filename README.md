# ae::cnn - TCP connector, written for fun and education, not for production

## SYNOPSYS

    use ae:cnn;
    
    my $buf='';
    my $cnn = ae::cnn->new('1.2.3.4:5');
    $cnn->auto_reconnect=1;
    
    $cnn->on_connect( sub {
			my $cnn = shift;
    	$cnn->write("GET HTTP/1.1 /\n\n");
    });
    
    $cnn->on_read( sub {
			my $cnn = shift;
    	my $data = shift;
    	substr($buf,-1,0,$data);
			$cnn->disconnect if (length($buf) > 1024);
    });

    $cnn->on_disconnect( sub { 
			my $cnn = shift;
    	EV::unloop;
    });
    
    $cnn->on_error( sub {
			my $cnn = shift;
    	warn "Will try to reconect after connection error: $!";
			$buf = ''; # Reset buffer to read again
    });
    
    $cnn->connect;
    
    EV::loop;

This is the basic interface which should be later extended for better error handling
