---
title: I'm leaving GitLab to work on Inko full-time
date: 2021-12-14 15:54:48 UTC
---

Back in October 2015 I joined [GitLab](https://about.gitlab.com/). I think I was
employee #28 at the time, with the total number of employees being somewhere
between 30 and 40 if I'm not mistaken. Fast-forward to today, and GitLab has
grown to almost 1600 employees.

While I enjoyed my time at GitLab, after a little over six years I feel it's
time for something new. In particular, I want to be able to dedicate more time
to [Inko](https://inko-lang.org/). With that in mind, I resigned from GitLab
with my last day being December 31st 2021. Starting January 1st 2022, I'll be
working on Inko full-time. The roadmap for 2022 is as follows:

1. Finish the new compiler written in Rust, which also implements a new memory
   management strategy for Inko.
1. Build a decentralised package manager
1. Grow the community

For now I'm not adding more to the roadmap, as I'm not yet sure how productive
I'll be once I start working on Inko full-time.

The new memory management strategy is something I'm most excited about. This
strategy combines the efficient heap layout from
[Immix](https://www.cs.utexas.edu/users/speedway/DaCapo/papers/immix-pldi-2008.pdf)
with a single-ownership model, but without the lifetimes complexity found in
Rust. The ownership model is based on the paper [Ownership You Can Count On: A
Hybrid Approach to Safe Explicit Memory
Management](https://researcher.watson.ibm.com/researcher/files/us-bacon/Dingle07Ownership.pdf),
though I intend to extend it with additional compile-time analysis and support
for generic data structures that support both owned and borrowed values. Of
course this approach comes with its own trade-offs, but I feel these trade-offs
are worth making, and will make Inko a compelling alternative to languages such
as Python, Ruby, and Erlang.

If you'd like to support the project financially, you can do so [through GitHub
Sponsors](https://github.com/sponsors/YorickPeterse/). And if you'd like to
follow progress made on Inko, consider joining the [Matrix
channel](https://matrix.to/#/#inko-lang:matrix.org), as I'll post short updates
there from time to time. I also intend to start recording videos on the
development of Inko and maybe start streaming, but I think it will take a bit of
time before I have the courage to do so.
