use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my %prereq = ( 'HTML::Mason' => 1.09_01 );

eval { require mod_perl };
unless ( $@ || $^O =~ /mac|darwin/ )
{
    $prereq{'Apache::Cookie'} = 0;
}

eval { require HTML::Mason };
unless ($@)
{
    if ( $HTML::Mason::VERSION <= 1.0902 )
    {
	print <<'EOF';

***************************** BUG ALERT *****************************

Please be aware that versions 1.09_01 and 1.09_02 of Mason have a bug
that will make it impossible to configure this module via your
httpd.conf file.  This bug is fixed in CVS and will be included in the
next release of Mason.

EOF
    }
}

WriteMakefile
    ( NAME          => 'HTML::Mason::Request::WithApacheSession',
      VERSION_FROM  => 'lib/HTML/Mason/Request/WithApacheSession.pm',
      PREREQ_PM     => \%prereq,
      ABSTRACT_FROM => 'lib/HTML/Mason/Request/WithApacheSession.pm',
      AUTHOR        => 'Dave Rolsky <autarch@urth.org>',
    )

