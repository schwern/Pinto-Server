# ABSTRACT: Responder for Actions

package Pinto::Server::Responder::Action;

use Moose;

use JSON;
use IO::Pipe;
use Try::Tiny;
use File::Temp;
use File::Copy;
use Proc::Fork;
use Path::Class;
use Plack::Response;
use IO::Handle::Util qw(io_from_getline);

use Pinto::Result;
use Pinto::Constants qw(:all);

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

extends qw(Pinto::Server::Responder);

#-------------------------------------------------------------------------------

sub respond {
    my ($self) = @_;

    # path_info always has a leading slash
    my (undef, undef, $action_name) = split '/', $self->request->path_info;

    my %params      = %{ $self->request->parameters }; # Copying
    my $action_args = $params{args} ? decode_json( $params{args} ) : {};

    for my $upload_name ( $self->request->uploads->keys ) {
        my $upload    = $self->request->uploads->{$upload_name};
        my $basename  = $upload->filename;
        my $localfile = file($upload->path)->dir->file($basename);
        File::Copy::move($upload->path, $localfile); #TODO: autodie
        $action_args->{$upload_name} = $localfile;
    }

    return $self->_run_action($action_name => $action_args);
}

#------------------------------------------------------------------------------

sub _run_action {
    my ($self, $action_name, $action_args) = @_;

    my $response;
    my $pipe = IO::Pipe->new;

    run_fork {
        child {
            my $writer = $pipe->writer;
            $action_args->{out} ||= $writer;

            print { $writer } "$PINTO_SERVER_RESPONSE_PROLOGUE\n";

            my $result =
                try   { $self->pinto->run(ucfirst $action_name => %{ $action_args }) }
                catch { print { $writer } $_; Pinto::Result->new->failed };

            print { $writer } "$PINTO_SERVER_RESPONSE_EPILOGUE\n" if $result->was_successful;
            exit $result->was_successful ? 0 : 1;
        }
        parent {
            my $child_pid = shift;
            my $reader    = $pipe->reader;

            # In Plack::Util::foreach(), input is buffered at 65536
            # bytes We want to buffer each line only.  So we make our
            # own input handle with $/ set accordingly.

            my $getline   = sub { local $/ = "\n"; $reader->getline };
            my $io_handle = io_from_getline( $getline );
            my $headers   = ['Content-Type' => 'text/plain'];

            # If the parent looses the connection (usually because the
            # client at the other end was killed by Ctrl-C) then we
            # will get a SIGPIPE.  At that point, we need to kill the
            # child.  Not sure if parent should die too.

            $response  = sub {
                my $responder = shift;
                local $SIG{PIPE} = sub { kill 2, $child_pid };
                return $responder->( [200, $headers, $io_handle] );
            };
        }
    };

    return $response;
 }

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-------------------------------------------------------------------------------

1;
