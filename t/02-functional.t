#!perl

use strict;
use warnings;

use File::Temp;
use Path::Class;
use FindBin qw($Bin);

use Pinto;
use Pinto::Server::Routes;

use Dancer::Test;

use Test::More (tests => 23);

#------------------------------------------------------------------------------
# Create a repository

my $repos = dir( File::Temp::tempdir(CLEANUP => 1) );
my $pinto = Pinto->new(out => \my $buffer, repos => $repos, verbose => 3);

$pinto->new_action_batch();
$pinto->add_action('Create')->run_actions();

#------------------------------------------------------------------------------
# Setup the server

Dancer::set( 'repos' => $repos);

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

$params = {type => 'all'};
my $response = dancer_response( POST => '/action/list', {params => $params} );
is $response->{status}, 200, 'list action was successful';
is $response->{content}, '', 'listing is empty';

#------------------------------------------------------------------------------
# Now try adding a dist

$params = {author => 'ME'};
$files = [ {filename => $dist_file, name => 'dist_file' } ];
$response = Dancer::Test::dancer_response( POST => '/action/add', {params => $params, files => $files} );
is $response->{status}, 200, 'add action was successful';
is $response->{content}, '', 'response is empty';

#------------------------------------------------------------------------------
# The listing should now contain our dist

$params = {type => 'All'};
$response = dancer_response( POST => '/action/list', {params => $params} );
is $response->{status}, 200, 'List action was successful';
like $response->{content}, qr{M/ME/ME/FooAndBar}, 'listing has added dist';

#------------------------------------------------------------------------------
# Adding the same dist again should cause a Pinto exception

$params = {author => 'YOU'};
$files = [ {filename => $dist_file, name => 'dist_file' } ];
$response = Dancer::Test::dancer_response( POST => '/action/add', {params => $params, files => $files} );
is $response->{status}, 500, 'add action failed';
like $response->{content}, qr/Only author ME can update/, 'response has exception';

#------------------------------------------------------------------------------
# Now try removing the dist

$params = {author => 'ME', dist_name => $dist_name};
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
# Test server exceptions

$params = {};
$response = dancer_response( POST => '/action/add', {params => $params} );
is $response->{status}, 500, 'add action without author failed';
like $response->{content}, qr/No author/, 'got correct exception msg';

$params = {author => 'WHATEVER'};
$response = dancer_response( POST => '/action/add', {params => $params} );
is $response->{status}, 500, 'add action without dist_file failed';
like $response->{content}, qr/No dist_file/, 'got correct exception msg';

$params = {};
$response = dancer_response( POST => '/action/remove', {params => $params} );
is $response->{status}, 500, 'remove action without author failed';
like $response->{content}, qr/No author/, 'got correct exception msg';

$params = {author => 'WHATEVER'};
$response = dancer_response( POST => '/action/remove', {params => $params} );
is $response->{status}, 500, 'add action without dist_name failed';
like $response->{content}, qr/No dist_name/, 'got correct exception msg';
