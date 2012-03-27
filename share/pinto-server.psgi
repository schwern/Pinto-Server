# vim: set ft=perl :

use strict;
use warnings;

use Plack::Builder;
use Pinto::Server;
use Class::Load 'load_class';
use YAML::Any 'LoadFile';

#-----------------------------------------------------------------------------
# this file belongs to the Pinto-Server distribution
# VERSION

#-----------------------------------------------------------------------------

# get opts out of the config file.
my $opts = LoadFile($ENV{PINTO_SERVER_CONFIGFILE});
unlink $ENV{PINTO_SERVER_CONFIGFILE};

my $app = sub {
    my $env = shift;

    my $server = Pinto::Server->new(%$opts);
    $server->run($env);
};

builder {

    if (exists $opts->{auth})
    {
        my %auth_options = %{$opts->{auth}};

        my $backend = delete $auth_options{backend} or die 'No auth backend provided!';
        print "Authenticating using the $backend backend...\n";
        my $class = 'Authen::Simple::' . $backend;
        load_class $class;

        enable 'Auth::Basic', authenticator => $class->new(%auth_options);
    }

    $app;
};

