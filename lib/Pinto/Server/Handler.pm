# ABSTRACT: Handles requests to the Pinto server.

package Pinto::Server::Handler;

use Moose;

use Carp;
use JSON;
use Plack::MIME;
use Path::Class;
use File::Copy;
use Class::Load;
use Plack::Response;

use Pinto::Types qw(Dir);

#-------------------------------------------------------------------------------

# VERSION

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

#-------------------------------------------------------------------------------

=method handle($request)

Handles one L<Plack::Request>, returning a PSGI-compatible array
reference.

=cut

sub handle {
    my ($self, $request) = @_;

    my $method = $request->method();
    return $self->_handle_post($request) if $method eq 'POST';
    return $self->_handle_get($request)  if $method eq 'GET';
    return $self->_error_response(500, "Unable to process method $method");
}

#-------------------------------------------------------------------------------

sub _handle_post {
    my ($self, $request) = @_;

    my %params      = %{ $request->parameters() }; # Copying
    my $action_name = _parse_action_from_path($request->path_info);
    my $action_args = $params{args} ? decode_json( $params{args} ) : {};

    for my $upload_name ( $request->uploads->keys ) {
        my $upload    = $request->uploads->{$upload_name};
        my $basename  = $upload->filename;
        my $localfile = file($upload->path)->dir->file($basename);
        File::Copy::move($upload->path, $localfile); #TODO: autodie
        $action_args->{$upload_name} = $localfile;
    }

    my $responder_class = 'Pinto::Server::ActionResponder::' .
      (($request->env->{'psgi.streaming'} and not $params{nostream}) ? 'Streaming' : 'Splatting');

    Class::Load::load_class($responder_class);
    my $responder = $responder_class->new(root   => $self->root,
                                          action => $action_name,
                                          args   => $action_args);
    return $responder->respond;
}

#-------------------------------------------------------------------------------

sub _handle_get {
    my ($self, $request) = @_;

    # path_info always has a leading slash
    my (undef, $stack, @path_parts) = split '/', $request->path_info;

    if ($path_parts[-1] eq '02packages.details.txt.gz') {
       require Pinto::Server::IndexResponder;
       my $responder = Pinto::Server::IndexResponder->new(root => $self->root, stack => $stack);
       return $responder->respond;
    }

    my $file = file($self->root, @path_parts);
    return $self->_error_response(404, "File $file not found") if not -e $file;

    my $response = Plack::Response->new();
    $response->content_type( Plack::MIME->mime_type($file) );
    $response->content_length( -s $file );
    $response->body( $file->openr );
    $response->status(200);

    return $response;
}

#-------------------------------------------------------------------------------

sub _parse_action_from_path {
    my ($path) = @_;
    $path =~ m{^ /action/ ([^/]*) }mx or confess "Cannot parse path: $path";
    return ucfirst $1;
}

#-----------------------------------------------------------------------------

sub _error_response {
    my ($self, $code, $message) = @_;

    $code    ||= 500;
    $message ||= 'Unkown error';

    return Plack::Response->new($code, undef, $message);
}

#-----------------------------------------------------------------------------
1;

__END__
