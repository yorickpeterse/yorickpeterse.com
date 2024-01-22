---
{
  "title": "Oga 1.0 Released",
  "date": "2015-05-20T21:00:00Z"
}
---
<!-- vale off -->

Until now if one wanted to parse XML and/or HTML in Ruby the most common choice
would be [Nokogiri][nokogiri]. Nokogiri however is not without its problem,
[as I have discussed in the past][oga-announce]. Other existing alternatives
usually only focus on XML (such as Ox and REXML), making them unsuitable for
those in need of HTML support.

Starting today Ruby developers will be able to use a solid alternative as I'm
happy to announce that 449 days after the very [first commit][first-oga-commit]
Oga 1.0 has finally been released.

Version 1.0 of Oga will be the first version to be considered stable per
[semantic versioning 2.0][semver]. This doesn't mean it will be bug free, it
just means the API is not meant to change in backwards incompatible ways between
minor releases. While Oga is already being used in production for a while I was
reluctant to increment the version to 1.0 until at least proper HTML5 support
was introduced.

A lot has changed over the last 16 months. The old Racc parsers have been
replaced by LL(1) parsers using [ruby-ll][ruby-ll], support was added for HTML5,
XML/HTML entity conversion, handling of invalid XML/HTML, better SAX parsing,
Windows support and much more.

The exact list of changes can be found in the [changelog][changelog]. If you
want to jump straight to trying out Oga you can install it from RubyGems:

```
gem install oga
```

Oga doesn't depend on libxml so the installation process should only take a few
seconds.

Oga's Git repository is located at <https://gitlab.com/yorickpeterse/oga>, the
documentation can be found at <http://code.yorickpeterse.com/oga/latest/>. Those
interested in migrating from Nokogiri can use to the guide
["Migrating From Nokogiri"][migrating-nokogiri].

[semver]: http://semver.org/spec/v2.0.0.html
[changelog]: http://code.yorickpeterse.com/oga/latest/file.CHANGELOG.html
[nokogiri]: http://www.nokogiri.org/
[oga-announce]: /articles/oga-a-new-xml-and-html-parser-for-ruby/
[first-oga-commit]: https://github.com/YorickPeterse/oga/commit/6326bdd8c943299e9adc4d2cb6de00934da3609b
[ruby-ll]: https://gitlab.com/yorickpeterse/ruby-ll
[migrating-nokogiri]: http://code.yorickpeterse.com/oga/latest/file.migrating_from_nokogiri.html
