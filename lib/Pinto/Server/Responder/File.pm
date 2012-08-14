# ABSTRACT: Responder for static files

package Pinto::Server::Responder::File;

use Moose;

use Path::Class;
use Plack::Response;
use Plack::Mime;

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

extends qw(Pinto::Server::Responder);

#-------------------------------------------------------------------------------

sub respond {
    my ($self) = @_;

    my (undef, @path_parts) = split '/', $self->request->path_info;

    # HACK: The first element of @path_parts could be part of an
    # actual path, or just a stack name (which we don't need).  We
    # will assume that 'authors' and 'modules' are actual paths.
    # Anything else is a stack name that can be discarded.
    shift @path_parts if $path_parts[0] !~ m{^ (?:authors|modules) $}x;

    my $file = Path::Class::file($self->root, @path_parts);

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
