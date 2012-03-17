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

sub pinto { return Pinto->new(root => setting('root'), quiet => 1) }

#----------------------------------------------------------------------------

post '/action/add' => sub {

    my $params = params();

    status 500 and return 'No author supplied'
        if not $params->{author};

    status 500 and return 'No archive supplied'
        if not my $archive = upload('archive');


    # TODO: if $archive is a url, don't copy.  Just
    # pass it through and let Pinto fetch it for us.
    my $temp_dir = File::Temp->newdir(); # Deleted on DESTROY
    my $temp_archive = file( $temp_dir, $archive->basename() );
    $archive->copy_to( $temp_archive );
    $params->{archive} = $temp_archive;

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1, _get_batch_args());
    $pinto->add_action('Add', %{ $params } );
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return if $result->is_success();
    status 500 and return $result->to_string();

};

#----------------------------------------------------------------------------

post '/action/remove' => sub {

    my $params = params();

    status 500 and return 'No author supplied'
        if not $params->{author};

    status 500 and return 'No path supplied'
        if not $params->{path};

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1, _get_batch_args());
    $pinto->add_action('Remove', %{ $params } );
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return if $result->is_success();
    status 500 and return $result->to_string();
};

#----------------------------------------------------------------------------

post '/action/list' => sub {

    my $pkgs  = param('packages');
    my $dists = param('distributions');

    status 500 and return 'Cannot supply packages and distributions together'
       if $pkgs and $dists;

    my %args             = (out => \my $buffer);
    $args{format}        = param('format')  if param('format');
    $args{where}->{name} = {like => "%$pkgs%"}  if $pkgs;
    $args{where}->{path} = {like => "%$dists%"} if $dists;

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

    my $params = params();

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1);
    $pinto->add_action('Nop', %{ $params } );
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return if $result->is_success();
    status 500 and return $result->to_string;
};

#----------------------------------------------------------------------------

post '/action/pin' => sub {

    my $params = params();

    status 500 and return 'No package supplied'
        if not $params->{package};

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1, _get_batch_args());
    $pinto->add_action('Pin', %{ $params } );
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return if $result->is_success();
    status 500 and return $result->to_string;
};

#----------------------------------------------------------------------------

post '/action/unpin' => sub {

    my $params = params();

    status 500 and return 'No package supplied'
        if not $params->{package};

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1);
    $pinto->add_action('Unpin', %{ $params } );
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return if $result->is_success();
    status 500 and return $result->to_string;
};

#----------------------------------------------------------------------------

post '/action/statistics' => sub {

    my $buffer = '';
    my $params = params();
    $params->{out} = \$buffer;

    my $pinto = pinto();
    $pinto->new_batch(noinit => 1);
    $pinto->add_action('Statistics', %{ $params } );
    my $result = eval { $pinto->run_actions() };

    status 500 and return $@ if $@;
    status 200 and return $buffer if $result->is_success();
    status 500 and return $result->to_string;
};

#----------------------------------------------------------------------------
# Route for indexes and dists

get qr{^ /(authors|modules)/(.+) }x => sub {
     my $file =  file( setting('root'), request->uri() );
     status 404 and return "Not found\n" if not -e $file;
     return send_file( $file, system_path => 1 );
};

#----------------------------------------------------------------------------
# Ping route

get '/' => sub {
    status 200;
    return sprintf "Pinto::Server %s OK\n", __PACKAGE__->VERSION();
};

#-----------------------------------------------------------------------------
# Unknown actions.

post qr{ /action/.* }x => sub {

    status 500;
    my $vers     = __PACKAGE__->VERSION();
    my ($action) = (request->path() =~ m{ action/(.*)/? }mx);

    return "Action '$action' is not supported by Pinto::Server version $vers\n";
};

#-----------------------------------------------------------------------------
# Everything else.

any qr{ .* }x => sub {

    status 404;
    return 'Not Found';
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

