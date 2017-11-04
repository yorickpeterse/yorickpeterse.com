---
title: "Oga: a new XML/HTML parser for Ruby"
date: 2014-09-12 14:45
tags: ruby, html, xml, parser, oga
description: "Oga is an XML/HTML parser written in Ruby"
---

In the Ruby ecosystem there are plenty of HTTP libraries. Net::HTTP, HTTParty,
HTTPClient, Patron, Curb, Excon, Tyhpoeus, just to name a few. There are so many
of them it's almost as if it's required that one writes an HTTP client in order
to call themselves a Ruby developer.

When it comes to XML/HTML parsing on the other hand the options are quite
limited. The two most common libraries are Nokogiri and REXML. Both these
libraries however have various flaws that makes working with them less than
pleasant. REXML is generally quite slow, only supports XML and can use quite a
chunk of memory when parsing data.

Nokogiri on the other hand is quite fast, but in turn is not thread-safe and in
certain places has a bit of an odd API. Nokogiri also vendors its own copy of
libxml which greatly increases install sizes and times. Most important of all,
Nokogiri simply doesn't work on Rubinius.

So what exactly is the problem with Nokogiri and Rubinius? Well, on MRI and
Rubinius Nokogiri will use a C extension. This extension in turn uses libxml.
Due to MRI having a GIL everything might appear to be working as expected,
however on Rubinius all hell breaks loose. To be exact, at certain points in
time bogus data (e.g. null pointers) are sent to the garbage collector, this in
turn crashes Rubinius. Both I and Brian Shirai ([brixen][brixen]) have spent
quite some time trying to figure out what the heck is going on, without any
success so far. The exact details of all this can be found in the following
Nokogiri issue: <https://github.com/sparklemotion/nokogiri/issues/1047>.

This particular problem is thus severe that some of the production applications
I've tested (that use Nokogiri heavily) consistently crash around 30 seconds
into the process' lifetime. As a result it's impossible for me to run these
applications on Rubinius. If a process were to crash once every few days I might
be able to live with it while searching for a solution, every 30 seconds however
is just not an option.

All of this prompted me to start working on an alternative, an alternative that
doesn't require complicated system libraries or Ruby implementation specific
codebases. For the past 8 months I've been working on exactly that. I've called
the project Oga, and it can be found on GitHub:
<https://gitlab.com/yorickpeterse/oga>. Today, 199 days after the first Git
commit, I'll be releasing the first version on RubyGems.

Oga is primarily written in Ruby (91% Ruby according to Github), with a small
native extension for the XML lexer. It supports parsing of XML and HTML, comes
with XPath expressions, support for XML namespaces and much more. It works on
MRI, Rubinius and JRuby and doesn't require large system libraries. This in turn
means smaller Gem sizes and _much_ faster installation times. For more
information, see the [Oga README][readme].

Oga can be installed from RubyGems as following (the installation process should
only take a few seconds):

    gem install oga

Once installed you can start parsing XML and HTML documents. For example, lets
parse the Reddit frontpage and get all article titles:

```ruby
require 'oga'
require 'net/http'

body     = Net::HTTP.get(URI.parse('http://www.reddit.com/'))
document = Oga.parse_html(body)
titles   = document.xpath('//div[contains(@class, "entry")]/p[@class="title"]/a/text()')

titles.each do |title|
  puts title.text
end
```

Because Oga is a very young library there is a big chance you'll bump into bugs
or other issues (I'm going to be honest here). For example, HTML parsing is not
yet as solid as it should be (<https://gitlab.com/yorickpeterse/oga/issues/20>),
Oga also does not yet honor the encoding set in the document itself
(<https://gitlab.com/yorickpeterse/oga/issues/29>). If you happen to run into
any problems/bugs, please report these at the [issue tracker][issue-tracker].
Feedback and questions are also more than welcome.

Personally I'm really excited about what Oga currently is and what it will
become (it also seems other share that sentiment). I was not expecting it to
take nearly 8 months to write such a library, but looking back at everything it
was more than worth the effort.

And last, I'd like to thank the following people:

* [Peter Zotov][whitequark]: for helping me out with Ragel numerous times
* [Brian Shirai][brixen] for debugging the initial problems with Nokogiri as
  well as his support of the project in general
* [Charles Nutter][headius] for helping me out with getting a new version of
  Racc released, his interest in profiling/benchmarking Oga and his support of
  project in general
* Countless of other people that have shown great interest ever since I started
  working on Oga

[brixen]: https://github.com/brixen
[readme]: https://gitlab.com/yorickpeterse/oga/blob/master/README.md
[issue-tracker]: https://gitlab.com/yorickpeterse/oga/issues/new
[whitequark]: https://github.com/whitequark
[headius]: https://github.com/headius
