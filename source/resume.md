---
{
  "title": "Resume",
  "created": "2021-12-03 15:50:00 UTC"
}
---

I am a software developer with 15 years of working experience, with a focus on
high performance concurrent and distributed systems, compilers, and virtual
machines. I'm based in The Netherlands and speak both Dutch and English.

I have experience working with a variety of tools and languages, such as Rust
(since 2015), Ruby (since 2012), C, Lua, the usual Unix tools (perf, Bash, etc),
and more. I primarily work on Linux based systems, but have also used macOS
extensively in the past, and have (albeit limited) experience with FreeBSD.

For communication I prefer written and asynchronous communication, and prefer to
work out in the open (whenever possible) instead of behind closed doors. I've
worked for both small and large organizations, though I prefer smaller ones as I
believe this makes it easier to develop a good connection with your colleagues.

::: page-break
:::

## Work experience

### The Inko programming language

|=
| Period
| Title
|-
| January 2022 - Present
| Lead developer/author

[Inko](https://inko-lang.org/) is a programming language that I've been working
on since 2015, initially in my spare time and full-time since December 2021.
Inko is a compiled and statically typed programming language, focused on making
it easier to write concurrent and distributed applications, and uses
compile-time memory management without relying on runtime garbage collection.

Inko uses a small runtime library written in Rust, used for scheduling threads
and performing various other low-level operations. The compiler is also written
in Rust, while everything else (e.g. the standard library) is written in Inko
itself.

::: page-break
:::

### GitLab

|=
| Period
| Title
|-
| October 2015 until December 2021
| Staff backend developer

During my time at GitLab I worked on optimising application performance,
building and growing GitLab's database team, improving GitLab's release tooling
and release process, and more. Notable projects include:

- Merging the two different codebases for GitLab CE and GitLab EE into a single
  project, an effort that took over nine months to complete and improved the
  workflow of hundreds of GitLab developers. Some more information can be found
  [in this
  article](https://about.gitlab.com/blog/2019/02/21/merging-ce-and-ee-codebases/)
  and [in this GitLab epic](https://gitlab.com/groups/gitlab-org/-/epics/802).
- Improving release tooling and workflows, reducing the time it takes to deploy
  to GitLab.com from several weeks to a matter of hours.
- Building a chatops solution that allows GitLab employees to run a variety of
  commands directly from Slack, such as starting the release process of a new
  GitLab version, or enabling a feature flag.
- A new changelog workflow that uses Git trailers instead of YAML files, making
  it easier for developers to add entries to the changelog.
- [A custom database load
  balancer](https://docs.gitlab.com/ee/administration/postgresql/database_load_balancing.html#database-load-balancing)
  with support for balancing read-only queries across different databases,
  automatic service discovery of new database hosts, and improved handling of
  database connection errors and timeouts. As of December 2021, the load
  balancer setup for GitLab.com handles over 300 000 queries per second.
- Building a solution for database migrations that makes it possible to deploy
  GitLab without downtime, both for GitLab.com and self-hosted installations.
- [Solving GitLab's scaling and performance problems]{del} [Removing
  GitLab.com's production database by accident](https://about.gitlab.com/blog/2017/02/01/gitlab-dot-com-database-incident/),
  only to find out our backups hadn't been working for months. We recovered with
  "only" six hours of data loss, then spent several months working to ensure
  this would not happen again. A post-mortem of this [is found
  here](https://about.gitlab.com/blog/2017/02/10/postmortem-of-database-outage-of-january-31/).

::: page-break
:::

### Olery

|=
| Period
| Title
|-
| December 2012 until October 2015
| Backend developer

Olery is a company/platform for collecting and analysing online review data from
websites such as Booking.com, TripAdvisor, and dozens of others. I was the first
developer to be hired on a full-time basis (apart from the CTO). Notable
projects include:

- Rebuilding all web scrapers from the ground up using modern development
  practises, rather than outsourcing the development. This resulted in a massive
  increase of reliability and performance of the scrapers.
- Setting up continuous integration and development pipelines using Jenkins,
  making it possible to deploy our software to dozens of servers in a matter of
  minutes.
- Replacing the use of [MongoDB with PostgreSQL](https://archive.md/ScSgG),
  drastically improving performance and stability of the platform.
- [A natural language processing pipeline](https://archive.md/aHvmY), used for
  sentiment analysis in six different languages.
- Improved performance of the platform, reducing AWS hosting costs by several
  thousands of US dollars per month.

::: page-break
:::

### Isset Internet Professionals

|=
| Period
| Title
|-
| June 2010 until November 2012
| Backend developer

Isset is a small web development agency based in Hilversum, The Netherlands.
Notable projects include:

- Setting up and maintaining an internal [Redmine](https://www.redmine.org/)
  instance for project management.
- Building and maintaining an internal platform for managing over 3000 customer
  domain names using PowerDNS.
- A metrics aggregation application for radio/TV broadcasters and advertisers,
  allowing them to analyse the impact of their advertisements.

::: page-break
:::

## Free and open-source software

A non-exhaustive list of the Free and Open Source Software projects that I work
on or have worked on in the past:

- [Ghostty](https://github.com/ghostty-org/ghostty): a fast, feature-rich, and
  cross-platform terminal emulator that uses platform-native UI and GPU
  acceleration
- [GitLab](https://about.gitlab.com/): a complete CI/CD toolchain in a single
  application
- [Inko](https://github.com/inko-lang/inko): a language for building concurrent
  software with confidence
- [Neovim](https://github.com/neovim/neovim): a Vim fork focused on
  extensibility and usability
- [Oga](https://github.com/yorickpeterse/oga): an XML/HTML parser for Ruby with
  XPath and CSS support
- [Pry](https://github.com/pry/pry): a popular REPL for Ruby
- [Ramaze](https://github.com/Ramaze/ramaze): a simple, light and modular
  open-source web application framework written in Ruby
- [Rubinius](https://github.com/rubinius/rubinius): an implementation of the
  Ruby programming language
- [libbfi-rs](https://github.com/tov/libffi-rs): Rust bindings for libffi
- [ruby-lint](https://github.com/yorickpeterse/ruby-lint): a static code
  analysis tool for Ruby
- [ruby-ll](https://github.com/yorickpeterse/ruby-ll): an LL(1) parser generator
  for Ruby

For more details, refer to my public [GitHub
profile](https://github.com/yorickpeterse).

## Public speaking

<!-- vale off -->

- [The Inko Programming Language, and Life as a Language Designer](https://www.youtube.com/watch?v=IH2i1PgO7sM) (2024)
- [Compiling pattern matching](https://github.com/yorickpeterse/presentations/tree/master/compiling_pattern_matching) (2023, recording unavailable)
- [Making GitLab Faster](https://www.youtube.com/watch?v=eYwSXDcXO6E) (2016)
- [Garbage Collection Crash Course](https://www.youtube.com/watch?v=JwuQ7rsHHf4) (2016)
- [Oga and Parsing](https://www.youtube.com/watch?v=NPPzUvyZB-I) (2015)

<!-- vale on -->
