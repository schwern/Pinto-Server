#!perl

use strict;
use warnings;

use FindBin;
use Path::Class;

use Test::More;
use Pinto::Server::Tester;

#------------------------------------------------------------------------------
# Setup...

my $t = Pinto::Server::Tester->new();
$t->start_server();
$t->server_running_ok();

#------------------------------------------------------------------------------
# Meat...

{
    my $res = $t->send_request( GET => 'modules/02packages.details.txt.gz' );
    is $res->header('Content-Type'), 'application/x-gzip', 'Correct Type header';
    ok $res->header('Content-Length') > 300, 'Reasonable Length header'; # May vary
    ok $res->header('Content-Length') < 400, 'Reasonable Length header'; # May vary
    is $res->code, 200, 'Correct status code';
}

#------------------------------------------------------------------------------

{
    my $archive = file($FindBin::Bin, qw(data TestDist-1.0.tar.gz))->stringify;
    my %params  = (Content => {author => 'THEBARD', norecurse => 1, archive => [$archive]} );
    my $res = $t->send_request( POST => 'action/add', %params );
    is $res->header('Content-Type'), 'text/plain', 'Correct Type header';
    is $res->code, 200, 'Correct status code';
}

#------------------------------------------------------------------------------

{
    my $res = $t->send_request( POST => 'action/list' );
    is   $res->code, 200, 'Correct status code';

    like $res->content, qr{Foo \s+ 0.7 \s+ T/TH/THEBARD/TestDist-1.0.tar.gz}x,
        'Listing contains the Foo package';

    like $res->content, qr{Bar \s+ 0.8 \s+ T/TH/THEBARD/TestDist-1.0.tar.gz}x,
        'Listing contains the Bar package';
}

#------------------------------------------------------------------------------

{
    my %params = (Content => {verbose => 3});
    my $res = $t->send_request( POST => 'action/purge', %params );
    is   $res->code, 200, 'Correct status code';

    like $res->content, qr{Process \d+ got the lock},
        'Content includes log messages when verbose';
}

#------------------------------------------------------------------------------

{
    my $res = $t->send_request( GET => 'bogus/path' );
    is   $res->code, 404, 'Correct status code';
    like $res->content, qr{not found}i, 'File not found message';
}

#------------------------------------------------------------------------------

#{

    # TODO: Make sure we get a failed status when streaming and an error occurs.
    # my $res = $t->send_request( POST => 'action/bogus' );
    # is   $res->code, 500, 'Correct status code';
    # like $res->content, qr{Can't locate Pinto/Action/Bogus.pm}i, 'Got an error message';
#}

#------------------------------------------------------------------------------
# Teardown...

$t->kill_server();
$t->server_not_running_ok();

#------------------------------------------------------------------------------

done_testing();


