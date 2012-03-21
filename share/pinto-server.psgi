# vim: set ft=perl :

use strict;
use warnings;

use Plack::Builder;
use Pinto::Server;
use Class::Load 'load_class';

my $app = sub {
    my $env = shift;

    # get opts out of %ENV.  This is kinda gross, but the PSGI specs say that
    # @ARGV is no longer available in the $app.
    my %opts = %{$ENV{PINTO_SERVER_OPTS}};

    Pinto::Server->new(%opts)->run($env);
};

builder {

    if (exists $ENV{PINTO_SERVER_OPTS}{auth})
    {
        my %auth_options = %{$ENV{PINTO_SERVER_OPTS}{auth}};

        my $backend = delete $auth_options{backend} or die 'No auth backend provided!';
        print "Authenticating using the $backend backend...\n";
        my $class = 'Authen::Simple::' . $backend;
        load_class $class;

        enable 'Auth::Basic', authenticator => $class->new(%auth_options);
    }

    $app;
};

