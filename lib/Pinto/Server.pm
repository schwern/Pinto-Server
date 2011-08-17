package Pinto::Server;

# ABSTRACT: Web interface to a Pinto repository

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Path::Class;
use File::Temp;

use Pinto;
use Pinto::Config;
use Pinto::Logger;

use Dancer ':syntax';

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------
# These are persistent variables!

my $config = Pinto::Config->new();
my $logger = Pinto::Logger->new(config => $config);
my $pinto  = Pinto->new(logger => $logger, config => $config);

#----------------------------------------------------------------------------

post '/add' => sub {

    my $author = param('author')
      or (status 500 and return 'No author supplied');

    my $dist   = upload('dist')
      or (status 500 and return 'No dist file supplied');

    my $tempdir = dir( File::Temp::tempdir(CLEANUP=>1) );
    my $dist_file = $tempdir->file( $dist->basename() );
    $dist->copy_to( $dist_file );

    eval {$pinto->add(dists => $dist_file, author => $author); 1}
        or (status 500 and return $@);

    status 200;
    return "SUCCESS\n";

};

#----------------------------------------------------------------------------

post '/remove' => sub {

    my $author  = param('author')  or return _error('No author supplied');
    my $package = param('package') or return _error('No package supplied');

    eval {$pinto->remove(packages => $package, author => $author); 1}
        or (status 500 and return $@);

    status 200;
    return "SUCCESS\n";
};

#----------------------------------------------------------------------------

post '/list' => sub {

    my $buffer = '';
    eval {$pinto->list(out => \$buffer); 1}
        or (status 500 and return $@);

    status 200;
    return $buffer;

};

#----------------------------------------------------------------------------

get '/' => sub {

    status 200;
    return "OK";
};

#----------------------------------------------------------------------------

get '/authors/**' => sub {
     my $file =  file( $config->local(), request->uri() );
     return send_file( $file, system_path => 1 );
};

#----------------------------------------------------------------------------

get '/modules/**' => sub {
     my $file =  file( $config->local(), request->uri() );
     return send_file( $file, system_path => 1 );
};

#----------------------------------------------------------------------------
1;

__END__

=head1 DESCRIPTION

You probably want to look at L<pinto-server> first.

L<Pinto::Server> is a web API to a L<Pinto> repository.  Using this
interface, remote clients (like L<pinto-remote>) can add
distributions, remove packages, and list the contents of the Pinto
repository.  In addition, L<Pinto::Server> serves the entire contents
of your repository, so you can use it as the source of distributions
for L<cpan> or L<cpanm>.

Before running L<Pinto::Server> you must first create a Pinto
repository.  See L<pinto-admin> for directions on that.  Once you have
a repository, the easiest way to run L<Pinto::Server> is like this:

  $> pinto-server [OPTIONS]

L<Pinto::Server> is also PSGI compatible, so you can run it under
L<Plack> like this:

  $> plackup [OPTIONS] /path/to/pinto-server

=head1 CONFIGURATION

L<Pinto::Server> automatically uses your L<Pinto> configuration file
which is usually at F<$HOME/.pinto/config.ini>.  Or you can set the
C<PERL_PINTO> environment variable to point to another location.

No additional configuration is required beyond what L<Pinto> itself
uses.  However, L<Pinto::Server> will always silently force the
C<nocommit> and C<noinit> parameters to 0.  Also, the C<author>
parameter is meaningless to L<Pinto::Server> because clients all
required to provide an author for any C<add> or C<remove> operations.

=head1 CAVEATS

If you are running L<Pinto::Server> and have configured Pinto to use a
VCS-based store, such as L<Pinto::Store::Svn> or L<Pinto::Store::Git>,
then you must not mess with the VCS directly (at least not the VCS
directories that Pinto is using).  This is because L<Pinto::Server>
only initializes the working copy of the Pinto repository at startup.
Thereafter, it assumes that it is the only actor that affects its part
of the VCS.  If you start

=head1 LIMITATIONS

L<Pinto::Server> speaks HTTP, but does not actually serve HTML.  At
the moment, is geared toward command-line tools like L<pinto-client>
so it just returns plain text.  This will probably change as
L<Pinto::Server> evolves into a real web application.

=cut

