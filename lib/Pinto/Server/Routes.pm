package Pinto::Server::Routes;                      ## no critic qw(Complexity)

# ABSTRACT: Dancer routes for a Pinto::Server

use strict;
use warnings;

use Pinto;
use Path::Class;
use File::Temp;
use Dancer qw(:syntax);

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------

=method pinto

Returns a new L<Pinto> object that is configured for this Server.

=cut

sub pinto { return Pinto->new(root_dir => setting('repos'), quiet => 1) }

#----------------------------------------------------------------------------

post '/action/add' => sub {

    my $author = param('author')
      or (status 500 and return 'No author supplied');

    my $archive = upload('archive')
      or (status 500 and return 'No archive supplied');

    # TODO: if $archive is a url, don't copy.  Just
    # pass it through and let Pinto fetch it for us.
    my $tempdir = dir( File::Temp::tempdir(CLEANUP=>1) );
    my $temp_archive = $tempdir->file( $archive->basename() );
    $archive->copy_to( $temp_archive );

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1, _get_batch_args());
    $pinto->add_action('Add', archive => $temp_archive, author => $author);
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return if $result->is_success();
    status 500 and return $result->to_string();

};

#----------------------------------------------------------------------------

post '/action/remove' => sub {

    my $author  = param('author')
      or (status 500 and return 'No author supplied');

    my $path = param('path')
      or ( status 500 and return 'No path supplied');

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1, _get_batch_args());
    $pinto->add_action('Remove', path => $path, author => $author);
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return if $result->is_success();
    status 500 and return $result->to_string();
};

#----------------------------------------------------------------------------

post '/action/list' => sub {

    my %args             = (out => \my $buffer);
    $args{format}        = param('format') if param('format');
    $args{packages}      = param('packages') if param('packages');
    $args{distributions} = param('distributions') if param('distributions');

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1);
    $pinto->add_action('List', %args);
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return $buffer if $result->is_success();
    status 500 and return $result->to_string;
};

#----------------------------------------------------------------------------

post '/action/nop' => sub {

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1);
    $pinto->add_action('Nop');
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return if $result->is_success();
    status 500 and return $result->to_string;
};

#----------------------------------------------------------------------------

post '/action/pin' => sub {

    my $pkg = param('package')
      or ( status 500 and return 'No package supplied');

    my $ver = param('version') || 0;

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1, _get_batch_args());
    $pinto->add_action('Pin', package => $pkg, version => $ver);
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return if $result->is_success();
    status 500 and return $result->to_string;
};

#----------------------------------------------------------------------------

post '/action/unpin' => sub {

    my $pkg = param('package')
      or ( status 500 and return 'No package supplied');

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1);
    $pinto->add_action('Unpin', package => $pkg);
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return if $result->is_success();
    status 500 and return $result->to_string;
};

#----------------------------------------------------------------------------

post '/action/statistics' => sub {

    my $buffer = '';
    my $format = param('format');
    my @format = $format ? (format => $format) : ();

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1);
    $pinto->add_action('Statistics', @format, out => \$buffer);
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return $buffer if $result->is_success();
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
    return sprintf 'Pinto::Server %s OK', __PACKAGE__->VERSION();
};

#-----------------------------------------------------------------------------
# Fallback route

any qr{ .* }x => sub {
    status 404;
    return 'Not found';
};

#----------------------------------------------------------------------------

sub _get_batch_args {

    my %args;
    $args{message} = param('message') if param('message');
    $args{tag}     = param('tag')     if param('tag');

    return %args;
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

