---
title: Debugging With Pry
date: 2011-11-27 00:00
tags: pry, repl, ruby, debugging, irb
description: >
  Pry is a REPL (Read Eval Print Loop) that was written as a better alternative
  to IRB.
---
<!-- vale off -->

Pry is a REPL (Read Eval Print Loop) that was written as a better alternative
to IRB. It comes with syntax highlighting, code indentation that actually works
and several other features that make it easier to debug code. I stumbled upon
Pry when looking for an alternative to both IRB and the way I was debugging my
code (placing ``puts`` all over the place, I think it's called "Puts Driven
Development").

Pry tries to do a lot of things and I was actually quite surprised how well it
does that. It might not stick to the Unix idea of only doing a single thing
(and doing that very well) but it makes my life (and the lifes of others) so
much easier that it's easy to forget.

Pry is primarily meant to be used as a REPL. There are a lot of things that
make Pry so much more pleasant to use than IRB. One of the things almost any
Ruby programmer will notice when using IRB is that its indentation support is a
bit clunky. Indenting itself works fine most of the time but it fails to
un-indent code properly as illustrated in the code snippet below (pasted
directly from an IRB session):

    ruby-1.9.3-p0 :001 > class User
    ruby-1.9.3-p0 :002?>   def greet
    ruby-1.9.3-p0 :003?>     puts "Hello world"
    ruby-1.9.3-p0 :004?>     end
    ruby-1.9.3-p0 :005?>   end

Luckily Pry handles this just fine, whether you're trying to indent a class or
a hash containing an array containing a proc and so on. Pry does this by
resetting the terminal output every time a new line is entered. The downside of
this approach is that it only works on terminals that understand ANSI escape
codes.  In Pry the above example works like it should do:

    [1] pry(main)> class User
    [1] pry(main)*   def greet
    [1] pry(main)*     puts "Hello world"
    [1] pry(main)*   end
    [1] pry(main)* end

Besides indentation Pry does a lot more. A feature that I think is very cool is
the ability to show documentation and source code of methods right in your REPL
(sadly this feature doesn't work with classes or modules at the time of
writing). This means that you no longer have to use the ``ri`` command to
search documentation for methods. You also don't need to install the RDoc
documentation as Pry pulls it directly from the source code. Showing the source
code of a method or its documentation can be done by using the ``show-method``
and ``show-doc`` command. For example, invoking ``show-method pry`` in a Pry
session would give you the following output:

    [1] pry(main)> show-method pry

    From: /path/trimmed/for/readability/lib/pry/core_extensions.rb @ line 19:
    Number of lines: 3
    Owner: Object
    Visibility: public

    def pry(target=self)
      Pry.start(target)
    end

Calling ``show-doc pry`` would instead show the following:

    [2] pry(main)> show-doc pry

    From: /path/trimmed/for/readability/lib/pry/core_extensions.rb @ line 19:
    Number of lines: 17
    Owner: Object
    Visibility: public
    Signature: pry(target=?)

    Start a Pry REPL.
    This method differs from Pry.start in that it does not
    support an options hash. Also, when no parameter is provided, the Pry
    session will start on the implied receiver rather than on
    top-level (as in the case of Pry.start).
    It has two forms of invocation. In the first form no parameter
    should be provided and it will start a pry session on the
    receiver. In the second form it should be invoked without an
    explicit receiver and one parameter; this will start a Pry
    session on the parameter.
    param [Object, Binding] target The receiver of the Pry session.
    example First form
      "dummy".pry
    example Second form
       pry "dummy"
    example Start a Pry session on current self (whatever that is)
      pry

You can also run these commands for code that was written in C. This requires
you to install the gem ``pry-doc`` (``gem install pry-doc``). Do note that this
only works for core C code, currently Pry does not support this for third party
extensions.

Another very cool feature is that Pry can be used as a debugging tool for your
code without having to manually jump into a session. By loading Pry, which can
be done by writing ``require "pry"`` or by using the option ``-r pry`` when
invoking Ruby you gain access to everything Pry has to offer. The most useful
tool is ``binding.pry``. This method starts a Pry session and pauses the
script.

Lets say you have the following script and want to see the values of the
variables:

```ruby
language = 'Ruby'
number   = 10

# Do something awesome with the above variables.
```

The typical approach would be to insert a puts statement above the comment
followed by an exit statement. Pry in a way can do a similar thing, it just
makes it a lot more awesome. If you modify the script as following you can
truly debug your code like a boss:

```ruby
language = 'Ruby'
number   = 10

binding.pry

# Do something awesome with the above variables.
```

If you now run the script by calling ``ruby -r pry file.rb`` you get a fancy
Pry session:

    [yorickpeterse@Wifi-Ninja in ~]$ ruby -r pry file.rb

    From: file.rb @ line 4 in Object#N/A:

         1: language = 'Ruby'
         2: number   = 10
         3:
     =>  4: binding.pry
         5:
         6: # Do something awesome with the above variables.
    [1] pry(main)>

A nice thing about starting Pry this way is that it starts in the context of
the call to ``binding.pry`` meaning you get access to data such as the local
variables. These can be displayed by calling ``ls`` or by simply typing their
name.

    [yorickpeterse@Wifi-Ninja in ~]$ ruby -r pry file.rb

    From: file.rb @ line 4 in Object#N/A:

         1: language = 'Ruby'
         2: number   = 10
         3:
     =>  4: binding.pry
         5:
         6: # Do something awesome with the above variables.
    [1] pry(main)> ls
    self methods: include  private  public  to_s
    locals: _  _dir_  _ex_  _file_  _in_  _out_  _pry_  language  number
    [2] pry(main)> number
    => 10
    [3] pry(main)>

Moving out of the "breakpoint" (or moving to the next one if you have multiple
ones defined) can be done by hitting ^D (Ctrl+D usually).

Besides the features mentioned in this article Pry has several more. For
example, long output is piped to Less. This can be quite useful if you're
trying to display a big hash using ``pp``. The full list of features can be
found on the [Pry website][pry website] as well as by invoking the ``help``
command inside a Pry session. If you're in need of help or have any suggestions
you can join the IRC channel #pry on the Freenode network (irc.freenode.net).
The source code of Pry is hosted on [Github][pry github].

[pry website]: http://pry.github.com/
[pry github]: http://github.com/pry/pry
