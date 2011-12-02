package Pinto::Server::Routes;                      ## no critic qw(Complexity)

# ABSTRACT: Dancer routes for a Pinto::Server

use strict;
use warnings;

use Path::Class;
use File::Temp;
use Dancer qw(:syntax);

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------

=method pinto

Returns a new L<Pinto> object that is configured for this Server.

=cut

sub pinto { return Pinto->new(repos => setting('repos'), quiet => 1) }

#----------------------------------------------------------------------------

post '/action/add' => sub {

    my $author = param('author')
      or (status 500 and return 'No author supplied');

    my $archive   = upload('archive')
      or (status 500 and return 'No archive supplied');

    # Must protect against passing an undef argument, or Moose will bitch
    my %batch_args = ( param('message') ? (message => param('message')) : (),
                       param('tag')     ? (tag     => param('tag'))     : () );

    # TODO: if $archive is a url, don't copy.  Just
    # pass it through and let Pinto fetch it for us.
    my $tempdir = dir( File::Temp::tempdir(CLEANUP=>1) );
    my $temp_archive = $tempdir->file( $archive->basename() );
    $archive->copy_to( $temp_archive );

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1, %batch_args);
    $pinto->add_action('Add', archive => $temp_archive, author => $author);
    my $result = $pinto->run_actions();

    status 200 and return if $result->is_success();
    status 500 and return $result->to_string();

};

#----------------------------------------------------------------------------

post '/action/remove' => sub {

    my $author  = param('author')
      or (status 500 and return 'No author supplied');

    my $path = param('path')
      or ( status 500 and return 'No path supplied');

    # Must protect against passing an undef argument, or Moose will bitch
    my %batch_args = ( param('message') ? (message => param('message')) : (),
                       param('tag')     ? (tag     => param('tag'))     : () );

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1, %batch_args);
    $pinto->add_action('Remove', path => $path, author => $author);
    my $result = $pinto->run_actions();

    status 200 and return if $result->is_success();
    status 500 and return $result->to_string();
};

#----------------------------------------------------------------------------

post '/action/list' => sub {

    my $buffer = '';
    my $format = param('format');
    my @format = $format ? (format => $format) : ();

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1);
    $pinto->add_action('List', @format, out => \$buffer);
    my $result = $pinto->run_actions();

    status 200 and return $buffer if $result->is_success();
    status 500 and return $result->to_string;
};

#----------------------------------------------------------------------------

post '/action/nop' => sub {

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1);
    $pinto->add_action('Nop');
    my $result = $pinto->run_actions();

    status 200 and return if $result->is_success();
    status 500 and return $result->to_string;
};

#----------------------------------------------------------------------------
# Route for indexes and dists

get qr{^ /(authors|modules)/(.+) }x => sub {
     my $file =  file( setting('repos'), request->uri() );
     status 404 and return 'Not found' if not -e $file;
     return send_file( $file, system_path => 1 );
};

#----------------------------------------------------------------------------
# Ping route

get '/' => sub {
    status 200;
    return 'Pinto OK';
};

#-----------------------------------------------------------------------------
# Fallback route

any qr{ .* }x => sub {
    status 404;
    return 'Not found';
};

#----------------------------------------------------------------------------

1;

__END__

=head1 DESCRIPTION

There is nothing to see here.

Look at L<pinto-server> instead.

Then you'll probably want to look at L<pinto-remote>.

See L<Pinto::Manual> for a complete guide.

=cut

