# ABSTRACT: Responder for action requests

package Pinto::Server::Responder::Action;

use Moose;

use Carp;
use JSON;
use IO::Pipe;
use Try::Tiny;
use File::Temp;
use File::Copy;
use Proc::Fork;
use Path::Class;
use Plack::Response;
use Log::Dispatch::Handle;
use IO::Handle::Util qw(io_from_getline);
use POSIX qw(WNOHANG);

use Pinto 0.066;
use Pinto::Result 0.066;
use Pinto::Constants 0.066;
use Pinto::Chrome::Term 0.066;
use Pinto::Constants qw(:server);

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

            # I'm not sure why, but cleanup isn't happening when we get
            # a TERM signal from the parent process.  I suspect it
            # has something to do with File::NFSLock messing with %SIG
            local $SIG{TERM} = sub { File::Temp::cleanup; exit };

            # We don't yet have a way to interactively compose the commit
            # message over the wire.  So we just pretend that we are not
            # interactive so Pinto will use the given (or default) message.
            local $Pinto::Globals::is_interactive = 0;  ## no critic qw(PackageVar)

            print { $writer } "$PINTO_SERVER_RESPONSE_PROLOGUE\n";

            my %chrome_args = (%{$pinto_args}, stdout => $writer, stderr => $writer);
            my $chrome = Pinto::Chrome::Term->new(%chrome_args);
            my $pinto  = Pinto->new(chrome => $chrome, root => $self->root);

            my $result =
                try   { $pinto->run(ucfirst $action_name => %{ $action_args }) }
                catch { print { $writer } $_; Pinto::Result->new->failed };

            print { $writer } "$PINTO_SERVER_RESPONSE_EPILOGUE\n" if $result->was_successful;
            exit $result->was_successful ? 0 : 1;
        }
        parent {

            my $child_pid = shift;
            my $reader    = $pipe->reader;

            # If the client aborts (usually by hitting Ctrl-C) then we
            # get a PIPE signal.  That is our cue to stop the Action
            # by killing the child.  TODO: Find a way to set these
            # signal handlers locally, rather than globally.  This is
            # tricky because we return a callback, which might not
            # always be in the callback when we get the signal.

            ## no critic qw(RequireLocalizedPunctuationVars)
            $SIG{PIPE} = sub { kill 'TERM', $child_pid };
            $SIG{CHLD} = 'IGNORE';
            ## use critic

            # In Plack::Util::foreach(), input is buffered at 65536
            # bytes. We want to buffer each line only.  So we make our
            # own input handle with $/ set accordingly.

            my $getline   = sub { local $/ = "\n"; $reader->getline };
            my $io_handle = io_from_getline( $getline );

            $response  = sub {
                my $responder = shift;
                my $headers = ['Content-Type' => 'text/plain'];
                return $responder->( [200, $headers, $io_handle] );
            };
        }
        error {

            croak "Failed to fork: $!";
        }
    };

    return $response;
 }

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-------------------------------------------------------------------------------

1;
