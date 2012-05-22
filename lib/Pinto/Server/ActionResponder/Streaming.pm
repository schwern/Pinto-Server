# ABSTRACT: An ActionResponder that returns a streaming response

package Pinto::Server::ActionResponder::Streaming;

use Moose;

use IO::Pipe;
use Proc::Fork;
use IO::Handle::Util qw(io_from_getline);

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

extends qw(Pinto::Server::ActionResponder);

#------------------------------------------------------------------------------

override respond => sub {
    my ($self, %args) = @_;

    my $action_name = $args{action};
    my $action_args = $args{params};;

    # Here's what's going on: Open a pipe (which has two endpoints),
    # and then fork.  The child process runs the Action and writes all
    # output to one end of the pipe.  Meanwhile, the parent reads
    # input from the other end of the pipe and spits it into the
    # response via callback.

    my $response;
    my $pipe = IO::Pipe->new();

    run_fork {
        child {
            my $writer = $pipe->writer();
            $writer->autoflush(1);
            $action_args->{out} = $writer;
            my $success = $self->run_pinto($action_name, $writer, $action_args);
            exit $success ? 0 : 1;
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
};

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------
1;

__END__
