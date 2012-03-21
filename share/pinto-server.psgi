# vim: set ft=perl :

use strict;
use warnings;

use Plack::Builder;
use Pinto::Server;

my $app = sub {
    my $env = shift;

    # get opts out of %ENV.  This is kinda gross, but the PSGI specs say that
    # @ARGV is no longer available in the $app.
    my %opts = %{$ENV{PINTO_SERVER_OPTS}};

    Pinto::Server->new(%opts)->run($env);
};

builder {

    # TODO: add middleware here - from $ENV{PINTO_SERVER_OPTS} as needed.
    $app;
};

