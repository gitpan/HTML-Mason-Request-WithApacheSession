#!/usr/bin/perl -w

use strict;

use File::Path;
use File::Spec;
use HTML::Mason::Tests;

my $tests = make_tests();
$tests->run;

sub make_tests
{
    my $group =
	 HTML::Mason::Tests->new
	     ( name => 'basic-session',
	       description => 'Basic tests for Request::WithApacheSession subclass' );

    my %params =
	( request_class  => 'HTML::Mason::Request::WithApacheSession',
	  session_class  => 'File',
	);

    foreach ( [ session_directory => 'sessions' ],
	      [ session_lock_directory => 'session_locks' ]
	    )
    {
	my $dir = File::Spec->catfile( $group->data_dir, $_->[1] );
	mkpath($dir);

	$params{ $_->[0] } = $dir;
    }

    # will be used below in various ways
    use Apache::Session::File;
    my %session;
    tie %session, 'Apache::Session::File', undef,
        { Directory => $params{session_directory},
	  LockDirectory => $params{session_lock_directory} };
    $session{bar}{baz} = 1;
    my $id = $session{_session_id};
    untie %session;

#------------------------------------------------------------

    $group->add_test
	( name => 'can_session',
	  description => 'make sure request->can("session")',
	  interp_params => \%params,
	  component => <<'EOF',
I <% $m->can('session') ? 'can' : 'cannot' %> session
EOF
	  expect => <<'EOF',
I can session
EOF
	);

#------------------------------------------------------------

    $group->add_test
	( name => 'isa_session',
	  description => 'make sure request->session->isa("Apache::Session")',
	  interp_params => \%params,
	  component => <<'EOF',
$m->session ref: <% ref $tied %>
<%init>
my $s = $m->session;
my $tied = tied(%$s);
</%init>
EOF
	  expect => <<'EOF',
$m->session ref: Apache::Session::File
EOF
	);

#------------------------------------------------------------

    $group->add_test
	( name => 'session_store',
	  description => 'store something in the session',
	  interp_params => \%params,
	  component => <<"EOF",
stored
<%init>
\$m->session( session_id => '$id' )->{foo} = 'bar';
</%init>
EOF
	  expect => <<'EOF',
stored
EOF
	);

#------------------------------------------------------------

    $group->add_test
	( name => 'session_read',
	  description => 'read stored data from the session',
	  interp_params => \%params,
	  component => <<"EOF",
read: <% \$m->session( session_id => '$id' )->{foo} %>
EOF
	  expect => <<'EOF',
read: bar
EOF
	);

#------------------------------------------------------------

    $group->add_test
	( name => 'session_allow_invalid',
	  description => 'test that session id can be invalid',
	  interp_params => \%params,
	  component => <<'EOF',
ok
<%init>
$m->session( session_id => 'abcdef' );
</%init>
EOF
	  expect => <<'EOF',
ok
EOF
	);

#------------------------------------------------------------

    $group->add_test
	( name => 'session_do_not_allow_invalid',
	  description => 'test that session id cannot be invalid',
	  interp_params => { %params,
			     session_allow_invalid_id => 0 },
	  component => <<'EOF',
<%init>
$m->session( session_id => 'abcdef' );
</%init>
EOF
	  expect_error => qr/Invalid session id/,
	);

#------------------------------------------------------------

    $group->add_test
	( name => 'session_always_write_on_1',
	  description => 'test always write (part 1)',
	  interp_params => \%params,
	  component => <<"EOF",
bar:baz: <% \$m->session( session_id => '$id' )->{bar}{baz} %>
<%init>
\$m->session( session_id => '$id' )->{bar}{baz} = 50;
</%init>
EOF
	  expect => <<'EOF',
bar:baz: 50
EOF
	);

#------------------------------------------------------------

    $group->add_test
	( name => 'session_always_write_2',
	  description => 'test always write (part 2)',
	  interp_params => \%params,
	  component => <<"EOF",
bar:baz: <% \$m->session( session_id => '$id' )->{bar}{baz} %>
EOF
	  expect => <<'EOF',
bar:baz: 50
EOF
	);

#------------------------------------------------------------

    $group->add_test
	( name => 'session_always_write_off_1',
	  description => 'test turning off always write (part 1)',
	  interp_params => { %params,
			     session_always_write => 0 },
	  component => <<"EOF",
bar:baz: <% \$m->session( session_id => '$id' )->{bar}{baz} %>
<%init>
\$m->session( session_id => '$id' )->{bar}{baz} = 100;
</%init>
EOF
	  expect => <<'EOF',
bar:baz: 100
EOF
	);

#------------------------------------------------------------

    $group->add_test
	( name => 'session_always_write_off_2',
	  description => 'test turning off always write (part 2)',
	  interp_params => { %params,
			     session_always_write => 0 },
	  component => <<"EOF",
bar:baz: <% \$m->session( session_id => '$id' )->{bar}{baz} %>
EOF
	  expect => <<'EOF',
bar:baz: 50
EOF
	);

#------------------------------------------------------------

    return $group;
}
