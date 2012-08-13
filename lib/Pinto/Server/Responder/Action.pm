# ABSTRACT: Responder for Actions

package Pinto::Server::Responder::Action;

use Moose;

use JSON;
use POSIX;
use IO::Pipe;
use Try::Tiny;
use File::Temp;
use File::Copy;
use Proc::Fork;
use Path::Class;
use Plack::Response;
use Log::Dispatch::Handle;
use IO::Handle::Util qw(io_from_getline);

use Pinto;
use Pinto::Result;
use Pinto::Constants qw(:all);

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

extends qw(Pinto::Server::Responder);

#-------------------------------------------------------------------------------

sub respond {
    my ($self) = @_;

    # path_info always has a leading slash, e.g. /action/list
    my (undef, undef, $action_name) = split '/', $self->request->path_info;

    my %params      = %{ $self->request->parameters }; # Copying
    my $pinto_args  = $params{pinto_args}  ? decode_json( $params{pinto_args} ) : {};
    my $action_args = $params{action_args} ? decode_json( $params{action_args} ) : {};

    for my $upload_name ( $self->request->uploads->keys ) {
        my $upload    = $self->request->uploads->{$upload_name};
        my $basename  = $upload->filename;
        my $localfile = file($upload->path)->dir->file($basename);
        File::Copy::move($upload->path, $localfile); #TODO: autodie
        $action_args->{$upload_name} = $localfile;
    }

    return $self->_run_action($pinto_args, $action_name, $action_args);
}

#------------------------------------------------------------------------------

sub _run_action {
    my ($self, $pinto_args, $action_name, $action_args) = @_;

    my $response;
    my $pipe = IO::Pipe->new;

    run_fork {

        child {

            my $writer = $pipe->writer;
            $action_args->{out} ||= $writer;

            print { $writer } "$PINTO_SERVER_RESPONSE_PROLOGUE\n";
            my $pinto = Pinto->new(%{$pinto_args}, root => $self->root);
            my $logger = $self->_make_logger($pinto_args->{log_level}, $writer);
            $pinto->add_logger($logger);

            my $result =
                try   { $pinto->run(ucfirst $action_name => %{ $action_args }) }
                catch { print { $writer } $_; Pinto::Result->new->failed };

            print { $writer } "$PINTO_SERVER_RESPONSE_EPILOGUE\n" if $result->was_successful;
            exit $result->was_successful ? 0 : 1;
        }
        parent {

            my $child_pid = shift;
            my $reader    = $pipe->reader;

            # In Plack::Util::foreach(), input is buffered at 65536
            # bytes. We want to buffer each line only.  So we make our
            # own input handle with $/ set accordingly.

            my $getline   = sub { local $/ = "\n"; $reader->getline };
            my $io_handle = io_from_getline( $getline );

            # If the parent looses the connection (usually because the
            # client at the other end was killed by Ctrl-C) then we
            # will get a SIGPIPE.  At that point, we need to kill the
            # child.  Not sure if parent should die too.

            $response  = sub {
                my $responder = shift;
                waitpid $child_pid, WNOHANG;
                local $SIG{PIPE} = sub { kill 2, $child_pid };
                my $headers = ['Content-Type' => 'text/plain'];
                return $responder->( [200, $headers, $io_handle] );
            };
        }
        error {

            die "Failed to fork: $!";
        }
    };

    return $response;
 }

#-------------------------------------------------------------------------------

sub _make_logger {
    my ($self, $log_level, $output_handle) = @_;

    # This callback prepends the special token "## LEVEL:" to each log
    # message, so that clients can distinguish log messages from
    # regular output, and re-log the message accordingly.

    my $cb = sub {
        my %args = @_;
        my $level = uc $args{level};
        chomp (my $msg = $args{message});
        $msg =~ s{\n}{\n\Q$PINTO_SERVER_RESPONSE_LINE_PREFIX$level: \E}xg;
        return $PINTO_SERVER_RESPONSE_LINE_PREFIX . "$level: $msg" . "\n";
    };


    # The log_level could be a number (0-6) or a string (e.g. debug,
    # warn, etc.) so we must be prepared for either one.

    $log_level = 'warning' if not defined $log_level;

    return Log::Dispatch::Handle->new( name      => 'server',
                                       handle    => $output_handle,
                                       min_level => $log_level,
                                       callback  => $cb,
                                       newline   => 1, );
}


#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-------------------------------------------------------------------------------

1;
