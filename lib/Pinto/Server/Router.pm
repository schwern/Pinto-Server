# ABSTRACT: Routes server requests

package Pinto::Server::Router;

use Moose;

use Scalar::Util;
use Plack::Request;
use Router::Simple;

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

has route_handler => (
    is      => 'ro',
    isa     => 'Router::Simple',
    default => sub { Router::Simple->new },
);

#-------------------------------------------------------------------------------

sub BUILD {
  my ($self) = @_;

  my $r = $self->route_handler;

  $r->connect( '/action/{action}',
               {responder => 'Action'}, {method => 'POST'} );

  # Route for index of the named stack
  $r->connect( '/{stack}/modules/02packages.details.txt.gz',
               {responder => 'Index' }, {method => 'GET' } );

  # Route for index of the default (unamed) stack
  $r->connect( '/modules/02packages.details.txt.gz',
               {responder => 'File' }, {method => 'GET' } );

  # Route for 03modlist.data.gz (same for all stacks)
  $r->connect( '/{stack}/modules/03modlist.data.gz',
               {responder => 'File' }, {method => 'GET' } );

  # Route for 03modlist.data.gz (same for unamed stack)
  $r->connect( '/modules/03modlist.data.gz',
               {responder => 'File' }, {method => 'GET' } );

  # Route for distributions on the named stack
  $r->connect( '/{stack}/authors/*',
               {responder => 'File'  }, {method => 'GET' } );

  # Route for distributions on the default (unamed) stack
  $r->connect( '/authors/*',
               {responder => 'File'  }, {method => 'GET' } );

  return $self;
}

#-------------------------------------------------------------------------------

=method route( $env, $root )

Given the request environment and the path to the repository root,
dispatches the request to the appropriate responder and returns the
response.

=cut

sub route {
    my ($self, $env, $root) = @_;

    my $p = $self->route_handler->match($env)
      or return [404, [], ['Not Found']];

    my $responder_class = 'Pinto::Server::Responder::' . $p->{responder};
    Class::Load::load_class($responder_class);

    my $request   = Plack::Request->new($env);
    my $responder = $responder_class->new(request => $request, root => $root);

    return $responder->respond;
};

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-------------------------------------------------------------------------------

1;

__END__

=pod

=for stopwords responder

=for Pod::Coverage BUILD

=cut
