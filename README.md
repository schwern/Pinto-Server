# NAME

Pinto::Server - Web interface to a Pinto repository

# VERSION

version 0.028

# DESCRIPTION

There is nothing to see here.

Look at [pinto-server](http://search.cpan.org/perldoc?pinto-server) instead.

Then you'll probably want to look at [pinto-remote](http://search.cpan.org/perldoc?pinto-remote).

See [Pinto::Manual](http://search.cpan.org/perldoc?Pinto::Manual) for a complete guide.

# ATTRIBUTES

## repos

The path to your Pinto repository.  The repository must already exist
at this location.  This attribute is required.

## port

The port number the server shall listen on.  The default is 3000.

## daemon

If true, Pinto::Server will fork and run in a separate process.
Default is false.

# METHODS

## run()

Starts the Pinto::Server.  Returns a PSGI-compatible code reference.

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

The CPAN Testers Matrix is a website that provides a visual way to determine what Perls/platforms PASSed for a distribution.

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