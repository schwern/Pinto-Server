# ABSTRACT: Class for testing a Pinto::Server

package Pinto::Server::Tester;

use Moose;
use MooseX::NonMoose;
use MooseX::Types::Moose qw(Maybe Int);

use Carp;
use Proc::Fork;
use Path::Class;
use Plack::Runner;
use LWP::UserAgent;
use File::Temp qw(tempdir);
use POSIX qw(:sys_wait_h);
use HTTP::Request::Common;

use Pinto::Tester;
use Pinto::Server;
use Pinto::Types qw(Uri File);
use Pinto::Constants qw($PINTO_SERVER_TEST_PORT);

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------

extends qw(Test::Builder::Module);

#-----------------------------------------------------------------------------

=attr pinto_tester

A L<Pinto::Tester> object.  If you do not specify one, it will be
created for you, using a Pinto repository constructed in a temporary
directory that will be removed when the Pinto::Tester is destroyed.

=cut

has pinto_tester => (
   is      => 'ro',
   isa     => 'Pinto::Tester',
   default => sub { Pinto::Tester->new() },
   lazy    => 1,
);


=attr pinto_server

A L<Pinto::Server> object.  If you do not specify one, it will be
created for you, using the repostitory created by the C<pinto_tester>.

=cut

has pinto_server => (
   is      => 'ro',
   isa     => 'Pinto::Server',
   default => sub { Pinto::Server->new( root => $_[0]->pinto_tester->pinto->root ) },
   lazy    => 1,
);


=attr server_pid

The process ID number of the server.  This will be undefined until the
server has actually started.

=cut

has server_pid => (
    is      => 'ro',
    isa     => Maybe[Int],
    default => undef,
    writer  => '_set_server_pid',
);


=attr ua

An L<LWP::UserAgent> that will be used to send requests to the server.

=cut

has ua => (
   is       => 'ro',
   isa      => 'LWP::UserAgent',
   default  => => sub { LWP::UserAgent->new() },
   lazy     => 1,
);


=attr access_log

Path to a file where the server's access log will be written.
Defaults to a file in a temporary directory that will be removed when
this Tester object is destroyed.

=cut

has access_log => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    default  => sub { dir( tempdir(CLEANUP => 1) )->file('access_log') },
);


=method server_url

Returns a L<URI> repesenting the base address of the server.

=cut

has server_url => (
    is       => 'ro',
    isa      => Uri,
    init_arg => undef,
    default => sub { URI->new("http://localhost:$PINTO_SERVER_TEST_PORT") },
    lazy     => 1,
);


has tb => (
   is       => 'ro',
   isa      => 'Test::Builder',
   init_arg => undef,
   default  => => sub { __PACKAGE__->builder() },
);

#-----------------------------------------------------------------------------

=method start_server

Attempts to start the server in a forked process.  Throws an exception
if the fork fails.  But it is up to you to check if the server
actually started or not.

=cut

sub start_server {
    my ($self) = @_;

    run_fork {
        child {
            my $runner = Plack::Runner->new();

            my @argv = ( '--port'       => $PINTO_SERVER_TEST_PORT,
                         '--access-log' => $self->access_log);

            $runner->parse_options(@argv);

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

=method start_server

Attempts to kill the forked server process using a series increasing
C<kill> signals.

=cut

sub kill_server {
    my ($self) = @_;

    my $server_pid = $self->server_pid();

    for my $signal (2, 3, 7, 9) {

        kill $signal, $server_pid
            or confess "Failed to signal $signal to server $server_pid";

        sleep 2; # Wait a moment to shut down;

        # NOTE: This may not be very portable
        return if waitpid($server_pid, WNOHANG) != 0;
    }

    confess "Could not kill server $server_pid";
}

#-----------------------------------------------------------------------------

=method server_running_ok

Assert the server is running.

=cut

sub server_running_ok {
    my ($self) = @_;

    my $pid = $self->server_pid();
    if (not defined $pid) {
        return $self->tb->fail('Server was never started');
    }

    my $server_status = (waitpid($pid, WNOHANG) == 0 );
    return $self->tb->ok($server_status, "Server $pid is running");
}

#-----------------------------------------------------------------------------

=method server_not_running_ok

Assert the server is not running.

=cut

sub server_not_running_ok {
    my ($self) = @_;

    my $pid = $self->server_pid();
    if (not defined $pid) {
        return $self->tb->fail('Server was never started');
    }

    my $server_status = ( waitpid($pid, WNOHANG) == -1 );
    return $self->tb->ok($server_status, "Server $pid is not running");
}

#-----------------------------------------------------------------------------

=method send_request( $TYPE => @PARAMS );

Constructs an appropriate L<HTTP::Request> and sends it to the server.
Returns the corresponding L<HTTP::Response>.

The C<$TYPE> may be either 'GET' or 'POST'.  The C<@PARAMS> will be
passed to either the GET or POST methods in L<HTTP::Reqeust::Common>.

The first value in C<@PARAMS> is always the url.  Since the tester
knows the base url of the server, you do not need to specify a proper
url here, just the fragment that comes after the scheme://host:port/

=cut

sub send_request {
    my ($self, $type, @request_params) = @_;

    # We know our own url, so prepend it
    $request_params[0] = $self->server_url . '/' . $request_params[0];

    my $request  = $type eq 'GET'  ?  GET(@request_params)
                 : $type eq 'POST' ? POST(@request_params)
                 : confess "Don't know how to send $type request";

    my $response = $self->ua->request($request);
}

#-----------------------------------------------------------------------------

sub DEMOLISH {
    my ($self) = @_;

    # NOTE: This may not be very portable
    my $server_pid = $self->server_pid();
    return if waitpid($server_pid, WNOHANG) == -1;

    $self->kill_server();
}

#-----------------------------------------------------------------------------

1;

__END__
