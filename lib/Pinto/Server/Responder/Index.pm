# ABSTRACT: Responder for the 02packages index

package Pinto::Server::Responder::Index;

use Moose;

use File::Temp;
use Path::Class;
use Plack::Response;

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

extends qw(Pinto::Server::Responder);

#-------------------------------------------------------------------------------

sub respond {
    my ($self) = @_;

    # path_info always has a leading slash
    my (undef, $stk_name, @path_parts) = split '/', $self->request->path_info;

    my $temp_handle = File::Temp->new;
    my $temp_file   = file($temp_handle->filename);
    my $stack       = $self->pinto->repos->get_stack(name => $stk_name);

    $self->pinto->repos->write_index(stack => $stack, file  => $temp_file);

    my $response = Plack::Response->new;
    $response->content_type('application/x-gzip');
    $response->content_length(-s $temp_file);
    $response->body($temp_handle);
    $response->status(200);

    return $response;
 }

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-------------------------------------------------------------------------------

1;
