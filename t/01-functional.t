#!perl

use strict;
use warnings;

use Test::More;
use Plack::Test;

use JSON;
use Path::Class;
use PerlIO::gzip;
use HTTP::Date;
use HTTP::Request::Common;

use Pinto::Server;
use Pinto::Tester;
use Pinto::Constants qw(:all);
use Pinto::Tester::Util qw(make_dist_archive);

#------------------------------------------------------------------------------
# Setup...

my $t    = Pinto::Tester->new;
my %opts = (root => $t->pinto->root);
my $app  = Pinto::Server->new(%opts)->to_app;

#------------------------------------------------------------------------------
# Fetching an index...

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $req = GET('init/modules/02packages.details.txt.gz');
        my $res = $cb->($req);

        is $res->code, 200, 'Correct status code';

        is $res->header('Content-Type'), 'application/x-gzip',
            'Correct Type header';

        cmp_ok $res->header('Content-Length'), '>=', 200,
            'Reasonable Length header'; # Actual length may vary

        cmp_ok $res->header('Content-Length'), '<', 400,
            'Reasonable Length header'; # Actual length may vary

        is $res->header('Content-Length'), length $res->content,
            'Length header matches actual length';

        is $res->header('Cache-Control'), 'no-cache',
            'Got a "Cache-Control: no-cache" header';

        isnt str2time($res->header('Last-Modified')), undef,
            'Last-Modified header contains a proper HTTP::Date string';
    };

#------------------------------------------------------------------------------
# Test fetching legacy indexes (used by the cpan[1] client)

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;

        my @paths  = qw(authors/01mailrc.txt.gz modules/03modlist.data.gz);

        for my $path (@paths) {
            my $url = "init/$path";
            my $req = GET($url);
            my $res = $cb->($req);
            is $res->code, 200, "Got response for $url";
            is $res->header('Cache-Control'), "no-cache", "$url got a 'Cache-Control: no-cache' header";
        }
    };


#------------------------------------------------------------------------------
# Add an archive, then fetch it back.  Finally, check that all packages in the
# archive are present in the listing

{

  my $archive = make_dist_archive('TestDist-1.0=Foo~0.7,Bar~0.8')->stringify;

  test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $params  = {author => 'THEBARD', norecurse => 1, message => 'test', archives => [$archive]};
        my $req     = POST( 'action/add', Content => {action_args => encode_json($params)} );
        my $res     = $cb->($req);
        action_response_ok($res);

        #--------------------------------------------
        # Add it again, and make sure we get an error

        my $res2     = $cb->($req);
        action_response_not_ok($res2, qr{already exists});
    };

  test_psgi
    app => $app,
    client => sub {
          my $cb  = shift;
          my $url = 'init/authors/id/T/TH/THEBARD/TestDist-1.0.tar.gz';
          my $req = GET($url);
          my $res = $cb->($req);

          is $res->code, 200, "Correct status code for GET $url";

          is $res->header('Content-Type'), 'application/x-gzip',
            "Correct Type header for GET $url";

          is $res->header('Content-Length'), -s $archive,
            "Length header matches actual archive size for GET $url";

          is $res->header('Content-Length'), length $res->content,
            "Length header matches actual content length for GET $url";
    };

  my $last_modified;

  test_psgi
    app => $app,
    client => sub {
          my $cb  = shift;
          my $url = 'init/authors/id/T/TH/THEBARD/TestDist-1.0.tar.gz';
          my $req = HEAD($url);
          my $res = $cb->($req);

          $last_modified = $res->header('Last-Modified');

          isnt str2time($last_modified), undef,
            "Last-Modified header contains a proper HTTP::Date string for HEAD $url";

          is $res->code, 200, "Correct status code for HEAD $url";

          is $res->header('Content-Type'), 'application/x-gzip',
            "Correct Type header for HEAD $url";

          is $res->header('Content-Length'), -s $archive,
            "Length header matches actual archive size for HEAD $url";

          is length $res->content, 0,
            "No content returned for HEAD $url";
    };

  test_psgi
    app => $app,
    client => sub {
          my $cb  = shift;
          my $url = 'init/authors/id/T/TH/THEBARD/TestDist-1.0.tar.gz';
          my $req = GET($url, 'If-Modified-Since' => $last_modified);
          my $res = $cb->($req);

          is $res->code, 304, "Correct status code for unmodified $url";

          is $res->header('Content-Type'), undef,
            "No Content-Type header for 304 response";

          is $res->header('Content-Length'), undef,
            "No Content-Length header for 304 response";

          is length $res->content, 0,
            "No content returned for 304 response";
    };

  test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $params = {};
        my $req    = POST('action/list', Content => {action_args => encode_json($params)});
        my $res    = $cb->($req);

        is   $res->code, 200, 'Correct status code';

        # Note that the lines of the listing itself should NOT contain
        # the $PINTO_SERVER_RESPONSE_LINE_PREFIX in front of each line.

        like $res->content, qr{^rl \s+ Foo \s+ 0.7 \s+ \S+ \n}mx,
            'Listing contains the Foo package';

        like $res->content, qr{^rl \s+ Bar \s+ 0.8 \s+ \S+ \n}mx,
            'Listing contains the Bar package';
    };
}

#------------------------------------------------------------------------------
# Make two stacks, add a different version of a dist to each stack, then fetch
# the index for each stack.  The indexes should contain different dists.

for my $v (1,2) {

  my $stack   = "stack_$v";
  my $archive = make_dist_archive("Fruit-$v=Apple~$v,Orange~$v")->stringify;

  test_psgi
    app => $app,
    client => sub {
        my $cb     = shift;
        my $params = {stack => $stack, message => 'test'};
        my $req    = POST('action/new', Content => {action_args => encode_json($params)});
        my $res    = $cb->($req);

        action_response_ok($res);
    };


  test_psgi
    app => $app,
    client => sub {
        my $cb      = shift;
        my $params  = {author => 'JOHN', norecurse => 1, stack => $stack, message => 'test', archives => [$archive]};
        my $req     = POST( 'action/add', Content => {action_args => encode_json($params)} );
        my $res     = $cb->($req);

        action_response_ok($res);
    };


  test_psgi
    app => $app,
    client => sub {
        my $cb   = shift;
        my $req  = GET("$stack/modules/02packages.details.txt.gz");
        my $res  = $cb->($req);


        is   $res->code, 200, 'Correct status code';

        # Write the index to a file
        my $temp = File::Temp->new;
        print {$temp} $res->content;
        close $temp;

        # Slurp index contents into memory
        open my $fh, '<:gzip', $temp->filename or die $!;
        my $index = do { local $/ = undef; <$fh> };
        close $fh;

        # Test index contents
        for ( qw(Apple Orange) ) {
          like $index, qr{^ $_ \s+ $v  \s+ J/JO/JOHN/Fruit-$v.tar.gz $}mx, "index contains package $_-$v";
        }
    };
}

#------------------------------------------------------------------------------
# GET invalid path...

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $req = GET('bogus/path');
        my $res = $cb->($req);

        is   $res->code, 404, 'Correct status code';
        is   $res->header('Content-Type'), 'text/plain';
        is   $res->header('Content-Length'), length $res->content;
        like $res->content, qr{not found}i, 'File not found message';
    };

#------------------------------------------------------------------------------
# POST invalid action

test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $params = {};
        my $req    = POST('action/bogus', Content => {action_args => encode_json($params)});
        my $res    = $cb->($req);

        action_response_not_ok($res, qr{Can't locate Pinto/Action/Bogus.pm}i);
    };

#------------------------------------------------------------------------------

sub action_response_ok {
  my ($response, $pattern, $test_name) = @_;

  $test_name ||= sprintf '%s %s', $response->request->method,
                                  $response->request->uri;

  # Report failues from caller's perspective
  local $Test::Builder::Level = $Test::Builder::Level + 1;

  my $type = $response->header('Content-Type');
  is $type, 'text/plain', "Correct Content-Type header for $test_name";

  my $status = $response->code;
  is $status, 200, "Succesful status code for $test_name";

  my $content = $response->content;
  like $content, qr{^$PINTO_SERVER_RESPONSE_PROLOGUE\n},
    "Response starts with prologue for $test_name";

  like $content, qr{$PINTO_SERVER_RESPONSE_EPILOGUE\n$},
    "Response ends with epilogue for $test_name";

  like $content, $pattern, "Response content matches for $test_name"
    if $pattern;
}

#------------------------------------------------------------------------------

sub action_response_not_ok {
  my ($response, $pattern, $test_name) = @_;

  $test_name ||= sprintf '%s %s', $response->request->method,
                                  $response->request->uri;

  # Report failues from caller's perspective
  local $Test::Builder::Level = $Test::Builder::Level + 1;

  my $type = $response->header('Content-Type');
  is $type, 'text/plain', "Correct Content-Type header for $test_name";

  my $status = $response->code;
  is $status, 200, "Succesful status code for $test_name";

  my $content = $response->content;
  like $content, qr{^$PINTO_SERVER_RESPONSE_PROLOGUE\n},
    "Response starts with prologue for $test_name";

  unlike $content, qr{$PINTO_SERVER_RESPONSE_EPILOGUE\n$},
    "Response does not end with epilogue for $test_name";

  like $content, $pattern, "Response content matches for $test_name"
    if $pattern;

}

#------------------------------------------------------------------------------

done_testing;







