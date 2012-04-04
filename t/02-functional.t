#!perl

use strict;
use warnings;

use FindBin;
use Path::Class;
use Class::Load qw(load_class);

use Test::More;
use Pinto::Server::Tester;

use Pinto::Constants qw(:all);

#------------------------------------------------------------------------------

my @BACKENDS = ($ENV{AUTHOR_TESTING} or $ENV{RELEASE_TESTING}) ?
    qw(Starman Twiggy Corona Feersum Starlet) : ();

#------------------------------------------------------------------------------
# Setup...

START:
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
    my $res  = $t->send_request( POST => 'action/add', %params );
    my $body = $res->content;


    is $res->code, 200, 'Correct status code';
    is $res->header('Content-Type'), 'text/plain', 'Correct Type header';

    like $body, qr{^$PINTO_SERVER_RESPONSE_PROLOGUE\n}, 'Response starts with prologue';
    like $body, qr{$PINTO_SERVER_RESPONSE_EPILOGUE\n$}, 'Response ends with epilogue';
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
    my $res  = $t->send_request( POST => 'action/purge', %params );
    my $body = $res->content;

    is   $res->code, 200, 'Correct status code';
    like $body, qr{Process \d+ got the lock}, 'Content includes log messages when verbose';


    chomp $body;
    my @lines = split m{\n}, $body;
    ok @lines > 3, 'Got a reasonable number of lines'; # May vary
    $DB::single = 1;
    like $_, qr{^$PINTO_SERVER_RESPONSE_LINE_PREFIX}, 'Log line starts with prefix' for @lines;
}

#------------------------------------------------------------------------------

{
    my $res = $t->send_request( GET => 'bogus/path' );
    is   $res->code, 404, 'Correct status code';
    like $res->content, qr{not found}i, 'File not found message';
}

#------------------------------------------------------------------------------

{
    # TODO: Make sure we get a failed status when streaming and an error occurs.
    my $res = $t->send_request( POST => 'action/bogus' );
    my $body = $res->content;

    like   $body, qr{Can't locate Pinto/Action/Bogus.pm}i, 'Got an error message';
    like   $body, qr{^$PINTO_SERVER_RESPONSE_PROLOGUE\n}, 'Response starts with prologue';
    unlike $body, qr{$PINTO_SERVER_RESPONSE_EPILOGUE\n$}, 'Error response does not end with epilogue';
}

#------------------------------------------------------------------------------
# Teardown...

$t->kill_server();
$t->server_not_running_ok();

#------------------------------------------------------------------------------
# Repeat the entire test for various backends we know of

while (my $backend = shift @BACKENDS) {
    eval { load_class($backend) } or next;
    diag "Now testing on $backend";
    $ENV{PLACK_SERVER} = $backend;
    goto START;
}


#------------------------------------------------------------------------------

done_testing();


