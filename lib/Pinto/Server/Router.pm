# ABSTRACT: Routes server requests

package Pinto::Server::Router;

use Moose;

use Scalar::Util;
use Plack::Request;
use Router::Simple;

use Pinto;

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

  $r->connect( '/{stack}/modules/02packages.details.txt.gz',
               {responder => 'Index' }, {method => 'GET' } );

  $r->connect( '/{stack}/*',
               {responder => 'File'  }, {method => 'GET' } );

  return $self;
}

#-------------------------------------------------------------------------------

sub route {
    my ($self, $env, $root) = @_;

    my $p = $self->route_handler->match($env)
      or return [404, [], ['Not Found']];

    my $pinto = eval { Pinto->new(root => $root) }
      or return [500, [], [$@]];

    my $responder_class = 'Pinto::Server::Responder::' . $p->{responder};
    Class::Load::load_class($responder_class);

    my $request   = Plack::Request->new($env);
    my $responder = $responder_class->new(request => $request, pinto => $pinto);

    return $responder->respond;
};

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-------------------------------------------------------------------------------

1;

__END__
