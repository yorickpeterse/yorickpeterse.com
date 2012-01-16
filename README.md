# yorickpeterse.com

This repository contains the source code for my website
(<http://yorickpeterse.com/>). The website runs on [Zen][zen], requires Ruby 1.9
and is deployed using Fabric.

The source code is licensed under the MIT license, a copy of this license can be
found in the file "LICENSE". The articles, which are found in the "articles"
directory, are licensed under a [Creative Commons license][cc license].

## Requirements

* Zen 0.3 or newer
* PostgreSQL, MySQL or SQLite3 (please don't use that in production)
* Ruby 1.9.2 or newer
* Python 2.7 (Python 3.0 doesn't work with Fabric)
* Fabric
* Runit

## Installation

First get a copy of the repository:

    $ git clone git://github.com/YorickPeterse/yorickpeterse.com.git --recursive

This creates a clone of the repository and automatically loads all the
submodules. Once done you can deploy the website to your machines. Before doing
so you should change the server settings in ``fabfile.py``. And no, you won't
get access to my server :)

Once you've set the server details you can deploy the website. Assuming Ruby,
PostgreSQL and all that are set up you can deploy the website by running the
following commands:

    $ fab setup

Regular deployments (after the webiste has been set up) are executed by running
this:

    $ fab deploy

For a full list of the available commands run ``fab --list``.

[zen]: http://zen-cms.com/
[cc license]: http://creativecommons.org/licenses/by-nc-sa/3.0/
