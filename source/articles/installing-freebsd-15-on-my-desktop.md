---
{
  "title": "Installing FreeBSD 15 on my desktop",
  "date": "2025-11-21T00:00:00Z"
}
---

This week I've been working on a script and slides for a YouTube video about
[Inko](https://inko-lang.org/). After a week of doing that I needed a bit of a
break. Last week [I wrote a bit about
FreeBSD](/articles/a-brief-look-at-freebsd/), and specifically about wanting to
try it out on my yet to be delivered Framework 16 laptop. This got me thinking:
why don't I try FreeBSD on my desktop first, then see if it's still worth trying
out on a laptop? After all, my desktop has a spare SSD that I don't use much, so
I could move its data elsewhere temporarily and install FreeBSD on this SSD,
leaving my main system untouched.

What follows is a sort of transcript (with some editing) of doing just that, a
process that took a total of some three hours. Because I wrote most of this
while actually performing the work, it may feel a little chaotic at times, but I
hope it gives a bit of insight into the process.

## The hardware

The desktop in question uses an AMD Ryzen 5600X CPU, with an Intel Arc A380 GPU.
The SSD FreeBSD will be installed on is a Samsung Evo 860 with 256 GiB of
storage. The WiFi card is an Intel AX200, which is supported by FreeBSD.

## Preparing a USB drive

I downloaded the latest FreeBSD 15 snapshot ISO format, then wrote it to a
random USB drive using `dd`. I initially tried to use GNOME Disks to restore the
ISO to the USB drive, but for some reasons this results in it not being a
bootable drive. I vaguely recall having had similar issues in the past with
Linux distributions, so this isn't FreeBSD specific.

## Installing FreeBSD

Booting up worked and the installer detects the AX200, but then seemingly got
stuck for a good minute or so, after which it moved on. I'm not sure why, but it
didn't seem to matter much as the rest of the installer worked fine.

Using the installer I went with a ZFS on root setup and enabled disk encryption.
In particular I enabled the "local\_unbound" service to cache DNS lookups.
Knowing this won't work with my router (which runs a local DNS server/cache)
because it doesn't support DNSSEC, I was a bit surprised to see the installer
not consider this at all, i.e. there's no "use local\_unbound but without
DNSSEC" option.

## First boot

After installing FreeBSD I rebooted into the target SSD. The first thing I
noticed was a bunch of error messages from the ntp daemon (which I enabled)
saying it couldn't resolve a bunch of DNS names. This is because my router
doesn't support DNSSEC. I fixed this by creating
`/var/unbound/conf.d/disable-dnssec.conf` with the following contents:


```
server:
    module-config: "iterator"
```

Because FreeBSD ships vi by default (not vim, actual vi) this was a little
annoying as vi works a little different compared to vim. After saving the file I
restarted the `local_unbound` service, and all was well again.

FreeBSD offers both `doas` and `sudo`. I figured I'd give `doas` a try, mainly
because I wanted to give it a try. This requires you to copy
`/usr/local/etc/doas.conf.sample` to `/usr/local/etc/doas.conf` and edit it
accordingly. I just used it with the `permit :wheel` rule, which is enough for
most people. I then found out that `doas` doesn't support password persistence
outside of OpenBSD, meaning you have to enter your password again for every
`doas` command. While there appears to be a fork available called `opendoas`
that does support it, it in turn doesn't appear to be actively maintained
(judging by the [GitHub repository](https://github.com/Duncaen/OpenDoas)). I
ended up going back to `sudo` instead.

I then installed [Fish](https://fishshell.com/) and made it the default shell as
follows:

```bash
chsh -s /usr/local/bin/fish yorickpeterse
```

I then logged out and back in again, and Fish works as expected.

FreeBSD shows a message-of-the-day when you log in, which I don't want as it's
rather long. To disable this, I emptied `/etc/motd.template` then ran `sudo
service motd restart` to re-generate the message, then disabled the service
using `sudo sysrc update_motd="NO"`. We also need to remove `/var/run/motd`. I
think in hindsight editing the template wasn't required as I could've just
disabled the service then remove `/var/run/motd` file. Ah well, lessons learned
I guess.

## Fighting the GPU

Now it's time to make sure the GPU is set up. The reason my desktop is using an
Intel GPU is because it used to use an aging AMD RX 550, but after dealing with
AMD driver bugs for a few months I got fed up and decided to replace it. I
picked the A380 because it was the cheapest GPU with support for hardware
decoding that I could find.

To do this we have to install `drm-kmod`, which pulls in about 130 driver
related packages (yikes). Next we need to make sure the driver is loaded upon
startup by adding it to `/etc/rc.conf` like so:

```bash
sudo sysrc kld_list+=i915kms
```

This doesn't affect the existing system though, so we also have to load the
module using `kldload` (`modprobe` but for FreeBSD), so I ran this:

```bash
sudo kldload i915kms
```

This crashed my system. Brilliant. Worse, because I added the module to
`/etc/rc.conf` it keeps crashing when you reboot. The error shown when FreeBSD
tries to load the module says to run `pkg install gpu-firmware-kmod` to install
the necessary firmware, but because the module is now loaded at startup we first
have to figure out how to get back into a working system. I found [a forum
post](https://forums.freebsd.org/threads/how-to-boot-with-messed-up-boot-loader-conf.64019/)
that offered some suggestions, but they didn't work.

I ended up booting into the installation USB and mounted the host drive
following the instructions from [this article](https://www.adyxax.org/blog/2023/01/05/recover-a-freebsd-system-using-a-liveusb/),
using `/dev/ada0p3` as the drive name. I then opened `/mnt/etc/rc.conf` and
commented out the line that loads the i915kms driver, then rebooted. We have a
working system again!

Now to do what that error said: install the missing package. Well, except it
wasn't missing because when I installed it `pkg` said it was already installed.
This is fine, I guess?

A bit of searching reveals [this
issue](https://github.com/freebsd/drm-kmod/issues/315), first reported in
August 2024. There's a [pull request that should fix
this](https://github.com/freebsd/drm-kmod/pull/371), but I'm not going to
compile a custom kernel just to get a working system. It also seems the PR has
just been sitting around for a while, which doesn't bode well.

Most people would give up at this point, but I have one final trick up my
sleeve: when I replaced my AMD RX 550 I didn't throw it away in case I ever
needed it again, so I can temporarily use it instead of the A380. It shouldn't
be necessary, but at this point I want to try and get a working desktop
environment just so I can say I at least tried.

So after trying a few different screwdrivers to unscrew the GPU bracket screws
and some cursing later, the A380 is replaced with the RX 550. I booted up the
system and edited `/etc/rc.conf` to load the `amdgpu` driver instead of
`i915kms`. I then decided to reboot the system for good measure, though this
isn't strictly necessary. I am now presented with a system that works, except
the console font is tiny for some reason. [This
article](https://www.micski.dk/2022/01/06/fix-small-font-in-freebsd-virtual-terminal-system-console/)
suggests using `vidcontrol -f terminus-b32` which did the trick.

## Installing a desktop environment

Where were we again? Oh yes, I was going to install a desktop environment.
I'd use GNOME, but GNOME recently announced they were going to depend
on systemd more and more, and the GNOME version provided by FreeBSD is a bit old
at this point (GNOME 47). KDE seems better supported, so I'll give that a try.
The FreeBSD installer is supposed to come with an option to install KDE for you,
though the ISO I used for FreeBSD 15 didn't have that option. Either way, from
what I found it uses X11 and I want to use Wayland, so I wouldn't have used it
anyway. [This article](https://euroquis.nl/kde/2025/09/07/wayland.html) lists
some steps to enable KDE. The socket options it suggests to apply seem a bit
suspicious, as in, they look like the kind of setting people just copy-paste
without thinking, so we'll skip those unless they turn out to be required after
all.

Let's install the necessary packages:

```bash
sudo pkg install seatd kde sddm
```

This ends up installing close to 700 packages. This took a while since `pkg`
downloads packages one at a time. Support for concurrent downloads was first
requested [back in 2017](https://github.com/freebsd/pkg/issues/1628), but isn't
implemented as of November 2025. This wouldn't be a huge problem if it wasn't
for the FreeBSD mirrors only supporting speeds in the range of 5-20 Mib/sec,
while my internet connection's maximum speed is 100 MiB/sec.

Upon the installation finishing, I realized I hadn't explicitly stated or
switched to the latest branch for the FreeBSD ports, so I edited
`/usr/local/etc/pkg/repos/FreeBSD.conf` to be as follows:

```
FreeBSD-base {
  url: "pkg+https://pkg.freebsd.org/${ABI}/base_latest",
  enabled: yes
}
```

I then ran `sudo pkg update` followed by `sudo pkg upgrade` and there was
nothing to update, so I guess we're all good.

## Configuring the desktop environment

Now to enable the service we need for KDE. The linked article doesn't mention
enabling SDDM but it seems to me like that would be required for it to start, so
we'll give that a go as well:

```bash
sudo sysrc dbus_enable="YES"
sudo sysrc seatd_enable="YES"
sudo sysrc sddm_enable="YES"
sudo service dbus start
sudo service seatd start
sudo service sddm start
```

This results in SDDM starting and showing the login screen. The default session
is set to Wayland already, and logging in works fine. Neat!

Moving the mouse around I'm noticing some weird artifacts on the desktop
wallpaper:

![Artifacts on the
desktop](/images/installing-freebsd-15-on-my-desktop/artifacts.jpg)

Looking at the display settings I noticed scaling is set to 170%, while for this
display it should be 200%. Changing this removed the artifacts, so I guess this
is some sort of KDE bug?

Another thing I'm noticing when moving the cursor around or when window
animations play is that it isn't as smooth as GNOME, as if the display's refresh
rate is lower than it should be, though it's in fact set to 60hz. I vaguely
recall having this issue on GNOME when I was still using the AMD RX 550, so
maybe it's a GPU issue. Or maybe it's those socket options I decided not to
enable initially, so let's give that a try, just in case, though it's a bit of a
stretch. First I ran the following to apply the settings to the existing system:

```bash
sudo sysctl net.local.stream.recvspace=65536
sudo sysctl net.local.stream.sendspace=65536
```

The resulting output suggests this is already the default value, so I guess
that's not the reason, and the settings might not be necessary at all.

Now let's get rid of some software I don't need such as Konqueror and Kate:

```bash
sudo pkg remove konqueror kate
```

Initially this gave me a bit of a heart attack as it tells you that the `kde`
package will also be removed, but it turns out to be fine and not actually
uninstall your entire KDE setup.

## Audio

Audio works fine with no configuration necessary. Neat.

## Network

While the network itself works, there's no GUI application of any kind to manage
it, as NetworkManager isn't available on FreeBSD.  I found
[networkmanager-shim](https://www.freshports.org/net-mgmt/networkmanager-shim/)
which is required by
[kf6-networkmanager-qt](https://www.freshports.org/net-mgmt/kf6-networkmanager-qt/).
I installed the latter in case I'd also need that, logged out and back in again
and...nothing. Searching a bit more lead to me finding
[networkmgr](https://github.com/GhostBSD/networkmgr) which is available as a
FreeBSD package, so let's try that:

```bash
sudo pkg install networkmgr
```

Logging out and in again and there's now a network icon in the Plasma panel.
Unfortunately, it seems to be an X11/Xwayland application and looks horrible:

![networkmgr on FreeBSD](/images/installing-freebsd-15-on-my-desktop/networkmgr.jpg)

::: note
Apologies for the poor quality! I hadn't set up a screenshot application of some
sort and didn't want to also deal with that, so I just took a photo with my
phone.
:::

It also doesn't appear to show anything related to WiFi. `ifconfig` doesn't list
anything WiFi related either. I guess I have to set up
[wpa\_supplicant](https://w1.fi/wpa_supplicant/) or something along those lines,
but I'd prefer it if my desktop environment could manage it for me.

Bluetooth doesn't appear to work either, probably for the same reasons because
it's handled by the same AX200 chip. I found that
[wifimgr](https://www.freshports.org/net-mgmt/wifimgr/) can be used to manage
WiFi, but starting it results in it complaining I have to first configure a
device in `/etc/rc.conf`. Ugh.

It's at this point that not only was it getting late, I also had enough. I can
see the appeal of FreeBSD, and it's impressive how much up to date software
there is in the ports repository, but there's a reason I moved away from Arch
Linux several years ago: I just don't have the patience nor interest to
endlessly fiddle with configuration files just to get a basic system up and
running.

## Conclusion

If you have enough patience and time I think you can set up a decent KDE desktop
environment using FreeBSD, assuming your hardware is properly supported. That is
also the biggest challenge though: FreeBSD developers have limited resources and
port the Linux GPU drivers to FreeBSD, instead of using bespoke drivers. This
means it will always lag behind Linux, ranging from maybe only a few weeks to
months or even years.

Based on the challenges I ran into while trying to install FreeBSD on my
desktop, I'm not going to try and install it on a laptop any time soon. I just
don't have the patience or interest. If I did, I'd go back to using Arch Linux.

There are also some choices that FreeBSD makes that I don't agree with or don't
want to deal with, such as the archaic way of writing service files or setting
up log rotation, or the fact that the output of the `-h` option for the FreeBSD
userspace utilities (e.g. `ls`) is as good as useless.

On the bright side, if the FreeBSD foundation continues focusing on improving
the laptop and desktop experience of FreeBSD then all this could be different
1-2 years from now, so maybe I'll try again in the future.
