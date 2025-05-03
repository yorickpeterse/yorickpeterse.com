---
{
  "title": "Resume",
  "created": "2021-12-03 15:50:00 UTC"
}
---

## Free and open-source software

A non-exhaustive list of the Free and Open Source Software projects that I work
on or have worked on in the past:

- [Inko](https://inko-lang.org): a statically typed, object-oriented programming
  language focusing on concurrency and safety; inspired by Ruby, Smalltalk,
  Erlang and Rust.
- [GitLab](https://about.gitlab.com/): a complete CI/CD toolchain in a single
  application.
- [libbfi-rs](https://github.com/tov/libffi-rs): Rust bindings for libffi.
- [Oga](https://github.com/yorickpeterse/oga): an XML/HTML parser for Ruby with
  XPath and CSS support.
- [ruby-ll](https://github.com/yorickpeterse/ruby-ll): an LL(1) parser generator
  for Ruby.
- [ruby-lint](https://github.com/yorickpeterse/ruby-lint): a static code
  analysis tool for Ruby.
- [Rubinius](https://github.com/rubinius/rubinius): an implementation of the
  Ruby programming language.
- [OpeNER](http://www.opener-project.eu/): natural language processing framework
  for 6 different languages.
- [Ramaze](http://ramaze.net/): a simple, light and modular open-source web
  application framework written in Ruby.
- [Pry](https://github.com/pry/pry): a popular REPL for Ruby.

## Employment history

### GitLab B.V.

|=
| Period
| Title
|-
| October 2015 until December 2021
| Staff backend engineer

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

### Olery B.V.

|=
| Period
| Title
|-
| December 2012 until October 2015
| Backend developer

Olery is/was (as of December 2021 they still exist, but I'm not sure in what
state) a company/platform for collecting and analysing online review data from
websites such as Booking.com, TripAdvisor, and dozens of others. I worked as
part of a small development team on all aspects of the platform. Notable
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
