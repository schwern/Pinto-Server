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

override respond => sub {
    my ($self) = @_;

    my $buffer   = '';
    my $out      = IO::String->new( \$buffer );

    $self->run_pinto($out);
    my $response = Plack::Response->new(200, undef, $buffer);
    $response->content_length(length $buffer);
    $response->content_type('text/plain');

    return $response->finalize;
};

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------
1;

__END__
