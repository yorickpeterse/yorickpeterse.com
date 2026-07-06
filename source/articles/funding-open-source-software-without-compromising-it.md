---
{
  "title": "Funding open-source software without compromising it",
  "date": "2026-07-06T00:00:00Z"
}
---

Funding open-source software is a challenge, especially for projects without a
large existing community. While various approaches exist, they all come with
their own drawbacks. For example, asking for donations is by far the most
commonly used approach but also the least effective: you can ask (or pretty much
beg) for donations for years and _maybe_ you'll receive $10 per month.
[Heartbleed](https://en.wikipedia.org/wiki/Heartbleed) is probably the most
well-known vulnerability that highlights the problem of important but
chronically under-funded open-source software projects.

Other alternatives tend to compromise the project in some way. For example,
starting a side business of sorts (e.g. one that uses the project in question)
means you now have to balance two jobs: the open-source project that you _want_
to work on, and the commercial offering that is supposed to pay the bills.

Another option is to take the open-core approach: the project is proprietary and
there exists an open-source fork of sorts that contains a reduced feature set,
in an attempt to entice users to use (and pay for) the proprietary version
instead. [GitLab](https://about.gitlab.com/) is an example of one such
project/company. While this too can work, almost always does it end up
compromising the open-source version in some way, such as when features that
previously existed in the open-source version are made proprietary instead
because some C-whatever-O determined this was in the best interest of the
sharehold..err I mean the community of course!

Then there are software grants such as those provided by
[NLnet](https://nlnet.nl/). These are essentially (larger) donations but with
additional requirements and caveats. Unfortunately, these typically come in one
of two forms:

1. Grants that are only open to existing large projects
1. Grants that come with highly specific requirements, such as you needing to be
   a resident of a specific country

NLnet _used_ to be an exception to this, but this too changed in recent years
and the requirements today unfortunately exclude a lot of projects. [Sovereign
Tech Agency](https://www.sovereign.tech/) is the only grant organisation that I
know of that _did_ (not sure they still do) grant money to projects that have
yet to establish themselves, but it came with the caveat that you had to be
based in Germany to be able to apply. [FUTO](https://futo.tech/) appeared to be
a promising alternative, until I found out that the [the organization is
problematic at best](https://drewdevault.com/blog/Whats-up-with-FUTO/) (and
that's me trying to be nice) and not something I'd want to associate myself
with.

So why am I [beating the dead
horse](https://en.wikipedia.org/wiki/Flogging_a_dead_horse) that is "open-source
funding is difficult"? Well, because for the last year or so I've been more
actively trying to figure out how I can fund the long-term development of
[Inko](https://inko-lang.org/) without compromising the project somehow.

_Just_ relying on donations is something I don't see working out in the
long-term as it's just not reliable enough when it comes to providing a steady
income. One month you may be lucky and receive $500, while the next everybody
cancels their donations because you said you don't mind pineapple on pizza.
Grants is something I've looked into extensively and there just aren't any (that
I know of) that would accept Inko. Which brings me to the idea of running a side
business.

On paper I like the idea of running a business: no manager breathing down your
neck, no overpaid directors that just move numbers across spreadsheets and
somehow get paid 10x than the most important developer in the company, no "you
must use AI or you'll get fired" nonsense, and so on. Of course there are also
challenges such as having to do _everything_ yourself and sales being difficult,
especially if you tend to under-sell your work like I do.

One important requirement I have though is that whatever the product is, it
_must_ be open-source. Not open-source as in open-core, but truly open-source.
This isn't just a philosophical or political stance, it's also a practical one:
having worked at GitLab for quite a while, splitting a product into a
proprietary version and open-source fork (ish) introduces various technical
challenges that I just don't want to deal with again.

Which brings me to an idea I had, one that probably won't work out but that I
feel is worth sharing anyway; or at least one that's worth writing down so I can
get it out of my head.

The idea is pretty simple: the product is open-source, licensed using a strict
license such as the AGPL, optionally dual-licensed under a commercial license
for those two companies that are allergic to the AGPL but somehow _are_ willing
to pay for a commercial license. The source code exists in two repositories: a
private repository where all development takes place, and a public mirror.

The public mirror is only updated periodically (e.g. every three months), except
for when something warrants an additional update (e.g. a critical security
vulnerability for which it wouldn't be ethical to delay it by three months).

The private repository is also where the bug tracker resides and where users can
submit patches (assuming you want to accept those in the first place). Access to
the private repository requires one to active financially support the project
somehow, such as by donating or by acquiring a commercial license.

Crucially, to gain access to the private repository you must "sign" (i.e. this
could just be a "Yes I agree to these terms" checkbox) an agreement of sorts
which states that _if_ you publicly host a copy of the private repository your
access to this private repository will be revoked.

The idea is that the software _is_ truly open-source and that _if_ you have
access to a copy of the source code you can pretty much do whatever you want
with it, as long as it meets the requirements of the open-source license, but
_access_ to the _upstream repository_ is restricted to those with an active
subscription. And if you don't want to pay and are OK with updates being delayed
by say three months, then you can use the public delayed mirror.

Besides nudging users towards paying the maintainers of the project, requiring
users to pay to submit tickets (including bug reports) may in theory also
increase the quality of those reports as those who can't be bothered to fill in
an issue form properly most likely also can't be bothered to pay to gain access
to the issue tracker in the first place.

This approach is of course not without its own problems. For example, putting
the entire issue tracker behind a payment requirement also means that
well-meaning users who just can't afford to pay a subscription can't submit any
tickets. A second problem is that I suspect most users will be fine using a
delayed mirror if the delay is short enough but won't bother using the project
at all if the delay is too long. This means that the number of paying users will
likely still be pretty low.

There's also the technical challenge of having to integrate the repository with
a payment system of sorts, though this could probably be done manually for the
first few years of a project's existence given the number of subscribers will
likely remain low until the project establishes itself somehow. Using GitHub
Sponsors would make this a little easier as you can automatically grant sponsors
access to a private repository, though this requires that GitHub isn't down
_again_.

Probably the biggest challenge that remains is that you still need some sort of
additional business idea that people would be willing to pay for in the first
place. For example, this model wouldn't work for Inko itself because paying for
a programming language is something that developers or companies just don't want
to do these days. This means that unfortunately you still have to compromise the
project in some way by dedicating part of your time and resources to
_another_ project that ultimately pays the bills.

Now if only I could come up with a business model that _doesn't_ require
millions in venture capital funding just to get started, then maybe I could
experiment with the above to see how it works out in practise. If that doesn't
work out then I guess it's time to start selling pictures of my feet.
