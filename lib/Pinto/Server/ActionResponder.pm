# ABSTRACT: Base class for responding to Action requests

package Pinto::Server::ActionResponder;

use Moose;

use Carp;
use Try::Tiny;

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

Given an action name and a hash of arguments for L<Pinto> runs the
action and writes the output to the output handle.  This method takes
care of adding the prologue and epilogue to the output.  Returns a
true value if the action was entirely successful.

=cut

sub run_pinto {
    my ($self, $action, $out, %args) = @_;

    $args{root} = $self->root;
    $args{log_prefix} = $PINTO_SERVER_RESPONSE_LINE_PREFIX;

    print { $out } "$PINTO_SERVER_RESPONSE_PROLOGUE\n";

    my $result;
    try   {
        my $pinto = Pinto->new(%args);
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

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------
1;

__END__

=pod

=for stopwords params

=cut

