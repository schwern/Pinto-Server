# ABSTRACT: Base class for responding to Action requests

package Pinto::Server::ActionResponder;

use Moose;
use MooseX::Types::Moose qw(Str HashRef);

use Carp;
use Try::Tiny;
use List::Util qw(min);

use Log::Dispatch::Handle;

use Pinto;
use Pinto::Result;
use Pinto::Types qw(Dir);
use Pinto::Constants qw(:all);

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

=attr root => $directory

The root directory of your L<Pinto> repository.  This attribute is
required.

=cut

has root  => (
   is       => 'ro',
   isa      => Dir,
   required => 1,
   coerce   => 1,
);


has action => (
   is        => 'ro',
   isa       => Str,
   required  => 1,
);


has args => (
    is     => 'ro',
    isa    => HashRef,
    default => sub { {} },
);

#-----------------------------------------------------------------------------

=method respond( action => $action_name, params => \%params );

Given a Pinto Action name and a hash reference request parameters,
performs the Action and returns a PSGI-compatible response.  This is
an abstract method that you must implement in a subclass.

=cut

sub respond { confess 'Abstract method' };

#-----------------------------------------------------------------------------

=method run_pinto( $action_name, $output_handle, $args )

Given an Action name and a hash of arguments for L<Pinto>, runs the
Action.  Any output and log messages from the Action will be written
to the output handle.  This method takes care of adding the prologue
and epilogue to the output handle.  Returns a true value if the action
was entirely successful.

=cut

sub run_pinto {
    my ($self, $output_handle) = @_;

    my $args = $self->args;
    $args->{root} ||= $self->root;
    $args->{out} = $output_handle;

    print { $output_handle } "$PINTO_SERVER_RESPONSE_PROLOGUE\n";

    my $result;
    try   {
        my $pinto = Pinto->new($args);
        $pinto->add_logger($self->_make_logger($output_handle));
        $result = $pinto->run($self->action => %{ $args });
    }
    catch {
        print $_;
        print { $output_handle } $_;
        $result = Pinto::Result->new->failed;
    };

    print { $output_handle } "$PINTO_SERVER_RESPONSE_EPILOGUE\n"
        if $result->was_successful;

    return $result->was_successful;
}

#------------------------------------------------------------------------------

sub _make_logger {
    my ($self, $out) = @_;

    # Prepend all server log messages with a prefix so clients can
    # distiguish log messages from regular output from the Action.

    my $cb = sub {
        my %args = @_;
        my $level = uc $args{level};
        chomp (my $msg = $args{message});
        my @lines = split m{\n}x, $msg;
        $msg = join "\n" . $PINTO_SERVER_RESPONSE_LINE_PREFIX, @lines;
        return $PINTO_SERVER_RESPONSE_LINE_PREFIX . "$level: $msg" . "\n";
    };

    # We're going to send all log messages to the client and let
    # it decide which ones it wants to record or display.

    my $logger = Log::Dispatch::Handle->new( min_level => 0,
                                             handle    => $out,
                                             callbacks => $cb );

    return $logger;
}

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------
1;

__END__

=pod

=for stopwords params

=cut

