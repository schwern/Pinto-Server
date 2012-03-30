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
use Pinto::Server::Handler;

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

=attr handler

An object that does the L<Pinto::Server::Handler> role.  This object
will do the work of processing the request and returning a response.

=cut

has handler => (
    is      => 'ro',
    isa     => 'Pinto::Server::Handler',
    builder => '_build_handler',
    lazy    => 1,
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

sub _build_handler {
    my ($self) = @_;

    return Pinto::Server::Handler->new(root => $self->root);
}

#-------------------------------------------------------------------------------

sub prepare_app {
    my ($self) = @_;

    my $root = $self->root();
    print "Initializing pinto repository at '$root' ... ";
    my $pinto = $self->make_pinto();
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

    my $request  = Plack::Request->new($env);
    my $response = $self->handler->handle($request);

    return $response->finalize();
}

#-------------------------------------------------------------------------------

sub make_pinto {
    my ($self, %args) = @_;
    my $pinto  = Pinto->new(root => $self->root(), %args);
    return $pinto;
}

#------------------------------------------------------------------------------
1;

__END__

=pod

There is nothing to see here.

Look at L<pinto-server> if you want to start the server.

=cut


