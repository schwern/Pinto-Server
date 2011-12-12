#!perl

use strict;
use warnings;

use Path::Class;
use FindBin qw($Bin);

use Pinto::Tester;
use Pinto::Server::Routes;

use Dancer::Test;

use Test::More;

#------------------------------------------------------------------------------
# Create a repository

my $t     = Pinto::Tester->new();
my $repos = $t->root_dir();
my $pinto = $t->pinto();

#------------------------------------------------------------------------------
# Setup the server

Dancer::set(repos => $repos);

#------------------------------------------------------------------------------
# Get a distribution to play with.  Dancer::Test::dancer_response() does not
# handle uploading of binary files.  So instead of sending the usual .tar.gz
# file, we're going to send an uncompressed .tar file since it is just text.

my $dist_name = 'FooAndBar-0.02.tar';
my $dist_file = file($Bin, 'data', $dist_name);
ok -e $dist_file, "Test distribution $dist_file exists";

#------------------------------------------------------------------------------
# Now do some tests;

my $files = {};
my $params = {};


#------------------------------------------------------------------------------
# The repository is brand new, so the listing should be empty

$params = {};
my $response = dancer_response( POST => '/action/list', {params => $params} );
is $response->{status}, 200, 'list action was successful';
is $response->{content}, '', 'listing is empty';

#------------------------------------------------------------------------------
# Now try adding a dist

$params = {author => 'ME'};
$files = [ {filename => $dist_file, name => 'archive' } ];
$response = Dancer::Test::dancer_response( POST => '/action/add', {params => $params, files => $files} );
is $response->{status}, 200, 'add action was successful';
is $response->{content}, '', 'response is empty';

#------------------------------------------------------------------------------
# The listing should now contain our dist

$params = {};
$response = dancer_response( POST => '/action/list', {params => $params} );
is $response->{status}, 200, 'List action was successful';
like $response->{content}, qr{M/ME/ME/FooAndBar}, 'listing has added dist';

#------------------------------------------------------------------------------
# Try a formatted listing, of packages matching 'Foo' only

$params = {format => '%a %N', packages => 'Foo'};
$response = dancer_response( POST => '/action/list', {params => $params} );
is $response->{status}, 200, 'Formatted List action was successful';
is $response->{content}, 'ME Foo-0.02', 'Formatted listing is correct';

#------------------------------------------------------------------------------
# Adding the same dist again should cause a Pinto exception

$params = {author => 'YOU'};
$files = [ {filename => $dist_file, name => 'archive'} ];
$response = Dancer::Test::dancer_response( POST => '/action/add', {params => $params, files => $files} );
is $response->{status}, 500, 'add action failed';
like $response->{content}, qr/Only author ME can update/, 'response has exception';

#------------------------------------------------------------------------------
# Check the statistics

$response = Dancer::Test::dancer_response( POST => '/action/statistics', {});
is $response->{status}, 200, 'Statistics action was successful';
like $response->{content}, qr/Distributions \s* 1 \s* 1/, 'Correct dist stats';
like $response->{content}, qr/Packages \s* 1 \s* 1/, 'Correct pkg stats';

#------------------------------------------------------------------------------
# Try pinning

$params = {package => 'Foo'};
$response = Dancer::Test::dancer_response( POST => '/action/pin', {params => $params});
is $response->{status}, 200, 'Pin action was successful';

#------------------------------------------------------------------------------
# Try unpinning

$params = {package => 'Foo'};
$response = Dancer::Test::dancer_response( POST => '/action/unpin', {params => $params});
is $response->{status}, 200, 'Unpin action was successful';

#------------------------------------------------------------------------------
# Now try removing the dist

$params = {author => 'ME', path => $dist_name};
$response = dancer_response( POST => '/action/remove', {params => $params} );
is $response->{status}, 200, 'remove action was successful';
is $response->{content}, '', 'response is empty';

#------------------------------------------------------------------------------
# Once again, the listing should be empty

$params = {type => 'All'};
$response = dancer_response( POST => '/action/list', {params => $params} );
is $response->{status}, 200, 'List action was successful';
is $response->{content}, '', 'listing is now empty';

#------------------------------------------------------------------------------
# Just exercising the Nop

$response = dancer_response( POST => '/action/nop' );
is $response->{status}, 200, 'Nop action was successful';
is $response->{content}, '', 'output was empty';

#------------------------------------------------------------------------------
# Pinger

$response = dancer_response( get => '/' );
is $response->{status}, 200, 'Ping was successful';
is $response->{content}, 'Pinto::Server 0.027 OK', 'Correct output';

#------------------------------------------------------------------------------
# Test server exceptions

$params = {};
$response = dancer_response( POST => '/action/add', {params => $params} );
is $response->{status}, 500, 'add action without author failed';
like $response->{content}, qr/No author/, 'got correct exception msg';

$params = {author => 'WHATEVER'};
$response = dancer_response( POST => '/action/add', {params => $params} );
is $response->{status}, 500, 'add action without dist_file failed';
like $response->{content}, qr/No archive/, 'got correct exception msg';

$params = {};
$response = dancer_response( POST => '/action/remove', {params => $params} );
is $response->{status}, 500, 'remove action without author failed';
like $response->{content}, qr/No author/, 'got correct exception msg';

$params = {author => 'WHATEVER'};
$response = dancer_response( POST => '/action/remove', {params => $params} );
is $response->{status}, 500, 'add action without dist_name failed';
like $response->{content}, qr/No path/, 'got correct exception msg';

#------------------------------------------------------------------------------

done_testing();
