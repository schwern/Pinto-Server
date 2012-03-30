#!perl

use strict;
use warnings;

use Test::More;
use Pinto::Server::Tester;

#------------------------------------------------------------------------------------
# Not really testing the tester here, just exercising it

my $t = Pinto::Server::Tester->new();

$t->start_server();
$t->server_running_ok();

my $get_resp = $t->send_request(GET => 'modules/02packages.details.txt.gz');
is $get_resp->code, 200, 'GET-ing 02packages.details.txt.gz succeeded'
   or diag "Response content is: \n " . $get_resp->content();

my $post_resp = $t->send_request(POST => 'action/list');
is $post_resp->code, 200, 'POST-ing action/list'
   or diag "Response content is: \n" . $post_resp->content();

$t->kill_server();
$t->server_not_running_ok();

#------------------------------------------------------------------------------------

done_testing();
