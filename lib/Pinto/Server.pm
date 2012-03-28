package Pinto::Server;

# ABSTRACT: Web interface to a Pinto repository

use Moose;

use MooseX::Types::Moose qw(HashRef);
use Pinto::Types qw(Dir);

use Carp;
use Dancer qw(:moose :script);
use Class::Load 'load_class';
use Plack::Middleware::Auth::Basic;

use Pinto::Server::Routes;

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------

=attr root

The path to the root directory of your Pinto repository.  The
repository must already exist at this location.  This attribute is
required.

=cut

has root => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
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


#-----------------------------------------------------------------------------
# Methods

=method to_app()

Returns a PSGI-compatible code reference to start the server.

=cut

sub to_app {
    my $self = shift;

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

#-----------------------------------------------------------------------------

=method call($request)

Handles one request to the server.

=cut

sub call {
    my ($self, $env) = @_;

    my $request  = Dancer::Request->new(env => $env);
    my $response = Dancer->dance($request);

    return $response;
}

#-----------------------------------------------------------------------------

=method prepare_app()

Initialize the server.

=cut

sub prepare_app {
    my ($self) = @_;

    Dancer::set( root   => $self->root()  );

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

#----------------------------------------------------------------------------

1;

__END__

=head1 DESCRIPTION

There is nothing to see here.

Look at L<pinto-server> instead.

Then you'll probably want to look at L<pinto-remote>.

See L<Pinto::Manual> for a complete guide.

=cut

