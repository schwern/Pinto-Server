#!perl

use strict;
use warnings;

use Test::More;
use Pinto::Server::Routes;
use Dancer::Test;

route_exists( [POST => '/action/add'] );
route_exists( [POST => '/action/list'] );
route_exists( [POST => '/action/remove'] );
route_exists( [POST => '/action/nop'] );
route_exists( [POST => '/action/pin'] );
route_exists( [POST => '/action/unpin'] );
route_exists( [POST => '/action/statistics'] );

route_exists( [GET  => '/modules/something'] );
route_exists( [GET  => '/authors/id/'] );

response_status_is( [GET => '/config'], 404 );
response_status_is( [GET => '/bogus'], 404 );
response_status_is( [GET => '/'], 200 );

#-----------------------------------------------------------------------------

done_testing();
