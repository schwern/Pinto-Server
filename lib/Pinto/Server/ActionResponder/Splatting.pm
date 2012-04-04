# ABSTRACT: An ActionResponder that returns the entire response in one shot

package Pinto::Server::ActionResponder::Splatting;

use Moose;

use IO::String;
use Plack::Response;

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

extends qw(Pinto::Server::ActionResponder);

#------------------------------------------------------------------------------

sub respond {
    my ($self, %args) = @_;

    my $action = $args{action};
    my %params = %{ $args{params} };

    my $buffer   = '';
    my $out      = IO::String->new( \$buffer );
    my $result   = $self->_run_pinto($out, $action, %params);
    my $status   = $result->is_success() ? 200 : 500;
    my $response = Plack::Response->new($status, undef, $buffer);
    $response->content_length(length $buffer);
    $response->content_type('text/plain');

    return $response->finalize();
}

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------
1;

__END__
