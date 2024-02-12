---
{
  "title": "What it was like working for GitLab",
  "date": "2024-02-08T19:00:00Z"
}
---

I joined GitLab in October 2015, and left in December 2021 after working there
for a little more than six years.

While I previously wrote [about leaving
GitLab](/articles/im-leaving-gitlab-to-work-on-inko-full-time/) to work on
[Inko](https://inko-lang.org/), I never discussed what it was like working for
GitLab between 2015 and 2021. There are two reasons for this:

1. I was suffering from burnout, and didn't have the energy to revisit the last
   six years of my life (at that time)
1. I was still under an NDA for another 24 months, and I wasn't sure how much I
   could discuss without violating it, even though it probably wouldn't have
   caused any problems

The NDA expired last December, and while I suspect I'm still dealing with the
fallout of a burnout, I have a bit more energy to revisit my time at GitLab.

I'll structure this article into two main sections: an overview of my time at
GitLab based on what I can still remember, and a collection of things I've
learned as a result of my work and experiences.

## [Table of contents]{toc-ignore}

::: toc
:::

## Before GitLab

Before joining GitLab, I was working for a small startup based in Amsterdam.
Like most startups, in the months leading up to my departure the company started
to run out of money and had to resort to some desperate solutions, such as
renting out part of the office space to cover the costs. At the same time, I
felt I had done all the things I wanted to and could do at a technical level.

In parallel to this, I was also working on
[Rubinius](https://github.com/rubinius/rubinius) in my spare time, and we had
considered using it on various occasions, going as far as making sure all our
code ran on it without any problems. This also lead to the creation of
[Oga](https://github.com/yorickpeterse/oga), an XML/HTML parsing library acting
as an alternative to Nokogiri.

Unfortunately, the lack of funding combined with various technical problems
meant that we never pursued the use of Rubinius further. Because of all these
factors, I started looking for a job where I could spend at least some more time
working on Rubinius in hopes of making it stable enough for people to use in a
production environment.

During this time I attended various Ruby meetups in Amsterdam, and helped out
with a few [Rails Girls](https://railsgirls.com/) workshops. At one of these
workshops I ran into [Sytse](https://sytse.com/) and his wife, and once again at
a later workshop or meetup (I think, I can't quite remember as it's been a long
time). Through this I learned about GitLab, and developed an interest in working
there.

Some time in the summer of 2015 I sent Sytse an Email, stating I wanted to work
for GitLab and asking if they were willing to sponsor me working on Rubinius one
day per week. The conversation and interviews that followed resulted in me
starting at GitLab in October 2015 as employee #28. My task was to improve
performance of GitLab, and allowed me to spend 20% of my time on Rubinius.

During my time I was a part of various teams, had a lot of autonomy, reported to
10 different managers over the years, nearly wiped the company out of existence,
built various critical components that GitLab still uses to this day, saw the
company grow from 30-something employees to around 2000 employees, and ended up
with a burnout. Or as the Dutch saying goes: "Lekker gewerkt, pik!" (good luck
translating that).

## 2015-2017

My last day at the company before GitLab was September 30, a Wednesday, followed
by starting at GitLab the next day. This meant I went from working in an office
five days per week to working remote five days per week. While I had worked from
home before, mainly when the trains weren't running due to a tiny amount of snow
or leaves on the tracks, it took a bit of adjusting to the new setup.

A particular memory from this time that stands out is carrying a bag of
groceries home during the day, and realizing how nice it's to do that during the
day instead of in the evening after coming home from work.

Another memory is taking a nap on my sofa with my cat, of which I took this
picture at the time:

![My cat judging me while I try to take a nap](/images/what-it-was-like-working-for-gitlab/sofa_cat.jpg)

Yes, those are Homer Simpson slippers.

The apartment I was renting at the time wasn't large and only had a small
kitchen area, a small living room, and a similarly small attic. This meant that
my living room functioned as my bedroom, living room, and office all at once. It
wasn't a great setup, but it was all I could afford at the time. Perhaps the
expensive Aeron chair had something to do with it.

In spite of being an all remote company, GitLab was a social company, with
frequent meetups and events taking place over the years. For example, a few
weeks after I joined there was a company gathering in Amsterdam, involving
various activities during the day and dinners in the evening:

![A dinner with everybody at GitLab](/images/what-it-was-like-working-for-gitlab/amsterdam_dinner.jpg)

Back then you could still fit the entire company in one corner of a restaurant.

Not long after, GitLab had its first growth spurt, resulting in somewhere around
100 new employees (I think? My memories are a bit fuzzy at this point). At the
next company gathering in Austin in 2016, a single corner in a restaurant was no
longer enough:

![The company gathering in Austin, Texas](/images/what-it-was-like-working-for-gitlab/austin_gathering.jpg)

During this time there were also plenty of negative experiences. GitLab suffered
from terrible performance, frequent outages (almost every week some), poor
management, and many other problems that startups face. This lead to "GitLab is
slow" being the number one complaint voice by users. Especially on Hacker News
people just _loved_ to complain about it, no matter what the original topic
(e.g. some new feature announcement) might've been. Of course GitLab was aware
of this, and in fact one of the reasons GitLab hired me was to resolve these
problems.

Resolving these problems proved a real challenge, in particular because GitLab
had no adequate performance monitoring infrastructure. That's not an
exaggeration by the way: the only service running at the time was a New Relic
trial account that only allowed monitoring of one, _maybe_ two servers out of
the (I think) total of 15-20 servers we had at the time. This meant that
whatever data did come in wasn't an accurate representation, and made measuring
and solving performance a challenge.

What made solving these problems extra  difficult was GitLab's requirement that
whatever tooling we'd use had to be available to self-hosted customers, and
preferably be open source (or perhaps this was even a hard requirement, I can't
remember). This meant I had to not only improve performance, but also build the
tools to improve performance in the first place. At the same time, writing
performant code (or code that at least isn't horribly slow) wasn't at all
considered a priority for the rest of the company. GitLab also had a tendency to
listen more to complaints on Hacker News than internal complaints. This lead to
an internal running joke that it if you wanted something to change, you'd have
better luck complaining about it anonymously on Hacker News instead of bringing
it up through the proper channels.

What followed was several months of me trying to improve performance, build the
tooling necessary for this, try to change the company culture/attitude towards
performance such that things would actually improve over time, and deal with
GitLab not being happy with the improvements made. I distinctively remember
there being at least several video calls in which I was close to yelling at
Sytse, though it fortunately never came to that.

In spite of these challenges I did manage to build the necessary tooling, and
improve performance in various parts (some of which were significant, others not
so much). This tooling became an official GitLab feature known as ["GitLab
Performance Monitoring"](https://docs.gitlab.com/ee/administration/monitoring/performance/),
though it has changed quite a bit over the years. Another tool I built was
["Sherlock"](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/1749), a
heavy-weight profiler meant to be used in a development environment.

During this time, GitLab started to realize you can't solve these sort of
problems by just hiring one person, especially if performance isn't a priority
for the rest of the company. One of the changes this lead to was that instead of
reporting directly to Sytse, I would report to a dedicated manager as part of
the new "Performance" team, and the team had a budget to hire more people. I
don't remember exactly what the budget was, but it wasn't much: two, _maybe_
three people I think. This wasn't nearly enough given the total size of the
company and it's primary focus being producing as many features as possible, but
it was a start.

Much of my second year I spent as part of this team, now with a bit more room to
breathe. I continued campaigning for more resources and making good performance
a requirement for new code, but with mixed results, and of course I and the team
as a whole continued improving performance.

During this time GitLab also saw its first wave of lay-offs and people leaving
by their own will, mainly as a result of GitLab hiring the wrong people in the
first place. This meant that GitLab grew from 30-something to (I think)
130-something people, only to shrink back to 80-something people, only to start
growing again in the months to come.

As for Rubinius: while we tried to get GitLab to work on Rubinius, we never
succeeded. Combined with the maintainer of Rubinius wanting to take the project
in a different direction and the controversies this lead to within the Ruby
community, we ultimately decided to give up on Rubinius, and I stopped working
on it entirely. It's unfortunate, as Rubinius had a lot going for it over the
years but was ultimately held back by the maintainers running the project in a
way different from what was necessary for it to become successful.

## 2017-2018

![South Africa summit in 2018](/images/what-it-was-like-working-for-gitlab/sytse_giraffe.jpg)

After the first rocky 1,5 years, things started to improve. Performance had
improved greatly, and GitLab was starting to take it more seriously. Hiring
processes were much improved, and like a game of chess GitLab started moving the
right people into the right places. The scope of the performance team also
changed: instead of focusing on performance in general, the team would focus on
database performance and as part of this was to be renamed to the creatively
called "Database team". With this change also came a bigger budget for hiring
people, and infrastructure engineers assigned to help us out with e.g. setting
up new databases.

A critically important feature I built during this time is [GitLab's database
load balancer](https://docs.gitlab.com/ee/administration/postgresql/database_load_balancing.html)
([announced here](https://about.gitlab.com/blog/2017/10/02/scaling-the-gitlab-database/)).
This feature allowed developers to continue to write their database queries as
usual, while the load balancer would take care of not directing these queries to
either a replica or a primary. After performing a write, the load balancer
ensures the primary database is used until the written changes are available to
all replicas, an act commonly referred to as "sticking". The introduction of the
load balancer had a significant and positive impact on performance, and I'm
certain GitLab would've been in a lot of trouble if it wasn't for this load
balancer. What I'm most proud of is being able to introduce this system
transparently. To date I've not seen a database load balancer (let alone for
Ruby on Rails) that you can just add to your project and you're good to go.
Instead, existing solutions are more like frameworks that only provide a small
piece of the puzzle, requiring you to glue everything together yourself, often
without any form of sticking support. It's a shame we never got to extract it to
a standalone library.

This period wasn't just one of incredible productivity and improvements, it also
marked the lowest and scariest moment of my time at GitLab and my career as a
whole: on January 31st, after a long and stressful day of dealing with many
issues that continued well into the late evening, I [solved GitLab's performance
problems]{del} [removed GitLab's production database by
accident](https://about.gitlab.com/blog/2017/02/01/gitlab-dot-com-database-incident/).
This then lead to the discovery that we didn't have any backups as a result of
the system not working for a long time, as well as the system meant to notify us
of any backup errors not working either. In the end we did recover, as I had
copied the production data to our staging environment about six hours prior as
part of the work I was doing that day, though the recovery process took around
24 hours. While about six hours of data loss is by all accounts terrible, I'm
not sure what would've happened if I hadn't made that backup. Suffice to say, my
heart skipped a few beats that day, and I'm certain I instantly grew a few extra
grey hairs.

A recurring source of frustration during this time was GitLab's desire to shard
the database, even after the introduction of the database load balancer. Not
only did I and the other engineers and my manager believe this to be the wrong
solution to our problems, we also had the data to back this up. For example,
sharding is useful if writes heavily outnumber reads, but in case of GitLab
reads dominated writes by a ratio along the lines of 10:1. Further, the amount
of data we were storing wasn't nearly enough to justify the complexity of
introducing sharding. I distinctively remember a consultant we'd hired saying
something along the lines of "No offence, but we have customers with several
orders of magnitudes more load and storage, and even for them sharding is
overkill". In spite of this, GitLab would continue to push for this over the
years, until management made the decision to leave it be, only for GitLab to
bring it up _again_ (just using a slightly different name and idea this time)
towards the end of my time at GitLab.

## 2019-2021

![New Orleans summit in 2019](/images/what-it-was-like-working-for-gitlab/new_orleans.jpg)

Some time in 2018-2019 I transitioned from the database team into a newly
founded "Delivery" team, as I had grown tired of working on performance and
reliability for the last four years. Furthermore, multiple people were now
working on performance and reliability, so I felt it was the right time
for me to move on to something new. The goal of this new team was to improve the
release process and tooling of GitLab, as the state of this was at the time best
described as messy.

For example, we looked into how much time there was between a commit landing in
the main branch and deploying the change GitLab.com. The resulting data showed
that on average it would take several days, but in the worst cases it could take
up to _three weeks_. The main bottleneck here was the split between GitLab
Community Edition and GitLab Enterprise Edition, both existing as separate Git
repositories, requiring manual merges and conflict resolution on a regular
basis. This lead to a multi-month effort to [merge the two projects into
one](https://about.gitlab.com/blog/2019/02/21/merging-ce-and-ee-codebases/).
While we divided the work into frontend and backend work, and made various teams
responsible for contributing their share towards the effort, I ended up
implementing most of the backend related changes, with another colleague taking
care of most of the frontend work.

Together with the rest of the team we made significant improvements to the
release process during this period, and we reached a point where we could deploy
changes in a matter of hours. While this is nowhere near as quick as it
should've been, going from a worst-case of three weeks to a worst-case of
_maybe_ a day is a _massive_ improvement.

Like the previous periods, this period was not free of turmoil and changes.

2018 was the last year we had a GitLab summit focused on employees, with 2019
and following years following a format more like a traditional conference, aimed
more at customers and less at employees. From a financial perspective this was
understandable as organizing a gathering of 2000+ people is incredibly
expensive. From a social perspective it was a loss, as the more corporate
setting of the summits wasn't nearly as fun as the old format. I have fond
memories of [Sytse dancing on stage in response to a team winning a
contest](https://youtu.be/39chczWRKws?feature=shared&t=1751), or Sytse and his
wife giving a fitness class while Sytse is wearing a giraffe costume. These sort
of goofy events wouldn't happen any more in the following years.

Then there was the issue of laptop management: people would request a company
Mac laptop and were more or less free to use it how they saw fit, or you'd use
your own hardware like me. Over the years GitLab's management started
discussions about using software to be able to remotely manage the laptops. A
recurring problem in these discussions was that the proposed tools were invasive
(e.g. they could be used to record user activity), didn't contain any guarantees
against abuse, and feedback from employees (of which there was _a lot_) would be
ignored until key employees started applying pressure on management. The plans
would then be shelved, only for the discussion to start all over again months
later.

What stood out the most was not the proposed changes, but rather the way
management handled the feedback, and how the changes in general gave off a vibe
of solutions in search of problems to justify their existence. It's worth
mentioning that most people involved in these discussions (myself included)
understood the need for some form of laptop management (e.g. against theft), but
felt that the invasive solutions proposed went too far.

GitLab did settle on a laptop management solution using
[SentinelOne](https://nl.sentinelone.com/). While GitLab made it a requirement
for employees to install this software on hardware used to access GitLab
resources, including your personal hardware (or at least was considering
requiring that), I (using my own desktop computer) somehow managed to stay under
the radar and was never asked to install the software in question. Perhaps
because I wasn't using a company issued laptop, GitLab just forgot to check up
on me.

These cultural changes combined with various changes in my personal life
resulted in a loss of motivation, productivity, and an increase in stress, and
less consistent working hours. The team's manager (whom I'd consider the best
manager I've ever had) also transitioned to a different role, with a newly hired
manager now leading the team. I didn't get along well with this manager, The
resulting conflict lead to a "performance enablement plan", a procedure meant to
get things back on track before the need for a "performance improvement plan"
(PIP). A PIP is meant to be used as a last attempt at improving the relationship
between an employee, their work, and their employer.

What rubbed me the wrong way was how GitLab handled the PEP: I acknowledged
there were areas I needed to improve upon, but I felt that part of the problem
was the new manager's way of working. Management assured me that the PEP meant
to improve the state of things on both ends, i.e. it wouldn't just focus on _me_
improving but also the manager. That didn't happen, and the PEP focused solely
on what _I_ needed to do differently. The PEP was also a bit vague about what
requirements had to be met. The original plan was for the PEP to last one month,
but by the end of the first month my manager decided to extend the PEP by
another month because they felt this to be necessary, the reasons for which
weren't well specified. I decided to just go along with it, and after two months
passed I completed the PEP and management deemed the results satisfactory.

The optimist in me likes to believe I was just the first employee to be put on a
PEP and thus management had to figure things out as we went along. The pessimist
in me has a far more negative opinion on this series of events, but I'll keep
that to myself.

After this experience I realized that perhaps it was time for me to leave, as
both GitLab and I were heading in different directions, and I was unhappy with
the state of things at the time.

The opportunity for this presented itself towards the end of 2021: GitLab was
going public, and taking into account the time I had to wait before I could
exercise my stock options meant I'd be able to leave in December 2021. I
couldn't leave earlier due to how stock option taxes worked in The Netherlands
at the time: exercising stock options meant having to pay full income taxes
(52%) over the difference between the exercise fee and valuation, even if the
stock isn't liquid. In my case the amount of taxes would be so high I wouldn't
be able to afford it, forcing me to wait until GitLab went public. A few months
later the law changed, and you can now choose to pay the taxes either at the
time of exercise, or when the stock is liquid. The caveat is that if you defer
taxes until the stock is liquid, you pay taxes based on the value at that time,
not based on the value at the time of exercising your stock options. This
certainly isn't ideal and presents a huge financial risk, but at least you have
a choice.

And so with my stocks acquired, I left in December 2021 to work on
[Inko](https://inko-lang.org/) full-time, using my savings to cover my bills.

## What I've learned

With the history out of the way, let's take a look at some things I've learned
from my time at GitLab. One thing to keep in mind is that I'm basing these
findings on my personal experiences, and as such it's not unlikely I'm wrong in
some areas.

### Scalability needs to be part of a company's culture

A mistake GitLab made, and continued to make when I left, was not caring enough
about scalability. Yes, directors would say it was important and improvements
were certainly made, but it was never as much of a priority as other goals. At
the heart of this problem lies the way GitLab makes money: it primarily earns
money from customers self-hosting GitLab Enterprise Edition, not GitLab.com. In
fact, GitLab.com always cost _much_ more money than it brought in. This
naturally results in a focus on the self-hosted market, and many of the
performance problems we ran into on GitLab.com didn't apply to many self-hosted
customers.

What was even more frustrating was that many developers in fact _wanted_ to
improve performance, but weren't given the time and resources to do so.

### Make teams more data and developer driven

Another factor is GitLab's product manager driven nature. While some key
developers may have had the ability to influence product decisions (given enough
screaming and kicking), it was mainly product managers and directors deciding
what needed to be implemented. Sometimes these decisions made a lot of sense,
other times they seemed to be based solely on the equivalent of "I read on
Hacker News this is a good idea, so we have to build it".

I believe GitLab would've been able to perform better as a company if it adopted
a simpler hierarchy early on, instead of the traditional multi-layer hierarchy
it has today. In particular, I think the idea of product managers needs to go in
favour of giving team leads more power and having them interact more with users.
To me, that's ultimately what a "product manager" should do: help build the
product at a technical level, but also act as a liaison between the team and its
users.

### You can't determine what is "minimal viable" without data

One of GitLab's core principles is to always start with a "minimal viable
change". The idea is to deliver the smallest possible unit of work that delivers
value to the user. On paper that sounds great, but in practice the definition of
"minimal" is inconsistent between people. The result is that one team might
consider performance or good usability a requirement to something being viable,
while another team couldn't care less.

In practice this lead to GitLab building many features over the years that just
weren't useful: a serverless platform nobody asked for and that was ultimately
killed off, support for managing Kubernetes clusters that didn't work for three
weeks without anybody noticing, a chatops solution we had to build on top of our
CI offering (thus introducing significant latency) instead of using existing
solutions, or a requirements management feature that only supported creating and
viewing data (not even updating or deleting); these are just a few examples from
recent years.

To determine what makes something viable, you need a deep understanding of the
desires of your target audience. While GitLab does perform [user surveys every
quarter](https://handbook.gitlab.com/handbook/product/ux/performance-indicators/paid-nps/),
and some teams have access to data about user engagement, from what I remember
and learned from talking to other former colleagues it seems this data was more
incidentally used, instead of being a core part of each team's workflow.

### A SaaS and self-hosting don't go well together

GitLab offers two types of product: self-hosted installations and a software as
a service (SaaS) offering. I believe most companies won't be able to effectively
offer such a setup, including GitLab. Not only do you get a conflict of interest
based on what earns you the most money (as mentioned above), but the two types
of setups also come with different requirements and ways of applying updates.

For example, for a SaaS you want to be able to deploy quickly and have to
handle large amounts of data and workloads taking place on a centralized
infrastructure. Given most self-hosted instances tend  to be tiny in comparison
to the SaaS offering, many of the solutions for the problems you encounter as a
SaaS and their corresponding solutions just don't apply to self-hosted
installations. This effectively results in two code paths in many parts of your
platform: one for the SaaS version, and one for the self-hosted version. Even if
the code is physically the same (i.e. you provide some sort of easy to use
wrapper for self-hosted installations), you still need to think about the
differences.

In contrast, when you focus on _either_ a SaaS or self-hosted setup you get to
dedicate all your attention to providing the best experience for the setup in
question. There are of course exceptions, but they are exactly that: exceptions,
and exceptions are rare.

### More people doesn't equal better results

Like many other companies before it, GitLab hired large numbers of people over
the years and today employs over 2000 people. I don't know how many of those are
developers today, but I'm guessing at least a few hundred based on a quick
glance at their team page.

It's well known that adding more people to a project doesn't necessarily improve
productivity and results (see also "The Mythical Man-Month"), and yet almost
every western startup with venture capital seems to ignore this, hiring hundreds
of developers even if the product doesn't need nearly that many developers.

I don't have any data to back this up, but I suspect that most companies don't
need more than 20 developers, with some needing 20 to 50 developers, and only a
handful needing between 50 and 100 developers. Once you cross the 100 developer
mark, I think you need to start thinking about whether the scope of your
product(s) isn't getting out of hand before hiring even more people.

Note that I'm specifically talking about software developers here. For example,
if you're building custom hardware, you'll probably need more people to scale up
the production process. Sales and support are also two areas where you generally
do benefit from having more people, as these types of work require less
synchronisation between people.

### I'm conflicted on the use of Ruby on Rails

GitLab is built using Ruby and Ruby on Rails, and this is a big part of what
allowed it to reach the success it enjoys today. At the same time, this
combination presents its challenges when the project reaches a large size with
many contributors of different experience levels. Rails in particular makes it
too easy to introduce code that doesn't perform well.

For example, if you want to display a list of projects along with a counter
showing the number of project members, it's far too easy to introduce the [N+1
query problem](https://stackoverflow.com/questions/97197/what-is-the-n1-selects-problem-in-orm-object-relational-mapping)
by accident. While Rails (or more specifically, ActiveRecord) provides
functionality to solve this, it's an opt-in mechanism, inevitably leading to
developers forgetting about this. Many of the performance problems solved during
my first few years at GitLab were N+1 query problems.

Other frameworks have learned from this over the years and provide better
alternatives. The usual approach is that instead of being able to arbitrarily
query associated data, you have to pass in the data ahead of time. The benefit
here is that if you were to forget passing the data in, you'd run into some sort
of error rather than the code querying the data for you on a per-row basis,
introducing performance problems along the way.

Ruby itself is also a choice I have mixed opinions on. On one end, it's a
wonderful language I enjoyed using for a little under 10 years. On the other
end, its heavy use of meta programming makes it difficult to use in large
projects, even with the introduction of optional typing. I'm not just saying
that for the sake of saying it, I experienced it first hand when writing [a
static analysis tool for Ruby](https://github.com/yorickpeterse/ruby-lint) years
ago.

In spite of all this, I'm not sure what alternative I would recommend instead of
the combination of Ruby and Ruby on Rails. Languages such as Go, Rust or Node.js
might be more efficient than Ruby, but none have a framework as capable as Ruby
on Rails. Python and Django _might_ be an option, but I suspect you'll run into
similar problems as Ruby and Ruby on Rails, at least to some degree. It would
probably help if new web frameworks stopped obsessing over how to define your
routing tree, and instead focused more on productivity as a whole.

I have some vague ideas on how I'd approach this with
[Inko](https://inko-lang.org/), but there's a lot of other work that needs doing
before I can start writing a web framework in Inko.

### The time it takes to deploy code is vital to the success of an organization

This is something I already knew before joining GitLab, having spent a
significant amount of time setting up good deployment and testing pipelines at
my previous job, but working for GitLab reinforced this belief: you need to be
able to deploy your code _fast_, i.e. within at most an hour of pushing the
changes to whatever branch/tag/thing you deploy from. At GitLab it took
somewhere around four years for us to get even close to that, and we still had a
long way to go.

Apart from the obvious benefits, such as being able to respond to incidents more
efficiently (without having to hot-patch code to account for your deploys taking
hours), there's also a motivational benefit: being able to see your changes live
is _nice_ because you actually get to see and make use of your work. Nothing is
more demotivating than spending weeks on a set of changes, only for it to take
another two weeks for them to be deployed.

For this to work, you need to be incredibly aggressive about cutting down deploy
times and the time it takes to run your test suite as part of your deployments.
Depending on the type of application and the types of services you're testing,
you may inherently need a certain amount of time to run the tests. The point
here is not "tests and deployments must never take more than X minutes", but
rather to (as an organization) make it a priority to be able to deploy as fast
as your business requirements allow you to. As obvious as this may seem, I
suspect many organizations aren't doing nearly as good of a job in this area as
they could.

### Location based salaries are discriminatory

The salary you earn at GitLab is influenced by various variables, one of which
is location. The influence of your location isn't insignificant either. When you
are a company with a physical office and have a need to hire people in specific
areas, it might make sense to adjust pay based on location as you otherwise
might not be able to hire the necessary people in the required areas. But for an
all remote company without a physical office, and legal entities across the
whole world, there's no legitimate reason to pay two different people with the
same experience and responsibilities different salaries purely based on where
they live.

To illustrate: when I left GitLab my salary was around €120 000 per year, or
around €8500 per month, before taxes. For The Netherlands this is a good salary,
and you'll have a hard time finding companies that offer better _and_ let you
work from home full time. But if I had instead lived in the Bay Area, I would've
earned at least twice that amount, possibly even more. Not because I am somehow
able to do my job better in the Bay Area, or because of any other valid
reason for that matter, but because I would be living in the Bay Area instead of
in The Netherlands.

No matter how you try to spin this, it's by all accounts an act of
discrimination to pay one person less than another purely based on where they
live. Think about it: if a company pays a person less because of the color of
their skin or their gender, the company would be in big trouble. But somehow
it's OK to pay a person less based on their location?

As for how to solve this, for companies it's easy: just pay based on the
position's requirements, not the location of the applicant. It doesn't matter
whether you're paying somebody in the Bay Area $100 000 per year, or somebody in
the Philippines, because the cost for you as a business is the same. For
employees my only advice is to try and negotiate a better salary, but this may
prove difficult as companies paying based on locations also tend to be stubborn
about it. I hope one day our laws catch up with this practice.

A company that seems to do a good job at this is the [0xide Computer
Company](https://oxide.computer/). Instead of paying employees based on their
location, 0xide pays employees the same amount (see [this
post](https://oxide.computer/blog/compensation-as-a-reflection-of-values) for
more details), something I deeply admire and believe more companies should do.

## Conclusion

Looking back, my time at GitLab is a mix of both incredibly positive and
negative experiences. I'm incredibly proud of the achievements the various teams
I was on made, and the people I got to work with, but I'm also saddened by the
last year or so souring an otherwise great experience. I don't have any regrets
working for GitLab, and would do it all over again if I could, just a little
differently thanks to the benefit of hindsight. I also still recommend it as a
company to work for, because in spite of its flaws I think it does _much_ better
than many other companies.
