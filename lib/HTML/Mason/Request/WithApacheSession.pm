package HTML::Mason::Request::WithApacheSession;

use 5.005;
use strict;

use vars qw($VERSION @ISA);

$VERSION = '0.04';

use Apache::Session;

use Exception::Class ( 'HTML::Mason::Exception::NonExistentSessionID' =>
		       { isa => 'HTML::Mason::Exception',
			 description => 'An non-existent session id was used',
			 fields => [ 'session_id' ] },
		     );

use HTML::Mason::Exceptions ( abbr => [ qw( param_error error ) ] );
use HTML::Mason::Request;

use Params::Validate qw(:all);
Params::Validate::validation_options( on_fail => sub { param_error( join '', @_ ) } );

# This may change later
@ISA = qw(HTML::Mason::Request);

my %params =
    ( session_always_write =>
      { type => BOOLEAN,
	default => 1,
	descr => 'Whether or not to force a write before the session goes out of scope' },

      session_allow_invalid_id =>
      { type => BOOLEAN,
	default => 1,
	descr => 'Whether or not to allow a failure to find an existing session id' },

      session_use_cookie =>
      { type => BOOLEAN,
	default => 0,
	descr => 'Whether or not to use a cookie to track the session' },

      session_cookie_name =>
      { type => SCALAR,
	default => 'HTML-Mason-Request-WithApacheSession-cookie',
	descr => 'Name of cookie used by this module' },

      session_cookie_expires =>
      { type => SCALAR,
	default => '+1d',
	descr => 'Expiration time for cookies' },

      session_cookie_domain =>
      { type => SCALAR,
	default => undef,
	descr => 'Domain parameter for cookies' },

      session_cookie_path =>
      { type => SCALAR,
	default => '/',
	descr => 'Path for cookies' },

      session_cookie_secure =>
      { type => BOOLEAN,
	default => 0,
	descr => 'Are cookies sent only for SSL connections?' },

      session_class =>
      { type => SCALAR,
	descr => 'An Apache::Session class to use for sessions' },

      session_data_source =>
      { type => SCALAR,
	optional => 1,
	descr => 'The data source when using MySQL or PostgreSQL' },

      session_user_name =>
      { type => SCALAR,
	default => undef,
	descr => 'The user name to be used when connecting to a database' },

      session_password =>
      { type => SCALAR,
	default => undef,
	descr => 'The password to be used when connecting to a database' },

      session_lock_data_source =>
      { type => SCALAR,
	optional => 1,
	descr => 'The data source when using MySQL or PostgreSQL' },

      session_lock_user_name =>
      { type => SCALAR,
	default => undef,
	descr => 'The user name to be used when connecting to a database' },

      session_lock_password =>
      { type => SCALAR,
	default => undef,
	descr => 'The password to be used when connecting to a database' },

      session_handle =>
      { optional => 1,
	descr => 'An existing database handle to use' },

      session_lock_handle =>
      { optional => 1,
	descr => 'An existing database handle to use' },

      session_commit =>
      { default => 1,
	descr => 'Whether or not to auto-commit changes to the database' },

      session_transaction =>
      { type => BOOLEAN,
	default => 0,
	descr => 'The Transaction flag for Apache::Session' },

      session_directory =>
      { type => SCALAR,
	default => undef,
	descr => 'A directory to use when storing sessions' },

      session_lock_directory =>
      { type => SCALAR,
	default => undef,
	descr => 'A directory to use for locking when storing sessions' },

      session_file_name =>
      { type => SCALAR,
	optional => 1,
	descr => 'A DB_File to use' },

      session_store =>
      { type => SCALAR,
	optional => 1,
	descr => 'A storage class to use with the Flex module' },

      session_lock =>
      { type => SCALAR,
	optional => 1,
	descr => 'A locking class to use with the Flex module' },

      session_generate =>
      { type => SCALAR,
	default => 'MD5',
	descr => 'A session generator class to use with the Flex module' },

      session_serialize =>
      { type => SCALAR,
	optional => 1,
	descr => 'A serialization class to use with the Flex module' },

      session_textsize =>
      { type => SCALAR,
	optional => 1,
	descr => 'A parameter for the Sybase storage module' },

      session_long_read_len =>
      { type => SCALAR,
	optional => 1,
	descr => 'A parameter for the Oracle storage module' },

      session_n_sems =>
      { type => SCALAR,
	optional => 1,
	descr => 'A parameter for the Semaphore locking module' },

      session_semaphore_key =>
      { type => SCALAR,
	optional => 1,
	descr => 'A parameter for the Semaphore locking module' },

      session_mod_usertrack_cookie_name =>
      { type => SCALAR,
	optional => 1,
	descr => 'The cookie name used by mod_usertrack' },

      session_save_path =>
      { type => SCALAR,
	optional => 1,
	descr => 'Path used by Apache::Session::PHP' },

    );

__PACKAGE__->valid_params(%params);

# What set of parameters are required for each session class.
# Multiple array refs represent multiple possible sets of parameters
my %ApacheSessionParams =
    ( Flex     => [ [ qw( store lock generate serialize ) ] ],
      MySQL    => [ [ qw( data_source user_name password
                          lock_data_source lock_user_name lock_password ) ],
		    [ qw( handle lock_handle ) ] ],
      Postgres => [ [ qw( data_source user_name password commit ) ],
		    [ qw( handle commit ) ] ],
      File     => [ [ qw( directory lock_directory ) ] ],
      DB_File  => [ [ qw( file_name lock_directory ) ] ],

      PHP      => [ [ qw( save_path ) ] ],
    );

$ApacheSessionParams{Oracle} =
      $ApacheSessionParams{Sybase} =
      $ApacheSessionParams{Postgres};

my %OptionalApacheSessionParams =
    ( Sybase => [ qw( textsize ) ],
      Oracle => [ qw( long_read_len ) ],
    );

my %ApacheSessionFlexParams =
    ( store =>
      { MySQL    => [ [ qw( data_source user_name password ) ],
		      [ qw( handle ) ] ],
	Postgres => $ApacheSessionParams{Postgres},
	File     => [ [ qw( directory ) ] ],
	DB_File  => [ [ qw( file_name ) ] ],
      },
      lock =>
      { MySQL     => [ [ qw( lock_data_source lock_user_name lock_password ) ],
		       [ qw( lock_handle ) ] ],
	File      => [ [ ] ],
	Null      => [ [ ] ],
	Semaphore => [ [ ] ],
      },
      generate =>
      { MD5          => [ [ ] ],
	ModUniqueId  => [ [ ] ],
	ModUsertrack => [ [ qw( mod_usertrack_cookie_name )  ] ],
      },
      serialize =>
      { Storable => [ [ ] ],
	Base64   => [ [ ] ],
	UUEncode => [ [ ] ],
      },
    );

$ApacheSessionFlexParams{store}{Oracle} =
      $ApacheSessionFlexParams{store}{Sybase} =
      $ApacheSessionFlexParams{store}{Postgres};

my %OptionalApacheSessionFlexParams =
    ( Sybase => { store => [ qw( textsize ) ] },
      Oracle => { store => [ qw( long_read_len ) ] },
    );

sub _studly_form
{
    my $string = shift;
    $string =~ s/(?:^|_)(\w)/\U$1/g;
    return $string;
}

my %StudlyForm =
    ( map { $_ => _studly_form($_) }
      map { ref $_ ? @$_ :$_ }
      map { @$_ }
      ( values %ApacheSessionParams ),
      ( values %OptionalApacheSessionParams ),
      ( map { values %{ $ApacheSessionFlexParams{$_} } }
	keys %ApacheSessionFlexParams ),
      ( map { values %{ $OptionalApacheSessionFlexParams{$_} } }
	keys %OptionalApacheSessionFlexParams ),
    );

# why Apache::Session does this I do not know
$StudlyForm{textsize} = 'textsize';

sub new
{
    {
        my $new_isa = ( $HTML::Mason::ApacheHandler::VERSION ?
                        'HTML::Mason::Request::ApacheHandler' :
                        $HTML::Mason::CGIHandler::VERSION ?
                        'HTML::Mason::Request::CGI' :
                        'HTML::Mason::Request' );

        if ( $ISA[0] ne $new_isa )
        {
            @ISA = $new_isa;
            __PACKAGE__->valid_params(%params);
        }
    }

    my $class = shift;

    my $self = $class->SUPER::new(@_);

    $self->_check_params;

    require Apache::Cookie if $self->{session_use_cookie};

    eval "require Apache::Session::$self->{session_class_piece}";
    die $@ if $@;

    return $self;
}

sub _check_params
{
    my $self = shift;

    $self->{session_class_piece} = $self->{session_class};
    $self->{session_class_piece} =~ s/^Apache::Session:://;

    my $sets = $ApacheSessionParams{ $self->{session_class_piece} }
	or param_error "Invalid session class: $self->{session_class}";

    my $complete = $self->_check_sets($sets);

    param_error "Not all of the required parameters for your chosen session class ($self->{session_class}) were provided."
	unless $complete;

    if ( $self->{session_class_piece} eq 'Flex' )
    {
	foreach my $key ( keys %ApacheSessionFlexParams )
	{
	    my $subclass = $self->{"session_$key"};
	    my $sets = $ApacheSessionFlexParams{$key}{$subclass}
		or param_error "Invalid class for $key: $self->{$key}";

	    my $complete = $self->_check_sets($sets);

	    param_error "Not all of the required parameters for your chosen $key class ($subclass) were provided."
		unless $complete;
	}
    }
}

sub _check_sets
{
    my $self = shift;
    my $sets = shift;

    foreach my $set (@$sets)
    {
	return 1
	    if ( grep { exists $self->{"session_$_"} } @$set ) == @$set;
    }

    return 0;
}

sub exec
{
    my $self = shift;

    unless ( $self->is_subrequest )
    {
	if ( $self->{session_use_cookie} )
	{
	    my %c = Apache::Cookie->fetch;
	    $self->{session_id} =
		( exists $c{ $self->{session_cookie_name} } ?
		  $c{ $self->{session_cookie_name} }->value :
		  undef );
	}
    }

    my @r;

    if (wantarray)
    {
	@r = $self->SUPER::exec(@_);
    }
    else
    {
	$r[0] = $self->SUPER::exec(@_);
    }

    unless ( $self->is_subrequest )
    {
	$self->_cleanup_session;
    }

    return wantarray ? @r : $r[0];
}

sub session
{
    my $self = shift;

    return $self->parent_request->session(@_) if $self->is_subrequest;

    $self->{session} ||= $self->_make_session(@_);
    $self->{session_id} ||= $self->{session}{_session_id};

    $self->_bake_cookie if $self->{session_use_cookie};

    return $self->{session};
}

sub _make_session
{
    my $self = shift;
    my %p = validate( @_,
		      { session_id =>
			{ type => SCALAR,
			  default => $self->{session_id},
			},
		      } );

    my $params = $self->_session_params;

    my %s;

    {
	local $SIG{__DIE__};
	eval
	{
	    tie %s, "Apache::Session::$self->{session_class_piece}", $p{session_id}, $params;
	};
    }

    if ($@)
    {
	if ( $@ =~ /Object does not exist/ )
	{
	    HTML::Mason::Exception::NonExistentSessionID->throw
		( error => "Invalid session id: $p{session_id}",
		  session_id => $p{session_id} )
		    unless $self->{session_allow_invalid_id};
	}
	else
	{
	    die $@;
	}

	tie %s, "Apache::Session::$self->{session_class_piece}", undef, $params;
    }

    return \%s;
}

sub _bake_cookie
{
    my $self = shift;

    my $domain =
	$self->{session_cookie_domain};

    Apache::Cookie->new
	( $self->apache_req,
	  -name    => $self->{session_cookie_name},
	  -value   => $self->{session_id},
	  -expires => $self->{session_cookie_expires},
	  ( defined $self->{session_cookie_domain} ?
	    ( -domain  => $domain ) :
	    ()
	  ),
	  -path    => $self->{session_cookie_path},
	  -secure  => $self->{session_cookie_secure},
	)->bake;
}

sub _session_params
{
    my $self = shift;

    my %params;

    $self->_sets_to_params
	( $ApacheSessionParams{ $self->{session_class_piece} },
	  \%params );

    $self->_sets_to_params
	( $OptionalApacheSessionParams{ $self->{session_class_piece} },
	  \%params );


    if ( $self->{session_class_piece} eq 'Flex' )
    {
	foreach my $key ( keys %ApacheSessionFlexParams )
	{
	    my $subclass = $self->{"session_$key"};
	    $params{ $StudlyForm{$key} } = $subclass;

	    $self->_sets_to_params
		( $ApacheSessionFlexParams{$key}{$subclass},
		  \%params );

	    $self->_sets_to_params
		( $OptionalApacheSessionFlexParams{$key}{$subclass},
		  \%params );
	}
    }

    return \%params;
}

sub _sets_to_params
{
    my $self = shift;
    my $sets = shift;
    my $params = shift;

    foreach my $set (@$sets)
    {
	foreach my $key (@$set)
	{
	    if ( exists $self->{"session_$key"} )
	    {
		$params->{ $StudlyForm{$key} } =
		    $self->{"session_$key"};
	    }
	}
    }
}

sub _cleanup_session
{
    my $self = shift;

    if ( $self->{session_always_write} )
    {
	$self->{session}{___force_a_write___} ||= 0;

	if ( $self->{session}->{___force_a_write___} == 1 )
	{
	    $self->{session}{___force_a_write___} = 0;
	}
	else
	{
	    $self->{session}{___force_a_write___} = 1;
	}
    }

    untie %{ $self->{session} };
}

1;

__END__

=head1 NAME

HTML::Mason::Request::WithApacheSession - Add a session to the Mason Request object

=head1 SYNOPSIS

In your F<httpd.conf> file:

  PerlSetVar  MasonRequestClass         HTML::Mason::Request::WithApacheSession
  PerlSetVar  MasonSessionCookieDomain  .example.com
  PerlSetVar  MasonSessionClass         Apache::Session::MySQL
  PerlSetVar  MasonSessionDataSource    dbi:mysql:somedb

In a component:

  $m->session->{foo} = 1;
  if ( $m->session->{bar}{baz} > 1 ) { ... }

=head1 DESCRIPTION

This module integrates C<Apache::Session> into Mason by adding methods
to the Mason Request object available in all Mason components.

Any subrequests created by a request share the same session hash.

=head1 USAGE

To use this module you need to tell Mason to use this class for
requests.  This can be done in one of two ways.  If you are
configuring Mason via your F<httpd.conf> file, simply add this:

  PerlSetVar  MasonRequestClass  HTML::Mason::Request::WithApacheSession

If you are using a F<handler.pl> file, simply add this parameter to
the parameters given to the ApacheHandler constructor:

  request_class => 'HTML::Mason::Request::WithApacheSession'

=head1 CONFIGURATION

This module accepts quite a number of parameters, most of which are
simply passed through to C<Apache::Session>.  For this reason, you are
advised to familiarize yourself with the C<Apache::Session>
documentation before attempting to configure tihs module.

=head2 Generic Parameters

=over 4

=item * session_class / MasonSessionClass  =>  class name

The name of the C<Apache::Session> subclass you would like to use.

This module will load this class for you if necessary.

This parameter is required.

=item * session_always_write / MasonSessionAlwaysWrite  =>  boolean

If this is true, then this module will ensure that C<Apache::Session>
writes the session.  If it is false, the default C<Apache::Session>
behavior is used instead.

This defaults to true.

=item * session_allow_invalid_id / MasonSessionAllowInvalidId  =>  boolean

If this is true, an attempt to create a session with a session id that
does not exist in the session storage will be ignored, and a new
session will be created instead.  If it is false, a
C<HTML::Mason::Exception::NonExistentSessionID> exception will be
thrown instead.

This defaults to true.

=back

=head2 Cookie-Related Parameters

=over 4

=item * session_use_cookie / MasonSessionUseCookie  =>  boolean

If true, then this module will use C<Apache::Cookie> to set and read
cookies that contain the session id.

The cookie will be set again every time the client accesses a Mason
component.

=item * session_cookie_name / MasonSessionCookieName  =>  name

This is the name of the cookie that this module will set.  This
defaults to "HTML-Mason-Request-WithApacheSession-cookie".
Corresponds to the C<Apache::Cookie> "-name" constructor parameter.

=item * session_cookie_expires / MasonSessionCookieExpires  =>  expiration

How long before the cookie expires.  This defaults to 1 day, "+1d".
Corresponds to the "-expires" parameter.

=item * session_cookie_domain / MasonSessionCookieDomain  =>  domain

This corresponds to the "-domain" parameter.  If not given this will
not be set as part of the cookie.

=item * session_cookie_path / MasonSessionCookiePath  =>  path

Corresponds to the "-path" parameter.  It defaults to "/".

=item * session_cookie_secure / MasonSessionCookieSecure  =>  boolean

Corresponds to the "-secure" parameter.  It defaults to false.

=back

=head2 Apache::Session-related Parameters

These parameters are simply passed through to C<Apache::Session>.

=over 4

=item * session_data_source / MasonSessionDataSource  =>  DSN

Corresponds to the C<DataSource> parameter given to the DBI-related
session modules.

=item * session_user_name / MasonSessionUserName  =>  user name

Corresponds to the C<UserName> parameter given to the DBI-related
session modules.

=item * session_password / MasonSessionPassword  =>  password

Corresponds to the C<Password> parameter given to the DBI-related
session modules.

=item * session_handle / MasonSessionHandle =>  DBI handle

Corresponds to the C<Handle> parameter given to the DBI-related
session modules.

=item * session_lock_data_source / MasonSessionLockDataSource  =>  DSN

Corresponds to the C<LockDataSource> parameter given to
C<Apache::Session::MySQL>.

=item * session_lock_user_name / MasonSessionLockUserName  =>  user name

Corresponds to the C<LockUserName> parameter given to
C<Apache::Session::MySQL>.

=item * session_lock_password / MasonSessionLockPassword  =>  password

Corresponds to the C<LockPassword> parameter given to
C<Apache::Session::MySQL>.

=item * session_lock_handle / MasonSessionLockHandle  =>  DBI handle

Corresponds to the C<LockHandle> parameter given to the DBI-related
session modules.

=item * session_commit / MasonSessionCommit =>  boolean

Corresponds to the C<Commit> parameter given to the DBI-related
session modules.

=item * session_transaction / MasonSessionTransaction  =>  boolean

Corresponds to the C<Transaction> parameter.

=item * session_directory / MasonSessionDirectory  =>  directory

Corresponds to the C<Directory> parameter given to
C<Apache::Session::File>.

=item * session_lock_directory / MasonSessionLockDirectory  =>  directory

Corresponds to the C<LockDirectory> parameter given to
C<Apache::Session::File>.

=item * session_file_name / MasonSessionFileName  =>  file name

Corresponds to the C<FileName> parameter given to
C<Apache::Session::DB_File>.

=item * session_store / MasonSessionStore  =>  class

Corresponds to the C<Store> parameter given to
C<Apache::Session::Flex>.

=item * session_lock / MasonSessionLock  =>  class

Corresponds to the C<Lock> parameter given to
C<Apache::Session::Flex>.

=item * session_generate / MasonSessionGenerate  =>  class

Corresponds to the C<Generate> parameter given to
C<Apache::Session::Flex>.

=item * session_serialize / MasonSessionSerialize  =>  class

Corresponds to the C<Serialize> parameter given to
C<Apache::Session::Flex>.

=item * session_textsize / MasonSessionTextsize  =>  size

Corresponds to the C<textsize> parameter given to
C<Apache::Session::Sybase>.

=item * session_long_read_len / MasonSessionLongReadLen  =>  size

Corresponds to the C<LongReadLen> parameter given to
C<Apache::Session::MySQL>.

=item * session_n_sems / MasonSessionNSems  =>  number

Corresponds to the C<NSems> parameter given to
C<Apache::Session::Lock::Semaphore>.

=item * session_semaphore_key / MasonSessionSemaphoreKey  =>  key

Corresponds to the C<SemaphoreKey> parameter given to
C<Apache::Session::Lock::Semaphore>.

=item * session_mod_usertrack_cookie_name / MasonSessionModUsertrackCookieName  =>  name

Corresponds to the C<ModUsertrackCookieName> parameter given to
C<Apache::Session::Generate::ModUsertrack>.

=item * session_save_path / MasonSessionSavePath  =>  path

Corresponds to the C<SavePath> parameter given to
C<Apache::Session::PHP>.

=back

=head1 BUGS

As can be seen by the number of parameters above, C<Apache::Session>
has B<way> too many possibilities for me to test all of them.  This
means there are almost certainly bugs.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 SEE ALSO

HTML::Mason

=cut
