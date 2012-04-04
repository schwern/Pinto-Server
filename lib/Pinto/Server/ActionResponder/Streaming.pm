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

sub respond {
    my ($self, %args) = @_;

    my $action = $args{action};
    my %params = %{ $args{params} };

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
            my $result = $self->run_pinto($action, %params);
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

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------
1;

__END__
