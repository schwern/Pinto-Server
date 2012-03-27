package Pinto::Server;

# ABSTRACT: Web interface to a Pinto repository

use Moose;

use Pinto::Types qw(Dir);
use Pinto::Server::Routes;

use Dancer qw(:moose :script);

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------

=attr root

The path to the root directory of your Pinto repository.  The
repository must already exist at this location.  This attribute is
required.

=cut

has root => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    required => 1,
);

#-----------------------------------------------------------------------------

=method run()

Starts the Pinto::Server.  Returns a PSGI-compatible code reference.

=cut

sub run {
    my ($self, $env) = @_;

    my $request = Dancer::Request->new(env => $env);
    Dancer->dance($request);
}

#-----------------------------------------------------------------------------

sub BUILD
{
    my ($self) = @_;
    $self->_initialize;
}

sub _initialize {
    my ($self) = @_;

    Dancer::set( root   => $self->root()  );

    ## no critic qw(Carping)

    my $root = $self->root();
    print "Initializing pinto repository at '$root' ... ";
    my $pinto = eval { Pinto::Server::Routes::pinto() };
    print "\n" and die "$@" if not $pinto;

    $pinto->new_batch(noinit => 0);
    $pinto->add_action('Nop');

    my $result = $pinto->run_actions();
    print "\n" and die $result->to_string() . "\n" if not $result->is_success();

    print "Done\n";

    return $self;
}

#----------------------------------------------------------------------------

1;

__END__

=head1 DESCRIPTION

There is nothing to see here.

Look at L<pinto-server> instead.

Then you'll probably want to look at L<pinto-remote>.

See L<Pinto::Manual> for a complete guide.

=cut

