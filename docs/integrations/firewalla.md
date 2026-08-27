# Firewalla

[← back to the README](../../README.md)

## Your Firewalla (read-only, on purpose)


A Firewalla (Gold, Gold SE, Gold Plus, Purple, Blue Plus) can be registered the
same way. It shows up in `hh list` like anything else, and `hh overview` and
`hh inventory` include it:

    MSP       yourname.firewalla.net
    Box       Home Firewalla (gold, router mode, v1.975)   online   public IP 203.0.113.7
    Counts    41 devices, 34 rules, 6 alarms
    Devices   41 known, 39 online
    Offline   2: Office Printer, Garage Camera
    Alarms    3 most recent active:
              08-19 21:04  Abnormal upload from Desktop-PC

So "is that machine actually on the network", "what is eating my internet", "why
can't this reach that", and "anything alarming overnight" become questions Claude
answers from the router itself.

One difference from UniFi worth knowing: Firewalla ships no supported local API,
so this reads Firewalla MSP - Firewalla's own management portal - over the
internet, at `https://<yourname>.firewalla.net`. You need an MSP account, and
when your internet is down this is down with it, so it is a poor first probe for
"is the internet up" and a good one for everything else.

**One alias is one box.** An MSP token is scoped to your account, not to a box,
so `hh add-firewalla` asks which Firewalla the alias means when the token can
see more than one, and every read is filtered to it. Two sites means two
aliases, registered with the same token, and `hh firewalla devices cabin` says
which you want. `hh firewalla boxes` lists them all and marks the one an alias
reads. To change which box an alias means: `hh rm-host <alias> && hh add-firewalla`.

One read stays account-wide even so: `hh firewalla trends` filters by MSP
*group* rather than by box, and its output says as much rather than passing an
account-wide number off as one box's. If you want per-box trends, put the box in
an MSP group of its own and read that group directly:

    hh firewalla get '/v2/trends/flows' 'group=<group-id>'

Per-box numbers obtained that way sum back to the account-wide total. (Thanks to
@lesterktm for testing this on a live multi-box account.)

**It can only read. It cannot change anything on your network.** Note that here
that rests on *one* lock rather than UniFi's two:

1. The broker behind `hh firewalla` issues HTTP `GET` and has no code path that
   can `POST`, `PUT`, `PATCH`, or `DELETE`. No pause, no unpause, no rule edit,
   no rename, no reboot, because none of it is implemented.
2. There is no second lock, and the setup says so out loud. Firewalla MSP has no
   read-only token: a personal access token carries the permissions of the
   account that made it. The GET-only broker is the only thing making that token
   safe to hold, which is why it is worth reading `bin/hh-firewalla` before you
   trust it, and why the token is stored where the agent cannot read it.
3. The ops brain and the `firewalla-ops` skill tell Claude the rule plainly, and
   tell it what to do instead: explain the change you should make in the
   Firewalla app or MSP, then read the state back to confirm it worked.

If you would rather not hold an MSP token at all, that is a legitimate choice.
Skip this and keep reading your Firewalla in its own app; everything else in
HomelabHero works without it.

Register it from an admin shell (a token is a secret being typed, so it stays out
of the chat, exactly like password auth):

    hh add-firewalla

It asks for your MSP domain - `yourname.firewalla.net`, not the box's LAN address
- and the token, which it stores in the vault where the agent cannot read it.
There is no TLS pin here, unlike UniFi: an MSP domain has a publicly trusted
certificate, so ordinary CA verification already applies and is the stronger
check.
