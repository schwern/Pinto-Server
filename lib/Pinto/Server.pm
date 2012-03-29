# ABSTRACT: Web interface to a Pinto repository

package Pinto::Server;

use Moose;
use MooseX::NonMoose;
use MooseX::ClassAttribute;
use MooseX::Types::Moose qw(Int HashRef);

use Carp;
use Path::Class;
use Class::Load qw(load_class);

use Plack::Request;
use Plack::Response;
use Plack::Middleware::Auth::Basic;

use Pinto;
use Pinto::Types qw(Dir);
use Pinto::Constants qw($PINTO_DEFAULT_SERVER_PORT);

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

extends qw(Plack::Component);

#-------------------------------------------------------------------------------

=attr root

The path to the root directory of your Pinto repository.  The
repository must already exist at this location.  This attribute is
required.

=cut

has root  => (
   is       => 'ro',
   isa      => Dir,
   required => 1,
   coerce   => 1,
);


=attr auth

The hashref of authentication options, if authentication is to be used within
the server. One of the options must be 'backend', to specify which
Authen::Simple:: class to use; the other key/value pairs will be passed as-is
to the Authen::Simple class.

=cut

has auth => (
    is      => 'ro',
    isa     => HashRef,
    traits  => ['Hash'],
    handles => { auth_options => 'elements' },
);

=attr default_port

Returns the default port number that the server will listen on.  This
is a class attribute.

=cut

class_has default_port => (
    is       => 'ro',
    isa      => Int,
    default  => $PINTO_DEFAULT_SERVER_PORT,
);

#-------------------------------------------------------------------------------

sub prepare_app {
    my ($self) = @_;

    my $root = $self->root();
    print "Initializing pinto repository at '$root' ... ";
    my $pinto = eval { Pinto::Server::Routes::pinto() };
    print "\n" and carp "$@" if not $pinto;

    $pinto->new_batch(noinit => 0);
    $pinto->add_action('Nop');

    my $result = $pinto->run_actions();
    print "\n" and die $result->to_string() . "\n" if not $result->is_success();

    print "Done\n";

    return $self;
}

#-------------------------------------------------------------------------------

sub to_app {
    my ($self) = @_;

    $self->prepare_app;
    my $app = sub { $self->call(@_) };

    if (my %auth_options = $self->auth_options) {

        my $backend = delete $auth_options{backend}
          or carp 'No auth backend provided!';

        print "Authenticating using the $backend backend...\n";
        my $class = 'Authen::Simple::' . $backend;
        load_class $class;

        $app = Plack::Middleware::Auth::Basic->wrap($app,
            authenticator => $class->new(%auth_options) );
    }

    return $app;
}

#-------------------------------------------------------------------------------

sub call {
  my ($self, $env) = @_;

    my $request = Plack::Request->new($env);

    my $buffer = '';
    my %params = %{ $request->params() };
    $params{out} = \$buffer;

    my $pinto    = $self->make_pinto(%params);
    my $response = Plack::Response->new();

    if ( $request->method() eq 'POST' ) {
        my $action = parse_uri( $request->request_uri() );

        $pinto->new_batch(%params);
        $pinto->add_action($action, %params);
        $pinto->run_actions();
        $response->body($buffer);

    }
    elsif ( $request->method() eq 'GET' ) {
        my $file = file( $pinto->root(), $request->request_uri() );
        my $type = $self->get_type($file);
        $response->headers->header(Content_Type => $type);
        $response->body( $file->openr() );
    }

    return $response;
}

#-------------------------------------------------------------------------------

sub make_pinto {
    my ($self, %args) = @_;
    my $pinto  = Pinto->new(root => $self->root(), %args);
    return $pinto;
}

#------------------------------------------------------------------------------

sub parse_uri {
  my ($uri) = @_;
  $uri =~ m{^ /action/ ([^/]*) }mx
    or croak "Cannot parse uri: $uri";

  return ucfirst $1;
}

#-------------------------------------------------------------------------------

sub run {
    my ($self, @args) = @_;
    return $self->engine->run(@_);
}

#-------------------------------------------------------------------------------
1;

__END__



