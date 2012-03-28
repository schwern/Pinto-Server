# ABSTRACT: Web interface to a Pinto repository

package Pinto::Server;

use Moose;
use Pinto::Types qw(Dir);

use Carp;
use Pinto;
use Path::Class;
use HTTP::Engine;

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

has root  => (
   is       => 'ro',
   isa      => Dir,
   required => 1,
   coerce   => 1,
);


has engine => (
   is         => 'ro',
   isa        => 'HTTP::Engine',
   init_arg   => undef,
   lazy_build => 1,
);

#-------------------------------------------------------------------------------

sub _build_engine {
    my ($self) = @_;

    my $handler   = sub { $self->handle_request(@_) };
    my $interface = {module => 'PSGI', request_handler => $handler};
    my $engine    = HTTP::Engine->new(interface => $interface);

    return $engine;
}

#-------------------------------------------------------------------------------

sub handle_request {
  my ($self, $request) = @_;

    my $buffer = '';
    my %params = %{ $request->params() };
    $params{out} = \$buffer;

    my $pinto    = $self->make_pinto(%params);
    my $response = HTTP::Engine::Response->new();

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



