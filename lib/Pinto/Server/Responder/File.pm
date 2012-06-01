# ABSTRACT: Responder for static files

package Pinto::Server::Responder::File;

use Moose;

use Path::Class;
use Plack::Response;
use Plack::Mime;

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

has request => (
    is       => 'ro',
    isa      => 'Plack::Request',
    required => 1,
);


has pinto => (
    is       => 'ro',
    isa      => 'Pinto',
    required => 1,
);

#-------------------------------------------------------------------------------

extends qw(Pinto::Server::Responder);

#-------------------------------------------------------------------------------

sub respond {
    my ($self) = @_;

    my (undef, $stack, @path_parts) = split '/', $self->request->path_info;
    my $file = Path::Class::file($self->pinto->root, @path_parts);
    return [404, [], ["File $file not found"]] if not (-e $file and -f $file);

    my $response = Plack::Response->new;
    $response->content_type( Plack::MIME->mime_type($file) );
    $response->content_length(-s $file);
    $response->body($file->openr);
    $response->status(200);

    return $response;
 }

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-------------------------------------------------------------------------------

1;
