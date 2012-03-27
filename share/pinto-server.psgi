# vim: set ft=perl :

use strict;
use warnings;

use Pinto::Server;
use YAML::Any 'LoadFile';

#-----------------------------------------------------------------------------
# this file belongs to the Pinto-Server distribution
# VERSION

#-----------------------------------------------------------------------------

# get opts out of the config file.
my $opts = LoadFile($ENV{PINTO_SERVER_CONFIGFILE});
unlink $ENV{PINTO_SERVER_CONFIGFILE};

my $server = Pinto::Server->new(%$opts);
my $app = $server->to_app;


