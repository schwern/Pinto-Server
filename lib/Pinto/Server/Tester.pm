# ABSTRACT: A class for testing a Pinto server

package Pinto::Server::Tester;

use Moose;
use IPC::Run;
use Test::TCP;
use File::Which;
use Carp;

use Pinto::Types qw(File);

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

extends 'Pinto::Tester';

#-------------------------------------------------------------------------------

has server_port => (
  is         => 'ro',
  isa        => 'Int',
  default    => sub { empty_port },
);


has server_host => (
  is         => 'ro',
  isa        => 'Str',
  init_arg   => undef,
  default    => 'localhost',
);


has server_pid => (
  is         => 'rw',
  isa        => 'Int',
  init_arg   => undef,
  default    => 0,
);


has server_url => (
  is         => 'ro',
  isa        => 'Str',
  init_arg   => undef,
  default    => sub { 'http://' . $_[0]->server_host . ':' . $_[0]->server_port },
);


has pintod_exe => (
  is         => 'ro',
  isa        => File,
  default    => sub { which('pintod') || croak "Could not find pintod in PATH" },
  coerce     => 1,
);

#-------------------------------------------------------------------------------

sub start_server {
  my ($self) = @_;

  warn 'Server already started' and return if $self->server_pid;

  local $ENV{PLACK_SERVER} = '';         # Use the default backend
  local $ENV{PLACK_ENV}    = 'testing';  # Suppresses startup message

  my $server_pid = fork;
  croak "Failed to fork: $!" if not defined $server_pid;

  if ($server_pid == 0) {
    my %opts = ('--port' => $self->server_port, '--root' => $self->root);
    my @cmd = ($^X, $self->pintod_exe, %opts);
    $self->tb->note(sprintf 'exec(%s)', join ' ', @cmd);
    exec @cmd;
  }

  $self->server_pid($server_pid);
  $self->server_running_ok or croak 'Sever startup failed';
  sleep 3; # Let the server warm up


  return $self;
}

#-------------------------------------------------------------------------------

sub stop_server {
  my ($self) = @_;

  my $server_pid = $self->server_pid;
  warn 'Server was never started' and return if not $server_pid;
  warn "Server $server_pid not running" and return if not kill 0, $server_pid;

  # TODO: Consider using Proc::Terminator instead
  $self->tb->note("Shutting down server $server_pid");
  kill 'TERM', $server_pid;
  sleep 2 and waitpid $server_pid, 0;

  $self->server_not_running_ok;

  return $self;
}

#-------------------------------------------------------------------------------

sub server_running_ok {
  my ($self) = @_;

  my $server_pid  = $self->server_pid;
  my $server_port = $self->server_port;

  my $ok = kill 0, $server_pid; # Is this portable?

  return $self->tb->ok($ok, "Server $server_pid is running on port $server_port");
}

#-------------------------------------------------------------------------------

sub server_not_running_ok {
  my ($self) = @_;

  my $server_pid = $self->server_pid;
  my $ok = not kill 0, $server_pid;  # Is this portable?

  return $self->tb->ok($ok, "Server is not running with pid $server_pid");
}

#-------------------------------------------------------------------------------

sub DEMOLISH {
  my ($self) = @_;

  $self->stop_server if $self->server_pid;

  return;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-------------------------------------------------------------------------------

1;

__END__

=pod

=for stopwords responder

=for Pod::Coverage BUILD

=cut
