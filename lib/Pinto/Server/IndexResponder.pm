# ABSTRACT: Responds to requests for a repository index

package Pinto::Server::IndexResponder;

use Moose;
use MooseX::Types::Moose qw(Undef);

use File::Temp;
use Path::Class;

use Pinto;
use Pinto::Types qw(Dir StackName);

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


=attr stack => $stack_name

The name of the stack whose index will be transmitted in the response.
If not specified, it defaults to the stack that is currently marked as
the default stack.

=cut

has stack  => (
   is       => 'ro',
   isa      => Undef | StackName,  ## no critic qw(Bitwise)
   coerce   => 1,
);

#------------------------------------------------------------------------------

=method respond

Returns a PSGI-compatible response containing the index for the stack.

=cut

sub respond {
    my ($self) = @_;

    my $temp_fh   = File::Temp->new;
    my $temp_file = file($temp_fh->filename);
    my $pinto     = Pinto->new(root => $self->root);
    my $stack     = $pinto->repos->get_stack(name => $self->stack);

    $pinto->repos->write_index(stack => $stack,
                               file  => $temp_file);

    my $response = Plack::Response->new;
    $response->content_type( 'application/x-gzip' );
    $response->content_length( -s $temp_file );
    $response->body( $temp_fh );
    $response->status(200);

    return $response;
}

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------
1;

__END__

=pod

=for stopwords

=cut

