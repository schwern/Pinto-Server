# ABSTRACT: Base class for responders

package Pinto::Server::Responder;

use Moose;

use Carp;

use Pinto::Types qw(Dir);

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

has request => (
    is       => 'ro',
    isa      => 'Plack::Request',
    required => 1,
);


has root => (
    is       => 'ro',
    isa      => Dir,
    required => 1,
);

#-------------------------------------------------------------------------------

sub respond { croak 'abstract method' }

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-------------------------------------------------------------------------------

1;

__END__
