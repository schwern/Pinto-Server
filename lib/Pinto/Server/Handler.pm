# ABSTRACT: Handles requests to the Pinto server.

package Pinto::Server::Handler;

use Moose;

use Carp;
use IO::Pipe;
use MIME::Types;
use Path::Class;
use Proc::Fork;
use File::Copy;
use Path::Class;
use Plack::Response;
use IO::Handle::Util qw(io_from_getline);

use Pinto::Types qw(Dir);

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

=attr root

The path to the root directory of your Pinto repository.  The
repository must already exist at this location.  This attribute is
required.

=cut

#-------------------------------------------------------------------------------

has root  => (
   is       => 'ro',
   isa      => Dir,
   required => 1,
   coerce   => 1,
);

#-------------------------------------------------------------------------------

=method handle($request)

Handles one request, returning an L<Plack::Response> that has not been
finalized.

=cut

sub handle {
    my ($self, $request) = @_;

    my $method = $request->method();
    return $self->_handle_post($request) if $method eq 'POST';
    return $self->_handle_get($request)  if $method eq 'GET';
    confess "Unable to process method $method";
}

#-------------------------------------------------------------------------------

sub _handle_post {
    my ($self, $request) = @_;

    my %params = %{ $request->parameters() };
    my $action = _parse_uri($request->path_info);

    if (my $uploads = $request->uploads) {
        for my $upload_name ( $uploads->keys ) {
            my $upload   = $uploads->{$upload_name};
            my $filename = $upload->filename;
            my $file     = file($upload->path)->dir->file($filename);
            File::Copy::move( $upload->path, $file); #TODO: autodie
            $params{$upload_name} = $file;
        }
    }

    my $response = $request->env->{'psgi.streaming'} ?
                   $self->_stream_response($action, %params)
                 : $self->_splat_response($action, %params);

    return $response;
}

#-------------------------------------------------------------------------------

sub _handle_get {
    my ($self, $request) = @_;

    my $file = file( $self->root(), $request->path_info() );
    confess "$file does not exist"  if not -e $file;
    confess "$file is not readable" if not -r $file;

    my $response = Plack::Response->new();
    $response->content_type( $self->_get_file_type($file) );
    $response->content_length( -s $file );
    $response->body( $file->openr() );
    $response->status(200);

    return $response;
}

#-------------------------------------------------------------------------------

sub _make_pinto {
    my ($self, %args) = @_;
    my $pinto  = Pinto->new(root => $self->root(), %args);
    return $pinto;
}

#-------------------------------------------------------------------------------

sub _parse_uri {
  my ($uri) = @_;
  $uri =~ m{^ /action/ ([^/]*) }mx
    or confess "Cannot parse uri: $uri";

  return ucfirst $1;
}

#-----------------------------------------------------------------------------

sub _get_file_type {
    my ($self, $file) = @_;

    my $mt = MIME::Types->new();
    my $type = $mt->mimeTypeOf($file);

    return $type;
}

#-----------------------------------------------------------------------------

sub _stream_response {
    my ($self, $action, %params) = @_;

    # Here's what's going on: Open a pipe (which has two endpoints),
    # the fork.  The child process runs the Action and writes output
    # to one end of the pipe.  Meanwhile, the parent reads input from
    # the other end of the pipe and spits it into the response via
    # callback.

    my $response;
    my $pipe = IO::Pipe->new();

    run_fork {
        child {
            my $writer = $pipe->writer();
            $writer->autoflush(1);
            $params{out} = $writer;
            my $pinto = $self->_make_pinto(%params);
            $pinto->new_batch(%params, noinit => 1);
            $pinto->add_action($action, %params);
            my $result = $pinto->run_actions();
            exit $result->is_success() ? 0 : 1;
        }
        parent {
            my $reader = $pipe->reader();

            # In Plack::Util::foreach(), input is buffered at 65536
            # bytes We want to buffer each line only.  So we make our
            # own input handle with $/ set accordingly.

            my $getline   = sub { local $/ = "\n"; $reader->getline };
            my $io_handle = io_from_getline( $getline );
            my $headers   = ['Content-Type' => 'text/plain'];
            $response  = sub {$_[0]->( [200, $headers, $io_handle] )};
        }
    };

    return $response;
}

#-----------------------------------------------------------------------------

sub _splat_response {
    my ($self, $action, %params) = @_;

    my $pinto = $self->_make_pinto(%params);
    $pinto->new_batch(%params, noinit => 1);
    $pinto->add_action($action, %params);
    my $result = $pinto->run_actions();

    my $status   = $result->is_success() ? 200 : 500;
    my $body     = $result->to_string();
    my $headers  = [ 'Content-Length' => length $body ];
    my $response = Plack::Response->new($status, $headers, $body);

    return $response;
}

#-----------------------------------------------------------------------------
1;

__END__
