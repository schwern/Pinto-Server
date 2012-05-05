#!perl

use strict;
use warnings;

use Test::More;
use Plack::Test;

use FindBin;
use Path::Class;
use HTTP::Request::Common;

use Pinto::Tester;
use Pinto::Server;
use Pinto::Constants qw(:all);

#------------------------------------------------------------------------------
# Setup...


my %nostream = ();

START:

my $t    = Pinto::Tester->new();
my %opts = (root => $t->pinto->root());
my $app  = Pinto::Server->new(%opts)->to_app();

#------------------------------------------------------------------------------
# Fetching a file...

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $req = GET('modules/02packages.details.txt.gz');
        my $res = $cb->($req);

        is $res->code, 200, 'Correct status code';

        is $res->header('Content-Type'), 'application/x-gzip',
            'Correct Type header';

        cmp_ok $res->header('Content-Length'), '>=', 300,
            'Reasonable Length header'; # Actual length may vary

        cmp_ok $res->header('Content-Length'), '<', 400,
            'Reasonable Length header'; # Actual length may vary

        is $res->header('Content-Length'), length $res->content,
            'Length header matches actual length';
    };

#------------------------------------------------------------------------------
# Adding an archive...

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $archive = file($FindBin::Bin, qw(data TestDist-1.0.tar.gz))->stringify;
        my $params  = {%nostream, author => 'THEBARD', norecurse => 1, archives => [$archive]};
        my $req     = POST( 'action/add', Content => $params);
        my $res     = $cb->($req);
        is $res->code, 200, 'Correct status code';

        is $res->header('Content-Type'), 'text/plain', 'Correct Type header';

        like $res->content, qr{^$PINTO_SERVER_RESPONSE_PROLOGUE\n},
            'Response starts with prologue';

        like $res->content, qr{$PINTO_SERVER_RESPONSE_EPILOGUE\n$},
            'Response ends with epilogue';

        #--------------------------------------------
        # Add it again, and make sure we get an error

        my $res2     = $cb->($req);
        is $res2->code, 200, 'Correct status code';

        is $res2->header('Content-Type'), 'text/plain', 'Correct Type header';

        like $res2->content, qr{already exists},
            'Response has Pinto error message';

        like $res2->content, qr{^$PINTO_SERVER_RESPONSE_PROLOGUE\n},
            'Response starts with prologue';

        unlike $res2->content, qr{$PINTO_SERVER_RESPONSE_EPILOGUE\n$},
            'Error response does not end with epilogue';

    };

#------------------------------------------------------------------------------
# Listing repository contents...

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $params = {%nostream};
        my $req    = POST('action/list', Content => $params);
        my $res    = $cb->($req);

        is   $res->code, 200, 'Correct status code';

        # Note that the lines of the listing itself should NOT contain
        # the $PINTO_SERVER_RESPONSE_LINE_PREFIX in front of each line.

        like $res->content, qr{^rl \s+ Foo \s+ 0.7 \s+ \S+ \n}mx,
            'Listing contains the Foo package';

        like $res->content, qr{^rl \s+ Bar \s+ 0.8 \s+ \S+ \n}mx,
            'Listing contains the Bar package';
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
        my $cb = shift;
        my $params = {%nostream};
        my $req    = POST('action/bogus', Content => $params);
        my $res    = $cb->($req);

        my $content = $res->content;

        like   $content, qr{Can't locate Pinto/Action/Bogus.pm}i,
            'Got an error message';

        like   $content, qr{^$PINTO_SERVER_RESPONSE_PROLOGUE\n},
            'Response starts with prologue';

        unlike $content, qr{$PINTO_SERVER_RESPONSE_EPILOGUE\n$},
            'Error response does not end with epilogue';
    };

#------------------------------------------------------------------------------
# Do all tests again, without streaming

unless (%nostream) {
    $nostream{nostream} = 1;
    goto START;
}

#------------------------------------------------------------------------------

done_testing();







