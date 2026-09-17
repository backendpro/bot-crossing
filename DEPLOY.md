# Running it as a service

This fork adds a container image and a compose file, so the colony can run on a box you do
not sit in front of and be read from a phone or a laptop elsewhere. Upstream is written for
the machine you work on; three things change when it moves to a server.

## What changes on a server

**Live-session detection needs the host's pid namespace.** A thread counts as running when
its registered pid answers `kill(pid, 0)`. Inside its own namespace a container sees none of
the host's processes, so every astronaut potters about as though nothing were happening.
`pid: host` fixes it, and the container must run as the uid that owns those processes —
a different uid gets EPERM from the signal, which the scan reads as "gone".

**Nothing here can open a thread.** `Open`, `New conversation` and `Finder` hand a
`harness://` URL or a path to the OS opener. A headless box has nothing to hand it to, and
the opener would act on the *server* rather than on the device whose browser is looking at
the colony. `BOT_CROSSING_NO_LAUNCH=1` makes that explicit: the thread's own button greys
out, and the other two answer with why instead of failing obscurely.

**A proxy changes the Host header.** The server only answers requests whose `Host` is one it
recognises — that is what stops DNS rebinding. It learns the machine's own addresses, but a
tunnel or reverse proxy passes on the *name* the browser asked for, which is not among them,
so every `/api/*` call is refused and the page loads and stays empty. List those names in
`BOT_CROSSING_ALLOWED_HOSTS`. Inside a container the automatic list is useless anyway: the
addresses it finds are the bridge's.

## Up

```bash
cp .env.example .env    # then fill CLAUDE_HOME in
docker compose up -d --build
```

It binds loopback only. Put whatever you already use in front of it — a tunnel, a reverse
proxy — and add that hostname to `BOT_CROSSING_ALLOWED_HOSTS`.

**Before you expose it, know what it hands out.** There is no login, and anyone who reaches
the port is shown every thread title, every opening prompt, every working directory and
branch on the machine. Upstream's README is blunt about this and it is worth repeating here:
fine on a network you own, not something to leave reachable from anywhere.

## What it touches

| | |
| --- | --- |
| Reads | The harness session records under `CLAUDE_HOME`, mounted read-only |
| Writes | `data/colony.json` in its own volume — the map layout and what you archived |
| Sends | Nothing |
