#!perl

use strict;
use warnings;

use Test::More;
use Plack::Test;

use FindBin;
use Path::Class;
use HTTP::Request::Common;
use Class::Load qw(load_class);

use Pinto::Tester;
use Pinto::Server;
use Pinto::Constants qw(:all);

#------------------------------------------------------------------------------
# Setup...

my $t    = Pinto::Tester->new();
my %opts = (root => $t->pinto->root());
my $app  = Pinto::Server->new(%opts)->to_app();

#------------------------------------------------------------------------------
# Tests...

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $req = GET('modules/02packages.details.txt.gz');
        my $res = $cb->($req);

        is $res->code, 200, 'Correct status code';

        is $res->header('Content-Type'), 'application/x-gzip',
            'Correct Type header';

        ok $res->header('Content-Length') > 300,
            'Reasonable Length header'; # Actual length may vary

        ok $res->header('Content-Length') < 400,
            'Reasonable Length header'; # Actual length may vary

        is $res->header('Content-Length'), length $res->content,
            'Length header matches actual length';
    };

#------------------------------------------------------------------------------

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $archive = file($FindBin::Bin, qw(data TestDist-1.0.tar.gz))->stringify;
        my $params  = {author => 'THEBARD', norecurse => 1, archive => [$archive]};
        my $req     = POST( 'action/add', Content => $params);
        my $res     = $cb->($req);

        is $res->code, 200, 'Correct status code';

        is $res->header('Content-Type'), 'text/plain', 'Correct Type header';

        like $res->content, qr{^$PINTO_SERVER_RESPONSE_PROLOGUE\n},
            'Response starts with prologue';

        like $res->content, qr{$PINTO_SERVER_RESPONSE_EPILOGUE\n$},
            'Response ends with epilogue';
    };

#------------------------------------------------------------------------------

test_psgi
    app => $app,
    client => sub {
        my $cb   = shift;
        my $req  = POST('action/list');
        my $res  = $cb->($req);

        is   $res->code, 200, 'Correct status code';

        like $res->content, qr{Foo \s+ 0.7 \s+ T/TH/THEBARD/TestDist-1.0.tar.gz}x,
            'Listing contains the Foo package';

        like $res->content, qr{Bar \s+ 0.8 \s+ T/TH/THEBARD/TestDist-1.0.tar.gz}x,
            'Listing contains the Bar package';
    };

#------------------------------------------------------------------------------

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $req = POST('action/purge', Content => {verbose => 3});
        my $res = $cb->($req);

        is   $res->code, 200, 'Correct status code';

        like $res->content, qr{Process \d+ got the lock},
            'Content includes log messages when verbose';

        my $content = $res->content;
        chomp $content;

        my @lines = split m{\n}, $content;
        ok @lines > 3, 'Got a reasonable number of lines'; # May vary

        like $_, qr{^$PINTO_SERVER_RESPONSE_LINE_PREFIX},
            'Log line starts with prefix' for @lines;
    };

#------------------------------------------------------------------------------

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $req = GET('bogus/path');
        my $res = $cb->($req);

        is   $res->code, 404, 'Correct status code';
        like $res->content, qr{not found}i, 'File not found message';
    };

#------------------------------------------------------------------------------

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $req = POST('action/bogus');
        my $res = $cb->($req);

        my $content = $res->content;

        like   $content, qr{Can't locate Pinto/Action/Bogus.pm}i,
            'Got an error message';

        like   $content, qr{^$PINTO_SERVER_RESPONSE_PROLOGUE\n},
            'Response starts with prologue';

        unlike $content, qr{$PINTO_SERVER_RESPONSE_EPILOGUE\n$},
            'Error response does not end with epilogue';
    };

#------------------------------------------------------------------------------

done_testing();







