WormBase Website Repository
===========================

This repository contains the [WormBase](http://www.wormbase.org) Web application.

Installation
------------

Execute the following commands in a BASH terminal:

    git clone git://github.com/WormBase/website.git wormbase
    cd wormbase
    export approot=`pwd`
    perl Makefile.PL
    make installdeps

If you did not start off in `/usr/local`, then you can either change the preset paths in the application's configuration files, or alternatively, carry out these two steps:

    sudo -E su
    cd /usr/local
    ln -s $approot

### Dependencies

Most dependencies will be installed with `make installdeps`, but `perl Makefile.PL` itself is depending on some prerequisites:

1.  a development environment: Perl, make, gcc & co.
2.  `sudo cpan Module::Install`

On Mac OS X, Perl comes preinstalled. The C development tools are installed from within Xcode, which is free, and then selecting from the menu/dialogs: Xcode -> Preferences... -> Downloads -> Components -> "Command Line Tools" -> "Install".

Running the application
-----------------------

To run the app using the built-in Catalyst server:

    script/wormbase_server.pl -p 8000

Running the application via Starman
-----------------------------------

    starman --port 8000 --workers 10 wormbase.psgi

Contributing
------------

Our development workflow can be found here:

[wiki.wormbase.org/index.php/Development_workflow_-_webdev](wiki.wormbase.org/index.php/Development_workflow_-_webdev)

Todd Harris (todd@wormbase.org)
