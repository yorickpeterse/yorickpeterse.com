Almost any application will eventually need to store a collection of passwords or another
type of data that has to be stored using a hashing algorithm. Blogs, forums, issue 
trackers, they all need to store user data and these passwords. This article covers the 
common mistakes made when dealing with passwords and what you should use instead. In order 
to fully understand this article some basic knowledge of programming and computers is 
required, you should also know a bit about the common hashing algorithms such as MD5 and 
SHA1.

## The Problem

When developing applications developers make the common mistake of thinking they have a
solid understanding of how hashing works. They think that by doing X they're done and 
perfectly safe. Guess what, that's not the case (not even close). The following mistakes
are the most common:

* Using a broken algorithm (MD5, SHA1)
* Hashing a password N times in the form of hash( hash(password) ) * N
* Limiting the length of passwords to N characters

We'll start with the first problem. Up until a few years ago MD5 was the most common 
hashing algorithm used for passwords (and other data as well). MD5 was considered to be
pretty safe until a group of people managed to prove how weak it really was: they were
able to generate a set of collisions in a relatively short amount of time (a few hours or
so). This set off a chain reaction and many more flaws were found. 

Luckily MD5 isn't the only hashing algorithm out there, there's SHA1 and the SHA2 family
as well as a few other ones. SHA1-SHA2 are much strong than MD5 and at the time of writing
(April 2011) only SHA1 has been compromised. Technically it would take serious amount of
time to crack SHA1 but the idea of using an algorithm that *can* be cracked before 
humanity is wiped out should be enough for people to not use it for privacy related data.

So why are collisions bad? Can't we just use a very very long password or use method X 
(insert your favorite counter measure)? Yes, you can. The problem however isn't fixed,
you're merely making the process slower rather than fixing the actual root of the problem.
Time for an example. Assuming we have a hashing function called "hash" and two strings,
A and B (where A and B are unique), our hashing process of these strings would look like
the following:

    pwd1 = hash(A)
    pwd2 = hash(B)

In this case both pwd1 and pwd2 are unique. At this point a lot of people think they're
good to go as they assume nobody is willing to wait for a certain period of time before
they're able to crack the password, this is a *very* stupid mistake. While trying to
crack a password (by bruteforcing it for example) may take a long time on a single computer 
most hackers can easily boot up a few servers or even worse, use a botnet. All known 
hashing algorithms (except BCrypt, more on that later) are affected by a single common 
problem: [Moore's law][moore's law]. Moore's law states that every two years the amount 
of transistors that can be put in a computer doubles. This means that the faster computers 
get the quicker they're able to crack a password. A hacker merely has to use N computers 
and the time required to retrieve the original password will be greatly reduced.    

Because of this problem developers try to come up with solutions. These solutions don't
actually solve the problem, they just make it harder and require more time. A common "fix"
is to hash a password N times and then save it in the database. Developers do this for
a few reasons:

* It's supposed to be slower
* In order to retrieve the original password a hacker has to crack multiple
hashes instead of only one.

The fun thing is that this entire process doesn't actually make the password more secure,
in a lot of cases it will even make it *less* secure. The first reason is pretty easy to
bust: simply add more hardware (or better hardware) and you're good to go. The second
reason is a bit harder to bust as it depends on the algorithm that is used. If we look
back at our hash() function the process of hashing a hash multiple times would look like
the following:

    hash = hash( hash(hash(A)) )

In this example there are 3 calls to the hashing function. If A was "yorick" this would
look a bit like the following:

    hash(yorick)  -> j238103
    hash(j238103) -> a9shda9
    hash(a9shda9) -> 11s08j1

In this case "11s08j1" is the final hash that will be stored in our database. At this
point developers usually lay down their work and take a coffee or a tea thinking they've
done a good job and are hacker proof. Guess what, they're not. What just happened is that
the process of hashing A multiple times actually increased the possibility of a hash
collision. While we do have to crack the hashing process N times for each call
to hash() we don't actually have to start at the very end (with "11s08j1"). The reason for
this is that "11s08j1" isn't directly based on "yorick" but on "a9shda9". This means that
we merely have to find the hash that results in "11s08j1" when using our hash function.
If we find a collision we can simply crack it again and we'd end up with our
original password. 

In order to explain this properly I simplified the process of hashing A N times:

    password --> hash 1 --> hash 2 --> final hash

In order to retrieve the original password ("password") we'd have to find a collision for
"hash 2". We can't use hash 1 as it's source ("password") can be considered totally random
and would take more time. However, the source of hash 2 is much easier due one big issue:
the entropy (the amount of possible combinations) of the password has been decreased. If
we look back at the previous example we know the final hash is "11s08j1" and that the
original password is "yorick". Using various techniques (rainbow tables, bruteforcing, etc)
we can quickly identify the source of "final hash". The value of "hash 2" is "a9shda9",
while in our example this looks more random (it is) than the original password common
hashing algorithms only use regular characters (letters and numbers) for their output. A
good example of this is the following Ruby example:

    require 'digest'

    password = 'as9(A*&SD&(@))'
    hash     = Digest::SHA1.new.hexdigest(password)

    p hash # => "d4c36f9b1f003bee2e5dcafdf6b006110709dfb5"

The hash of the password (which is just something I randomly typed on my keyboard) may be
longer but it only uses letters and numbers opposed to all the gibberish in the original
password. The same happens with our hash() function and this allows us to quickly retrieve
the original password. If we have the original hash of "final hash" we can then simply
continue reversing the process until we end up at "yorick".

The reason why you can't initially find the source of "hash 2" is because you can't find
out what "hash 1" is because it's not stored somewhere while "final hash" is. 

To cut a long story short, hashing a hash N times doesn't make your passwords more secure
and can actually make it less secure as a hacker can quite easily reverse the process by 
generating hash collisions.

## The Solution

It has already been mentioned before but the solution is to use an algorithm called 
"BCrypt". BCrypt is a hashing algorithm based on [Blowfish][blowfish] with a small twist:
it keeps up with Moore's law. The idea of BCrypt is quite simple, don't just use regular
characters (and thus increasing the entropy) and make sure password X always takes the 
same amount of time regardless of how powerful the hardware is that's used to generate X.
I'm not going to cover all the technical details but basically BCrypt requires you to
specify a cost/workfactor in order to generate a password. This workfactor not only makes
the entire process slower but is also used to generate the end hash. This means that if
somebody were to change the workfactor the hash would also be different. In other words,
hackers, you're fucked. In order for a hacker to gain the original password he must use
the same workfactor and thus has to wait N times longer than when not using a workfactor.

Time for an example in Ruby:

    require 'benchmark'
    require 'bcrypt'

    password = 'yorick'
    amount   = 100

    Benchmark.bmbm(20) do |run|

      run.report("Cost of 5") do
        amount.times do
          hash = BCrypt::Password.create(password, :cost => 5)
        end
      end

      run.report("Cost of 10") do
        amount.times do
          hash = BCrypt::Password.create(password, :cost => 10)
        end
      end

      run.report("Cost of 15") do
        amount.times do
          hash = BCrypt::Password.create(password, :cost => 15)
        end
      end

    end

For the non Ruby people, this is a simple benchmark script that shows the time it takes
to hash "yorick" with BCrypt with a cost/workfactor of 5, 10 and 15 a total of 100 times. 
The results of this benchmark would look like the following:

    Rehearsal -------------------------------------------------------
    Cost of 5             0.250000   0.000000   0.250000 (  0.249723)
    Cost of 10            7.740000   0.010000   7.750000 (  7.879849)
    Cost of 15          247.510000   0.460000 247.970000 (255.346897)
    -------------------------------------------- total: 255.970000sec

                              user     system      total        real
    Cost of 5             0.250000   0.000000   0.250000 (  0.272549)
    Cost of 10            7.750000   0.030000   7.780000 (  8.442511)
    Cost of 15          247.530000   0.480000 248.010000 (254.815985)

The column we're really interested in is the "real" column. As you can see a cost of 5
only takes about 250 miliseconds while a cost of 15 takes a whopping 250 seconds (around 
4 minutes). 

To cut another long story short: BCrypt adopts to Moore's law and makes it impossible for
a hacker to crack a password using rainbow tables or other techniques.

## Implementations

The BCrypt hashing algorithm is implemented in quite a few languages. I've collected a
list of resources for various languages so you can start using BCrypt right away.

### PHP

PHP allows you to use BCrypt passwords using the [crypt()][php crypt] function. This works
as following:

    <?php

    $hash = crypt('rasmuslerdorf', '$2a$07$usesomesillystringforsalt$');

### Ruby

For Ruby there's a gem called "bcrypt-ruby" which can be installed using Rubygems:

    $ gem install bcrypt-ruby

Once installed you can use it as following:

    require 'bcrypt'

    hash = BCrypt::Password.create('yorick', :cost => 10)

### Perl

For Perl there's [Crypt::Eksblowfish][perl bcrypt] which works as following:

    use Crypt::Eksblowfish::Bcrypt qw(bcrypt_hash);

    $salt     = '1p23j1-9381-23';
    $password = 'yorick';
    $hash     = bcrypt_hash({
        key_nul => 1,
        cost    => 10,
        salt    => $salt,
    }, $password);

### Others 

* Python has [The Python Cryptography Toolkit][pycrypto]
* Lua seems to have [this][lua bcrypt] implementation
* There's an [Erlang implementation][erlang bcrypt] as well

## Special Thanks

I'd like to thank the following IRC folks for helping me out (all of them can be found 
on Freenode):

* squeeks from \#forrst-chat
* amr from \#forrst-chat
* dominikh from \#ramaze

[sha wikipedia]: http://en.wikipedia.org/wiki/SHA-1
[moore's law]: https://secure.wikimedia.org/wikipedia/en/wiki/Moore's_law
[blowfish]: http://en.wikipedia.org/wiki/Blowfish_(cipher)
[php crypt]: http://nl3.php.net/manual/en/function.crypt.php
[perl bcrypt]: http://search.cpan.org/dist/Crypt-Eksblowfish/
[pycrypto]: https://github.com/dlitz/pycrypto
[lua bcrypt]: https://github.com/silentbicycle/lua-bcrypt
[erlang bcrypt]: https://github.com/skarab/erlang-bcrypt
