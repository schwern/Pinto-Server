# ABSTRACT: Handles requests to the Pinto server.

package Pinto::Server::Handler;

use Moose;

use Carp;
use IO::Pipe;
use Plack::MIME;
use Path::Class;
use Proc::Fork;
use File::Copy;
use Path::Class;
use Plack::Response;
use English qw(-no_match_vars);
use IO::Handle::Util qw(io_from_getline);
use POSIX qw(:sys_wait_h);

use Pinto::Types qw(Dir);
use Pinto::Constants qw(:all);

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
    return $self->_error_response(500, "Unable to process method $method");
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
    return $self->_error_response(404, "File $file not found") if not -e $file;

    my $response = Plack::Response->new();
    $response->content_type( Plack::MIME->mime_type($file) );
    $response->content_length( -s $file );
    $response->body( $file->openr() );
    $response->status(200);

    return $response;
}

#-------------------------------------------------------------------------------

sub _parse_uri {
  my ($uri) = @_;
  $uri =~ m{^ /action/ ([^/]*) }mx
    or confess "Cannot parse uri: $uri";

  return ucfirst $1;
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
            my $result = $self->_run_pinto($action, %params);
            exit $result->is_success() ? 0 : 1;
        }
        parent {
            my $child_pid = shift;
            my $reader    = $pipe->reader();

            # In Plack::Util::foreach(), input is buffered at 65536
            # bytes We want to buffer each line only.  So we make our
            # own input handle with $/ set accordingly.

            my $getline   = sub { local $/ = "\n"; $reader->getline };
            my $io_handle = io_from_getline( $getline );
            my $headers   = ['Content-Type' => 'text/plain'];

            # TODO: Need to figure out how to communicate a failure
            # once we've started the stream.

            $response  = sub {$_[0]->( [200, $headers, $io_handle] )};
        }
    };

    return $response;
}

#-----------------------------------------------------------------------------

sub _splat_response {
    my ($self, $action, %params) = @_;

    my $buffer   = '';
    my $out      = IO::String->new( \$buffer );
    my $result   = $self->_run_pinto($out, $action, %params);
    my $status   = $result->is_success() ? 200 : 500;
    my $response = Plack::Response->new($status, undef, $buffer);
    $response->content_length(length $buffer);

    return $response;
}

#-----------------------------------------------------------------------------

sub _error_response {
    my ($self, $code, $message) = @_;

    $code    ||= 500;
    $message ||= 'Unkown error';

    return Plack::Response->new($code, undef, $message);
}

#-----------------------------------------------------------------------------

sub _run_pinto {
    my ($self, $action, %args) = @_;

    $args{root} = $self->root;
    $args{log_prefix} = $PINTO_SERVER_RESPONSE_LINE_PREFIX;

    print { $args{out} } "$PINTO_SERVER_RESPONSE_PROLOGUE\n";

    my $pinto = Pinto->new(%args);
    $pinto->new_batch(%args, noinit => 1);
    $pinto->add_action($action, %args);
    my $result = $pinto->run_actions();

    print { $args{out} } "$PINTO_SERVER_RESPONSE_EPILOGUE\n"
        if $result->is_success();

    return $result;
}

#-----------------------------------------------------------------------------
1;

__END__
