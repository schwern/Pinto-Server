# ABSTRACT: Base class for responding to Action requests

package Pinto::Server::ActionResponder;

use Moose;

use Carp;
use Try::Tiny;
use List::Util qw(max);

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

#-----------------------------------------------------------------------------

=method respond( action => $action_name, params => \%params );

Given an action name and a hash reference request parameters, performs
the action and returns a PSGI-compatible response.  This is an
abstract method that you must implement in a subclass.

=cut

sub respond { confess 'Abstract method' };

#-----------------------------------------------------------------------------

=method run_pinto( $action_name, $output_handle, %pinto_args )

Given an Action name and a hash of arguments for L<Pinto>, runs the
Action and writes the output to the output handle.  This method takes
care of adding the prologue and epilogue to the output handle.  Any
output produced by the Action will be written to the output
handle. Returns a true value if the action was entirely successful.

=cut

sub run_pinto {
    my ($self, $action, $out, %args) = @_;

    $args{root} = $self->root;

    print { $out } "$PINTO_SERVER_RESPONSE_PROLOGUE\n";

    my $result;
    try   {
        my $pinto = Pinto->new(%args);
        $pinto->add_logger($self->make_logger($out, %args));
        $pinto->new_batch(%args, noinit => 1);
        $pinto->add_action($action, %args);
        $result = $pinto->run_actions();
    }
    catch {
        print { $out } $_;
        $result = Pinto::Result->new();
        $result->add_exception($_);
    };

    print { $args{out} } "$PINTO_SERVER_RESPONSE_EPILOGUE\n"
        if $result->is_success();

    return $result->is_success() ? 1 : 0;
}

#------------------------------------------------------------------------------

sub make_logger {
    my ($self, $out, %pinto_args) = @_;

    my $verbose   = $pinto_args{verbose} || 0;
    my $log_level = max(0, 2 - $verbose);    # Equivalent to 'notice'
    $log_level    = 4 if $pinto_args{quiet}; # 'error' or higher

    # TODO: Using a regex to squirt in the PREFIX might be faster
    # and more understandable that splitting and re-joining the string
    my $cb = sub { my %args = @_;
                   chomp (my $msg = $args{message});
                   my @lines = split m{\n}, $msg;
                   $msg = join $PINTO_SERVER_RESPONSE_LINE_PREFIX, @lines;
                   return $PINTO_SERVER_RESPONSE_LINE_PREFIX . $msg . "\n" };

    my $logger = Log::Dispatch::Handle->new( min_level => $log_level,
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

