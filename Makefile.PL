use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my %prereq = ( 'HTML::Mason' => 1.12,
	       'Apache::Session' => 1.54,
	     );

eval { require mod_perl };
unless ( $@ || $^O =~ /mac|darwin/ )
{
    $prereq{'Apache::Cookie'} = 0;
}

WriteMakefile
    ( NAME          => 'HTML::Mason::Request::WithApacheSession',
      VERSION_FROM  => 'lib/HTML/Mason/Request/WithApacheSession.pm',
      PREREQ_PM     => \%prereq,
      ABSTRACT_FROM => 'lib/HTML/Mason/Request/WithApacheSession.pm',
      AUTHOR        => 'Dave Rolsky <autarch@urth.org>',
    );
