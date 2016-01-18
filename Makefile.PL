use 5.008008;
use ExtUtils::MakeMaker;

$ENV{AUTHOR} and require CPAN::Meta;

print STDERR "Configuring ae::cnn\n";

WriteMakefile(
	NAME              => 'ae-cnn',
	VERSION_FROM      => 'lib/ae/cnn.pm',
	PREREQ_PM         => {
		'EV'                      => 4,
		'AnyEvent'                => 5,
	},
	ABSTRACT       => 'Example TCP connector',
	AUTHOR         => 'Maxim Polyakov <mmonk@cpan.org>',
	LICENSE        => 'GPLv2',
	
	EXE_FILES => [ ],
);
