There are a lot of things I dislike (like any true Dutchman). I probably also
like ranting about those things as much as I dislike them. Normally I either
rant in `#webdevs` or `#ruby-lang` on Freenode but people tend to get a bit
butthurt when you don't talk purely about Ruby for more than 2 minutes.

This article serves as a collection of random rants that I feel are worth
writing down. Expect vulgar language, double standards, anger and badly written
paragraphs.

## Index

* [GPG/Enigmail](#gpg-enigmail)

## GPG/Enigmail

If there's one tool that manages to perfectly combine good intentions with an
absolutely fucking terrible user experience/interface it's [GPG][gpg]. The idea
of GPG/PGP sound interesting: provide a distributed trust system with no single
point of failure.

The problem is that the concept and the tools built around it are so complex
that even experienced programmers will end up bashing their skull against a
wall every time they have to download and verify a public key. Even worse, if
you try to teach Average Joe about these concepts chances are they'll quite
literally ask you if you just told them to go fuck themselves. Imagine the
following conversation:

    #!text
    <Bob>   First you must search for a key using `gpg --search-key [QUERY]`
    <Alice> Isn't --search-key an option?
    <Bob>   No it's a command because fuck you GPG makes no sense

Shortly followed by the following:

    #!text
    <Alice> Ok now that I have the key, what's next?
    <Bob>   Now we must indicate if we trust it or not and sign the key
    <Alice> Ok, so I can just say I trust the key?
    <Bob>   NO HOW DARE YOU *smacks Alice*, YOU MUST CHOOSE AN ARBITRARY TRUST
            LEVEL THAT NOBODY CARES ABOUT!

The conversation goes on and by the end Alice decides to never use GPG ever
again.

To make matters worse there's this concept of "key signing parties". Basically
these are "parties" (probably minus everything that would make it a fun party)
where a bunch of nerds gather to verify their public keys printed on A4 paper.
I'm not kidding, people actually print their fucking public keys/finger prints
(which aren't exactly small) on paper and then *re-type them on another
computer* ([example][gpg-paper]). Yet somehow these same people wonder why
nobody uses GPG.

Heavens forbid if you also want to encrypt/sign Emails, you'll end up in a
whole new nightmare. For example, Thunderbird has an extension called
[Enigmail][enigmail]. Enigmal does do a few things right such as easily showing
the validty of an Email and such (once you've gone through the trouble of
setting it up) but it becomes an absolute disaster if you want to encrypt an
Email using somebody else's public key (so that they can actually decrypt it).
To do so you must not only set a trust level of a key but you also have to sign
it, whether this is a flaw in PGP/GPG or Enigmail I'm not sure about but it's
super fucking annoying if the only indication of this process is a small column
that says "untrusted" or "trusted", especially after you've marked the key as
trusted a thousand times already out of pure frustration.

There are also various other issues with the extension such as random buttons
(e.g. "View Key properties") simply not doing shit or just saying "This key is
invalid" (no shit). I'll this section as it is since I'm pretty sure most of
these issues arise from me just not caring about Enigmail anymore after the
first few setup steps.

Don't get me wrong, I really support the idea of encrypted Email and I would be
willing to go through the pain of GPG (e.g. I use it to sign Gems nobody cares
about) but it's such a fucking pain that you can honestly not expect anyone
outside of IT to ever take it seriously.

[gpg]: https://en.wikipedia.org/wiki/GNU_Privacy_Guard
[gpg-paper]: http://people.apache.org/~henkp/sig/pgp-key-signing.txt
[enigmail]: https://www.enigmail.net/home/index.php
