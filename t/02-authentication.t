#!perl

use strict;
use warnings;

use Test::More;
use Plack::Test;

use File::Temp;
use Path::Class;
use HTTP::Request;
use Apache::Htpasswd;

use Pinto::Tester;
use Pinto::Server;
use Pinto::Constants qw(:all);

#------------------------------------------------------------------------------
# Create a repository

my $t = Pinto::Tester->new();

#------------------------------------------------------------------------------
# Create a password file

my $temp_dir = File::Temp->newdir();
my $htpasswd_file = file($temp_dir, 'htpasswd');
$htpasswd_file->touch(); # Apache::Htpasswd requires the file to exist
Apache::Htpasswd->new( $htpasswd_file )->htpasswd('my-login', 'my-password');

ok( -e $htpasswd_file, 'htpasswd file exists' );
ok( -s $htpasswd_file, 'htpasswd file is not empty' );

#------------------------------------------------------------------------------
# Setup the server

my $auth = {backend => 'Passwd', path => $htpasswd_file->stringify()};
my %opts = ( root => $t->pinto->root(), auth => $auth );
my $app  = Pinto::Server->new(%opts)->to_app();

#------------------------------------------------------------------------------
# Do tests

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $req = HTTP::Request->new(POST => "/action/list");
        my $res = $cb->($req);

        ok !$res->is_success, 'Request without authentication failed';
        like $res->content, qr/authorization required/i, 'Expected content';
    };

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $req = HTTP::Request->new(POST => "/action/list");
        $req->authorization_basic('my-login', 'my-password');
        my $res = $cb->($req);

        ok $res->is_success, 'Request with correct password succeeded';

        my $expected_content = "$PINTO_SERVER_RESPONSE_PROLOGUE\n"
            . "$PINTO_SERVER_RESPONSE_EPILOGUE\n";

        is $res->content, $expected_content, 'Expected content';
    };

test_psgi
    app => $app,
    client => sub {
        my $cb  = shift;
        my $req = HTTP::Request->new(POST => "/action/list");
        $req->authorization_basic('my-login', 'my-bogus-password');
        my $res = $cb->($req);

        ok ! $res->is_success, 'Request with invalid password failed';
        like $res->content, qr/authorization required/i, 'Expected content';
    };


#------------------------------------------------------------------------------

done_testing();
