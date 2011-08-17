package Pinto::Server;

# ABSTRACT: Web interface to a Pinto repository

use Carp;
use Data::Dumper;
use Path::Class;
use File::Temp;

use Pinto;
use Pinto::Config;
use Pinto::Logger;

use Dancer ':syntax';

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------
# These are persistent variables!

my $config = Pinto::Config->new();
my $logger = Pinto::Logger->new(config => $config);
my $pinto  = Pinto->new(logger => $logger, config => $config);

#----------------------------------------------------------------------------

post '/add' => sub {

    my $author = param('author')
      or (status 500 and return 'No author supplied');

    my $dist   = upload('dist')
      or (status 500 and return 'No dist file supplied');

    my $tempdir = dir( File::Temp::tempdir(CLEANUP=>1) );
    my $dist_file = $tempdir->file( $dist->basename() );
    $dist->copy_to( $dist_file );

    eval {$pinto->add(dists => $dist_file, author => $author); 1}
        or (status 500 and return $@);

    status 200;
    return "SUCCESS\n";

};

#----------------------------------------------------------------------------

post '/remove' => sub {

    my $author  = param('author')  or return _error('No author supplied');
    my $package = param('package') or return _error('No package supplied');

    eval {$pinto->remove(packages => $package, author => $author); 1}
        or (status 500 and return $@);

    status 200;
    return "SUCCESS\n";
};

#----------------------------------------------------------------------------

post '/list' => sub {

    my $buffer = '';
    eval {$pinto->list(out => \$buffer); 1}
        or (status 500 and return $@);

    status 200;
    return $buffer;

};

#----------------------------------------------------------------------------

get '/' => sub {

    status 200;
    return "OK";
};

#----------------------------------------------------------------------------

get '/authors/**' => sub {
     my $file =  file( $config->local(), request->uri() );
     return send_file( $file, system_path => 1 );
};

#----------------------------------------------------------------------------

get '/modules/**' => sub {
     my $file =  file( $config->local(), request->uri() );
     return send_file( $file, system_path => 1 );
};

#----------------------------------------------------------------------------

1;

__END__
