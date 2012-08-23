# ABSTRACT: Responder for static files

package Pinto::Server::Responder::File;

use Moose;

use Plack::Response;
use Plack::MIME;

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

extends qw(Pinto::Server::Responder);

#-------------------------------------------------------------------------------

sub respond {
    my ($self) = @_;

    # e.g. /stack_name/modules/02packages.details.txt.gz
    my (undef, @path_parts) = split '/', $self->request->path_info;

    my $file = $self->root->file(@path_parts);

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
