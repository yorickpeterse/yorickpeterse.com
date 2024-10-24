---
{
  "title": "Thoughts on data migrations that scale",
  "date": "2024-10-24T00:00:00Z"
}
---

Recently I read about a new Rust web framework called
[rwf](https://github.com/levkk/rwf). I was especially curious about its approach
to handling database migrations, as many frameworks released in recent years
tend to either overlook this or provide a mechanism that won't scale to larger
projects. Reading through the documentation I learned that rwf falls in the
second category: it generates two SQL files, one for migrating forward and one
for migrating backwards, and evaluates the appropriate files based on the
migration direction.

The problem here isn't necessarily the choice of using SQL (though it certainly
doesn't help), but rather that the system is built in such a way that it becomes
useless the moment your team and/or database starts growing in size.

I've been thinking about what a better solution to data migrations might look
like for a while, so let's explore my current thoughts on the subject.

## Defining a shared vocabulary

Since developers love to argue about terminology rather than focusing on the
subject as a whole, we'll start off with defining a few terms so it's clear what
we're talking about.

A **database** is a _relational_ database in the context of this article, so
something like PostgreSQL or SQLite. While technically much of what we'll
discuss here also applies to document-oriented databases such as MongoDB, I'll
be focusing on relational databases.

An **application** is a program that uses the database and is exposed to the
users. I assume no further explanation is needed for this particular term.

A database is considered **large** when conventional ways of mutating it, both
when changing its structure and content, requires a significant amount of time
and a non-conventional approach to reduce the time necessary to make the
changes.

The **application data** is the data and data structure the application needs,
such as the data in a database or elsewhere (e.g. AWS S3).

A **migration** is a function that transitions the application data from state A
to B.

Migrations move in a particular **direction**: **up** to move forward in time (=
apply the changes), and **down** to move backwards in time (= revert the
changes).

A **migration process** is the act of running one or more migrations.

## Defining the requirements

With the terminology out of the way, let's define a few requirements our
migration process must meet.

1. **I must be timeless:** given application data in a past state S~1~, we must
   be able to migrate it to a future state S~N~, or the other way around.
1. **It must be scalable:** we must be able to migrate not just the structure of
   the database, but also its data and ideally also non-database data. It must
   also support both small and large databases.
1. **It must be easy to use:** the migration process must be automated (rather
   than requiring many manual steps), easy to trigger, easy to understand, and
   easy to monitor while it's running.
1. **It must be possible to prove the system is correct:** given a migration, it
   must be possible to determine that it in fact works. Or in plain English: it
   should be easy to write tests for a migration.

There may be more requirements depending on your needs, but these are the ones
I'll consider as part of this article.

## A real-world example

To help better understand what we'll be dealing with, let's look at a real-world
example of a sufficiently complex piece of software:
[GitLab](https://about.gitlab.com/).

GitLab started as a GitHub clone with only a few developers working on it. For
performing database migrations, it uses the migration framework provided by
[Ruby on Rails](https://rubyonrails.org/). As GitLab's popularity and the number
of features it offered grew, so did the size of its database. When I joined
GitLab in 2015, the size of the GitLab.com database was somewhere around 200-300
GiB. By the time I left in December 2021, it had grown to 1-2 TiB. We did manage
to briefly shrink the database to a size of zero, but only because [I
removed the entire production database by
accident](https://about.gitlab.com/blog/2017/02/01/gitlab-dot-com-database-incident/).

Jokes aside, this growth in size meant that the traditional approach of running
database migrations was no longer suitable. For example, renaming a column was
no longer possible for large tables as it would take far too long to complete.
Similarly, migrating data from format A to format B could easily take weeks to
complete when performed using the traditional Rails approach.

Solving these problems required separate solutions. These are as follows:

1. We split migrations into "pre-deployment" and "post-deployment" migrations.
   Pre-deployment migrations run _before_ deploying code changes, and were only
   allowed to make backwards compatible changes (e.g. adding a column).
   Post-deployment migrations run _after_ deploying code changes, and were
   typically used for cleaning up past migrations (e.g. removing a column that's
   no longer in use).
1. Database migrations were no longer allowed to reuse application logic (e.g.
   Rails models) and instead had to define the classes/methods they needed
   themselves. The result is that migrations are essentially a snapshot of the
   code they need to run, making them more reliable and isolated from the rest
   of the application.
1. For large scale data migrations (the kind of migration that can take days or
   weeks to run) we scheduled jobs running in the background using
   [Sidekiq](https://github.com/sidekiq/sidekiq). These migrations could take
   days or even weeks to complete. A future deployment would then include a
   migration to check if all work is performed (performing it if this isn't the
   case), then perform the necessary cleanup work.

While this setup allowed GitLab to migrate both small and large tables as well
as data stored outside the database, it highlights several problems with the
migration system provided by Rails:

- It only provides basic primitives for making structural changes, but provides
  nothing to scale beyond that.
- It doesn't provide anything to ensure the process is timeless, i.e. there's
  nothing stopping you from depending on application logic that may change in
  unexpected ways, breaking the migration in the process.
- Rails provides nothing for writing tests for migrations, requiring you to roll
  your own solution.

There are also problems with the setup used by GitLab:

- GitLab's setup isn't timeless: while we tried to isolate migrations as much as
  possible, sometimes this would involve duplicating so much code we opted to
  reuse the application logic instead. Reverting migrations also proved
  challenging, and in plenty of instances straight up didn't work at all in our
  production environment.
- The introduction of background migrations and the lack of good monitoring
  made the system anything but easy to understand and monitor.
- GitLab's combination of being both a SaaS and an application that's released
  periodically for self-hosting purposes means it wasn't truly timeless, and
  instead only allowed you to upgrade across different minor versions of the
  same major version. That is, you can upgrade from version 1.2.3 to
  version 1.8.7, but not from version 1.2.3 to version 2.1.0.

While the resulting situation isn't ideal, I believe it's the best we could
come up with at the time given all the constraints we had to deal with.

If somebody were to create a framework or application from scratch, we can do
better than this, but this requires that we first understand the problems
existing solutions face.

## Problems faced by existing solutions

The first problem is that existing migration systems make the assumption that
the existence of a migration implies it's timeless, and that it will therefor
always work. If all the migration does is creating a table or column then that
is likely true, but for anything more complex this is no longer the case.
Isolating a migration from the application it's a part of may help, but there
will be plenty of cases where this just isn't practical due to the code
duplication this requires. Even if the amount of code that has to be duplicated
is small, it can add up when you have to do it many times for different
migrations.

What we need is a way to capture some sort of snapshot of the application logic
at the time the migration is written, then run the migration using that
snapshot. This ensures we can always migrate up or down, as migrations are
always run against a known state. This is similar to [minimal version
selection](https://research.swtch.com/vgo-mvs) ensuring a dependency always uses
the minimal version that satisfies its requirements, instead of the maximum
version.

The second problem is that to build a migration system that scales, you must
understand what that actually means, which in turn means you must've felt the
pain of dealing with a system that _doesn't_ scale. For whatever reason it seems
that the people building new migration systems (or the frameworks they're a part
of) don't have such experience or just don't care for it, resulting in setups
only capable of catering towards the most basic of scenarios.

The people who _do_ have the necessary experience in turn don't seem to be
interested in building a better solution, perhaps because they've burned out on
the subject. I certainly had no energy to think about this subject the first 1-2
years after leaving GitLab.

The third problem, and one that's related to the second problem, is that there
aren't many projects that will grow large enough such that they need more
sophisticated solutions to migrating their data. As a result, there's not enough
of a push to come up with something better than the current status quo.

The fourth problem is that different projects have different requirements for
applying their data migrations, and these requirements may result in different
solutions. A mobile application using a small SQLite database is going to
migrate its data in a way different from a SaaS application using a 10 TiB
database, and building a solution that works for both may prove difficult.

## How do we build something better?

Now that we've defined a set of requirements, discussed a real-world example to
better understand what we're dealing with, and listed several problems faced by
existing solutions, what would a better solution look like?

For applications deployed to controlled environments (i.e. _not_ a mobile
application deployed to phones you have no control over), I _think_ I have a
rough idea. What follows is only appliccable to deployments to controlled
environments.

### Migrations must be functions

As I've hinted at before, migrations should be _functions_. Functions as in "a
function written in a programming language", not functions as in "SQL snippets I
just refer to as functions because it makes me sound smart". This means they're
written in something like Ruby, Lua, Rust, or whatever language you prefer. I
would like to say this seems obvious, but the fact that new frameworks and
database toolkits (rwf, [Diesel](https://diesel.rs/), and probably many more)
tend to only support SQL files/expressions for migrations seems to suggest
otherwise.

A function should be provided for both directions, such that one doesn't need to
write a new migration to undo the changes of a previous migration. This allows
for fast rollbacks in production environments if it's determined that a
migration broke things. This does of course assume you can in fact revert the
migration (i.e. data isn't mutated in a non-reversible manner), which
unfortunately isn't always the case. Even if you revert by creating a new
migration to undo the relevant changes, having a separate "down" function is
still useful for testing purposes and development environments.

### Run migrations against specific VCS revisions

Migrations should be run against specific VCS revisions rather than whatever the
latest revision is. For this to work you need to maintain a file of sorts that
tracks the migrations to run along with the revisions to run them against. This
also means there's a two-step process to creating migrations:

1. First you create the migration, test it, etc, then you commit it.
1. You record this revision in the migration revision file and commit that in a
   separate commit.

While this may seem annoying, it's trivial to automate the second step such that
it shouldn't be a problem in practice.

To perform the migration process, the migration system determines the range of
migrations to run based on the system's current state and the desired state,
resulting in the migration range \[M~1~, M~2~, …, M~N~\]. For each migration in
this range, the system checks out the corresponding revision and then runs the
migration against the revision. Once the process is done, the system checks out
the initial revision again.

By running the migration against a known revision of the code we ensure that
it's timeless, even when it reuses application logic defined outside of the
migration. This also means we remove the need for duplicating any application
logic the migration may need to perform its work, making it easier to write,
review and maintain the migration. Another nice benefit is that we're free to
remove the migration once we no longer need it, rather than keeping it around
for an unspecified amount of time, because as long as it's still tracked in the
migration revision file we can still run it.

### Split migrations into pre and post-deployment migrations

Migrations need to be split into pre-deployment and post-deployment migrations
similar to GitLab's approach. This allows you to use the pre-deployment
migrations for additions and other backwards compatible changes, while using
post-deploymeng migrations for those that first require code changes. A simple
example is removing renaming a column: a pre-deployment migration adds the new
column and copies over its data (and maybe installs a trigger to keep the two in
sync). The deployment updates the code to start using the new column, and the
post-deployment migration (running after the code is deployed) removes the
column.

### Provide the means for running large data migrations

Dealing with large data migrations is a more difficult problem to solve. This
would require at least the following:

1. The ability to distribute the workload across multiple hosts in a fork-join
   manner: the migration schedules N jobs across M hosts and waits for these to
   complete before moving on.
1. The ability to also run these background jobs against a specific revision,
   such that they too are free to use application logic in a known stable state.
1. The ability to flag a deployment as "not blocking", meaning future
   deployments won't have to wait for it to finish, thereby allowing you to
   continue deploying. This requires scheduling of background migrations _after_
   completing all pending pre and post-deployment migrations, ensuring a future
   deployment doesn't cause problems (e.g. by using a column not yet present).
   I'm not yet sure how you'd go about enforcing this.

This does come with the (potentially unfortunate) requirement that you also
provide (or depend on) a background processing system of some sort (i.e.
Sidekiq). For a full-stack framework that might not be a problem, but for e.g. a
standalone database toolkit this may not be desirable.

An important requirement here is that the deployment must not finish until the
background jobs complete their work. This makes monitoring easier as the
migration in charge of the background jobs can report its progress by e.g.
writing to STDOUT, which is then collected as part of the deployment
output/logs. This also makes it easier to reason about the system: when a
deployment is done, so is all its work, rather than there being an unspecified
number of jobs still running in the background.

### Make it easy to test migrations

A set of primitives should exist to make it easy to write tests for migrations,
such that one can verify they in fact work as intended. For example, there
should be a primitive that migrates the test database to the expected starting
state and back, so you can test the migration against the expected initial state
instead of the latest state.

This is probably the least exciting idea, but the fact this isn't widely done
suggests it's not as obvious as I'd like it to be.

## Conclusion

The above is just a rough idea of what I think that can be done to provide a
better migration system. I think the idea of running migrations against known
VCS revisions is especially interesting and worth exploring further. Perhaps
I'll explore this in the future if I ever get around to building a web framework
in [Inko](https://inko-lang.org/).
