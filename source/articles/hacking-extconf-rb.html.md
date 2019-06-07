---
title: Hacking extconf.rb
date: 2013-06-08 23:00
tags: ruby, extconf, hack, rubygems
description: >
  Hacking extconf.rb to run arbitrary commands upon Gem installation.
---
<!-- vale off -->

<div class="note">
As it turns out you can make the process discussed in this article easier by
using a Rakefile instead of an extconf.rb file. See the bottom of this article
for more information.
</div>

In Ruby land [RubyGems][rubygems] is the de facto package manager. RubyGems
allows you to easily distribute your Ruby packages (known as "Gems"). These
packages come in two flavours:

* Pure Ruby Gems
* Gems that include C code (or any other compiled code for that matter) that
  is compiled upon installation

The latter is commonly used to create Ruby bindings for C libraries such as
[libxml2][libxml2]. The benefit of using C bindings is that they generally
perform better than their pure Ruby equivalents.

To install a C extension RubyGems executes a Ruby file called "extconf.rb"
(though you can change the name) to generate a Makefile and then runs `make`
and `make install` to build and install the extension. To get this done you'll
have to tell RubyGems where it can find the required files, this is done in
your Gem specification as following:

```ruby
Gem::Specification.new do |gem|
  # ...

  # These files are used to generate Makefile files which in turn are used
  # to build and install the C extension.
  gem.extensions = ['ext/my_extension/extconf.rb']

  # ...
end
```

Here the configuration file is located in `ext/my_extension/extconf.rb`. These
files typically look like something along the lines of the following:

```ruby
require 'mkmf'

have_header('some_header')
find_executable('some_required_executable')

$CFLAGS << ' -Wextra -Wall -pedantic '

create_makefile('my_extension/my_extension')
```

Because all of this is executed upon Gem installation (and thus on the end
user's computer) this opens up interesting possibilities. For example, you
could check if specific files are available in a certain directory or as is
more commonly done check for headers and such. It also allows you to execute
arbitrary commands (which can potentially be dangerous).

For a project at [Olery][olery] we had to wrap code written in various
languages (Java, Python and Perl to be exact) in Ruby and distribute it. This
introduces a problem though: how do you ensure that all the dependencies of
both the Ruby and underlying code (e.g. Python) are installed? How do you
ensure that the right versions are available? In other words: dependency
management.

To give an example, one of the underlying code bases was written in Perl and
vendored the dependencies in the Git repository of the project. Normally Perl
is easy to use: you just run it. However, this particular project used one Perl
package that had a C binding and thus had to be compiled upon installation.

In Perl you normally install packages using CPAN (or CPAN Minus). However, CPAN
is rolling release and thus only keeps track of the most recent version of each
package. This means that a package could break at any given time without us
knowing about it beforehand. Another problem is that CPAN might not always be
available, configured or might require root access to install packages (this
depends on the configuration though). In other words, relying on CPAN would
probably make things too painful to deal with.

We decided to go down a different route: manually compile the package upon
installation. Since it was vendored and packaged along with the Ruby code this
in theory should not be too hard.

To achieve this we had to find a way to tap into the installation process of a
Gem. The only way to do this without requiring the user to run extra commands
after installing the Gem is to tap into the C extension build process. Since
this process is executed on the user's machine it allows you to inject
arbitrary actions. In other words, we had to hijack extconf.rb to compile the
Perl code.

To recap, building a C extension happens as following:

1. Download the Gem
2. Run the extconf.rb file(s) of the Gem to generate the Makefile(s)
3. Run `make` and `make install` for each Makefile to build and install the
   corresponding extensions.
4. Move the generated extension file (e.g. `my_extension.so`) to the lib
   directory of the Gem so that it becomes available in the load path.

Our solution was as following: use extconf.rb to compile the Perl code and use
a dummy Makefile to trick RubyGems into believing that the C extension was
built successfully. Without a valid Makefile RubyGems would otherwise just
abort the process.

As an example we'll build a Gem called "wat". The first step is to create a
basic Gem specification (only relevant code is shown here):

```ruby
Gem::Specification.new do |gem|
  gem.name       = 'wat'
  gem.extensions = ['ext/wat/extconf.rb']
end
```

In our case the extconf.rb file had to do two things: check for the required
dependencies (e.g. the "perl" command) and compile the extensions:

```ruby
require 'mkmf'

# Stops the installation process if one of these commands is not found in
# $PATH.
find_executable('perl')
find_executable('make')

# Create a dummy extension file. Without this RubyGems would abort the
# installation process. On Linux this would result in the file "wat.so"
# being created in the current working directory.
#
# Normally the generated Makefile would take care of this but since we
# don't generate one we'll have to do this manually.
#
File.touch(File.join(Dir.pwd, 'wat.' + RbConfig::CONFIG['DLEXT']))

directories_with_perl_code.each do |directory|
  Dir.chdir(directory) do
    sh 'perl Makefile.PL PREFIX=path/to/local/installation LIB=path/to/local/lib'
    sh 'make && make install && make clean'
  end
end

# This is normally set by calling create_makefile() but we don't need that
# method since we'll provide a dummy Makefile. Without setting this value
# RubyGems will abort the installation.
$makefile_created = true
```

This takes care of ensuring our dependencies are there, the Perl code is
compiled and RubyGems doesn't abort the installation process.

Next up we'll need to create a dummy Makefile. This Makefile goes in the same
directory as the extconf.rb file and looks pretty simple:

    all:
        true

    install:
        true

The `true` commands are used to ensure that the commands run successfully,
again RubyGems would abort installation if one of them failed.

This solution, as dirty as it may sound, was actually surprisingly elegant. Of
course you should not use this as an excuse to turn RubyGems into a universal
package manager. However, if you need to take care of some basic dependency
management or need to run arbitrary commands upon installation it's not even
that bad. And no, I did not do drugs while writing that.

After discussing this with [Peter Zotov][whitequark] it turns out that the
above process can be done a bit easier by using a Rakefile instead of an
extconf.rb file. An example of a project using this approach is
[ruby-llvm][ruby-llvm]. I haven't investigated this option myself so I can't
tell for certain though.

## Using a Rakefile

After writing this article it was discovered that the above process can be made
significantly easier by using a Rakefile. To be more exact, any file that does
not match the following pattern can be used without having to create the above
dummy files:

```ruby
/\A(extconf|makefile).rb\z/
```

This information is based on [this][mkmf-wtf] code. These particular lines of
code cause the installation process to fail (since mkmf exits with a non
successful exit status) if the filename of an extension matches the above
pattern and the variable `$extmk` is set to `false`.

In our particular use case this meant that I could get rid of the dummy
Makefile and C extension file since it's actually mkmf that insists on these
files being created and not RubyGems. This in turn made the code considerably
smaller and much less of a hack.

[rubygems]: http://rubygems.org/
[libxml2]: http://www.xmlsoft.org/
[olery]: http://olery.com/
[whitequark]: https://github.com/whitequark/
[ruby-llvm]: https://github.com/ruby-llvm/ruby-llvm/blob/master/ruby-llvm.gemspec
[mkmf-wtf]: https://github.com/ruby/ruby/blob/34f5700a0947243198dea5461b80fa8be5ba19ea/lib/mkmf.rb#L2598-L2600
