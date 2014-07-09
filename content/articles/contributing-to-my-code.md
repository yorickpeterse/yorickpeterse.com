<div class="note">
    <p>
        This article is rather blunt and a bit old. I've since become much more
        pragmatic about coding styles. Most of my newer repositories have an
        explicit contributing guide (often in CONTRIBUTING.md) so its best to
        check that out in favour of this article.
    </p>
</div>

This document describes the various requirements that I have in order for me to
accept third-party contributions. Note that this guide is an ever expanding
guide so expect things to change over the course of time.

## Table Of Contents

* [Indentation](#indentation)
  * [Module and Class Indentation](#module-and-class-indentation)
* [Documentation](#documentation)
* [Dependencies](#dependencies)
* [Testing](#testing)
* [Git](#git)
  * [Commit Messages](#commit-messages)
* [Forbidden Files](#forbidden-files)
* [Legal Requirements](#legal-requirements)
* [Language Requirements](#language-requirements)

## Indentation

Code should be indented using 2 spaces per indentation level *or* 4 spaces for
HTML, CSS and JavaScript files. The latter is done because I strongly feel that
2 spaces just isn't enough in XML based languages or languages that use curly
braces. In all cases the use of tabs is forbidden. I'm not going to argue
whether tabs are better than spaces (or the other way around). Bluntly put, if
you want to contribute code you're going to use spaces.

An example of correct indentation:

    #!ruby
    class User
      def initialize(name)
        @name = name
      end
    end

An example of incorrect indentation:

    #!ruby
    class User
        def initialize(name)
            @name = name
        end
    end

If you use an odd number of spaces per indentation level (e.g. 3) I'll find you
and whack you with a cane.

If you're using Vim you can use the following snippet to ensure that you're
using the correct indentation settings:

    #!text
    autocmd! FileType ruby setlocal shiftwidth=2 softtabstop=2 tabstop=2 expandtab

### Module and Class Indentation

When defining classes and modules you should define each segment on its own.
This means that the following is correct:

    #!ruby
    module Foo
      class Bar

      end
    end

While this is not:

    #!ruby
    class Foo::Bar

    end

The former is better as it allows you to load the file without manually having
to define missing segments of the namespace. This becomes especially useful if
you want to test specific files without loading the rest of a Gem or
application.

## Documentation

Although many people seem to believe documentation is not relevant because code
supposedly always explains itself I have a very different opinion. Because the
code I write is meant for others it should be as easy as possible for these
people to get started with my code. I don't expect people to write entire books
about a single method but at the very least you should document the parameters
(or attributes for classes and such) and the return values. You should also use
easy to understand and short method names as these aid in the documentation
process.

Documentation should be done using [YARD][yard] for both Ruby and JavaScript
code. An example of a properly documented method is the following:

    #!ruby
    ##
    # Sends an Email notification to a user.
    #
    # @param [User] user
    # @return [TrueClass|FalseClass]
    #
    def register_user(user)
      # ...
    end

On the other hand, the following will make me angry:

    #!ruby
    def register_user(user)
      # ...
    end

Although I can live without a method description in the above example (the
method name does a good job at explaining what it does) it's not clear what
kind of input the method expects and what it gives back. Yes, you can start
digging around in code to see exactly what it does but most people really can't
be bothered. For those it's much easier to just look it up in the
documentation.

Whenever you write documentation you should use Markdown as the markup format.
Markdown is easy to read in its raw form and is converted to HTML when the
documentation is generated.

## Dependencies

The amount of dependencies of a project, both runtime and development
dependencies, should be kept as small as possible. Things can get quite
complicated when I have to read through the change logs of dozens of Gems for
various projects and as such I'd like to keep this amount at a controllable
level.

## Testing

When working with code please write tests accordingly. For example, I know
myself well enough to know that unless I have a proper set of tests I'll just
forget about potential problems until they bite me in the back when I least
expect it.

When you're just starting out with a new feature and opened a pull request as
the means to ask for feedback it's fine if you don't have any tests yet. I
start most projects without any tests until I have a better understanding of
what I'm actually trying to achieve. However, when you're reaching the point
where you actually want me to merge it you *must* add a decent set of tests.
Here "decent" is of course relative to the project and the contribution so I'll
try to do my best to help people with it.

Projects I run on my own are tested using [Bacon][bacon] along with maybe some
project specific dependencies such as [Webmock][webmock]. Bacon's syntax is
very similar to Rspec so it should be fairly easy to get started with it.

## Git

For version control I use Git and Github as my primary Git hosting company. In
case you're not familiar with Git you can find more information here:
<http://git-scm.com/>.

### Commit Messages

Commit messages should follow the same standard as the Kernel/Git repository.
The first line of the commit acts as a short description of what the commit
does. Think of it as the subject of an Email: make it short and understandable.
The maximum amount of characters on this line is 50 characters.

Note that descriptions such as "Updated README.md" and "Changes" are not proper
descriptions and will result in me not accepting such commits.

The second line of the commit should be empty as it acts as a separator between
the subject and following lines. The following lines can be used to give a more
in-depth description of what the commit does. These lines must not be longer
than 80 characters per line.

An example of a good commit message is the following:

    #!text
    Started completely re-writing the AST.

    The current AST that's being generated by RubyLint::Parser is overly complex
    and confusing due to the large number of classes used for different node types.
    After having a discussion about ASTs and the likes with @whitequark I decided
    that the AST generated by the parser has to be re-written from scratch.

    To make things easier I'm using "Furnace" which provides a simple, immutable
    class that can be used for representing nodes in an AST. Along with changing
    the AST will come various changes to the way the definitions list is built as
    well as how callback classes work (due to different event names being used).
    None of this will be backwards compatible with what I've currently pushed to
    Rubygems but that's expected when something is still alpha quality software.

    Signed-off-by: Yorick Peterse <yorickpeterse@gmail.com>

Example of a not so good commit message:

    #!text
    ensure a http 302 redirect

The latter is bad because although it does state what it does (up to a certain
point) there's no in depth explanation. This means that I have to start digging
through code in order to find out what's going on. While I will always check
every commit added by somebody else there are times when the code is not clear
enough and I have no interest in spending an entire evening trying to
understand what somebody was trying to do.

## Forbidden Files

Most of my projects have various files that are off limits for anybody but me.
These are the following files:

* LICENSE
* MANIFEST
* lib/project-name/version.rb
* project-name.gemspec

Gemspecs may only be modified if you have to add a dependency, otherwise they
are also off limits.

## Legal Requirements

All my source code is licensed under the MIT license unless stated otherwise.
This means that any contribution you make *must* use the same license. Even if
it's compatible with the MIT license I simply do not accept other ones (GPL,
Apache, etc). An up to date copy of the MIT license can be found in a file
called "LICENSE" that lives in the root directory of the repository unless
specified otherwise.

The use of proprietary code or code taken from other projects without prior
permission is also strictly forbidden.

## Language Requirements

Besides the various coding standards and commit requirements I also require
both code and commits to be written in proper English. A typo or grammar error
happens and isn't the end of the world but please double check your spelling
before committing something. If you use Vim you can enable spell checking by
running the following:

    #!text
    set spell spelllang=en

The use of offensive or otherwise negative language aimed at other projects,
people, organizations and the likes is not allowed. My code is not the place to
share any sexist, racist or otherwise offensive opinions.

[yard]: http://yardoc.org/
[bacon]: https://github.com/chneukirchen/bacon
[webmock]: https://github.com/bblimke/webmock
