# NAME

Pinto::Server - Web interface to a Pinto repository

# VERSION

version 0.050

# ATTRIBUTES

## root

The path to the root directory of your Pinto repository.  The
repository must already exist at this location.  This attribute is
required.

## auth

The hashref of authentication options, if authentication is to be used within
the server. One of the options must be 'backend', to specify which
Authen::Simple:: class to use; the other key/value pairs will be passed as-is
to the Authen::Simple class.

## router

An object that does the [Pinto::Server::Handler](http://search.cpan.org/perldoc?Pinto::Server::Handler) role.  This object
will do the work of processing the request and returning a response.

## default\_port

Returns the default port number that the server will listen on.  This
is a class attribute.

# METHODS

## to\_app()

Returns the application as a subroutine reference.

## call( $env )

Invokes the application with the specified environment.  Returns a
PSGI-compatible response.

There is nothing to see here.

Look at [pintod](http://search.cpan.org/perldoc?pintod) if you want to start the server.

# SUPPORT

## Perldoc

You can find documentation for this module with the perldoc command.

    perldoc Pinto::Server

## Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

- Search CPAN

    The default CPAN search engine, useful to view POD in HTML format.

    [http://search.cpan.org/dist/Pinto-Server](http://search.cpan.org/dist/Pinto-Server)

- CPAN Ratings

    The CPAN Ratings is a website that allows community ratings and reviews of Perl modules.

    [http://cpanratings.perl.org/d/Pinto-Server](http://cpanratings.perl.org/d/Pinto-Server)

- CPAN Testers

    The CPAN Testers is a network of smokers who run automated tests on uploaded CPAN distributions.

    [http://www.cpantesters.org/distro/P/Pinto-Server](http://www.cpantesters.org/distro/P/Pinto-Server)

- CPAN Testers Matrix

    The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

    [http://matrix.cpantesters.org/?dist=Pinto-Server](http://matrix.cpantesters.org/?dist=Pinto-Server)

- CPAN Testers Dependencies

    The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

    [http://deps.cpantesters.org/?module=Pinto::Server](http://deps.cpantesters.org/?module=Pinto::Server)

## Bugs / Feature Requests

[https://github.com/thaljef/Pinto-Server/issues](https://github.com/thaljef/Pinto-Server/issues)

## Source Code



[https://github.com/thaljef/Pinto-Server](https://github.com/thaljef/Pinto-Server)

    git clone git://github.com/thaljef/Pinto-Server.git

# AUTHOR

Jeffrey Ryan Thalhammer <jeff@imaginative-software.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Imaginative Software Systems.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
