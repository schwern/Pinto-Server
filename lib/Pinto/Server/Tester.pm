# ABSTRACT: Class for testing a Pinto::Server

package Pinto::Server::Tester;

use Moose;

use Carp;
use Pinto::Tester;
use Pinto::Server;
use Plack::Runner;
use Proc::Fork;
use POSIX qw(:sys_wait_h);

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------

has pinto_tester => (
   is      => 'ro',
   isa     => 'Pinto::Tester',
   default => sub { Pinto::Tester->new() },
   lazy    => 1,
);


has pinto_server => (
   is      => 'ro',
   isa     => 'Pinto::Server',
   default => sub { Pinto::Server->new( root => $_[0]->pinto_tester->pinto->root ) },
   lazy    => 1,
);


has server_pid => (
    is     => 'ro',
    isa    => 'Int',
    writer => '_set_server_pid',
);

#-----------------------------------------------------------------------------

sub start_server {
    my ($self) = @_;

    run_fork {
        child {
            my $runner = Plack::Runner->new();
            eval { $runner->run($self->pinto_server->to_app()) };
            confess "Server quit unexpectedly: $@";
        }
        parent {
            $self->_set_server_pid(shift);
            sleep 2; # Wait a moment for start up
        }
    };

    return $self;
}

#-----------------------------------------------------------------------------

sub kill_server {
    my ($self) = @_;

    my $server_pid = $self->server_pid;

    for my $signal (2, 3, 7, 9) {

        kill $signal, $server_pid
            or die "Failed to signal $signal to server $server_pid";

        sleep 2; # Wait a moment to shut down;

        return if waitpid($server_pid, WNOHANG) != 0;
    }

    confess "Could not kill server $server_pid";
}

#-----------------------------------------------------------------------------

sub DEMOLISH {
    my ($self) = @_;

    my $server_pid = $self->server_pid();
    return if waitpid($server_pid, WNOHANG) == -1;

    $self->kill_server();
}

#-----------------------------------------------------------------------------

1;

__END__
