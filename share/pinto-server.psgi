#!/usr/bin/env perl

use Pinto::Server;

my $server = Pinto::Server->new(root => 'TEST');
my $app = sub { $server->engine->run(@_) };

#------------------------------------------------------------------------------

