# sailor

## Wannabe portable container system

**WARNING** this project is still under heavy development, use it at your own
risk

`sailor` is based on [chroot][0] and [pkgin][1], it will create a `chrooted`
environment containing _only_ the needed pieces in order to install and  / or
run a service.

**For now** _NetBSD_ and _Darwin / Mac OS X_ are the primary targets of this
project.

## requirements

`sailor` needs the following third party tools:

* `pkg_install`
* `pkgin`
* `rsync`

_NetBSD_ users should have those by default, except for `rsync` which can be
installed with `pkgin`.

_Mac OS X_ users are encouraged to use [Save OS X][2] in order to have a working
environment within seconds.

## usage

* Create a ship

```
# ./sailor.sh build ./nginx.conf
```

* Run the ship

```
# ./sailor.sh start ./nginx.conf
Starting nginx.
```

* List running ships

```
# ./sailor.sh ls
4ecd1896d35a66c7 - nginx - /home/imil/src/sailor/nginx.conf
```

* Stop a ship

```
# ./sailor.sh stop 4ecd1896d35a66c7
```

* Destroy a ship

```
# ./sailor.sh destroy ./nginx.conf
```

* Display the `rc.d` name for a service

```
# ./sailor.sh rcd apache
Likely name for service name: apache
```

## configuration file

A ship is defined by its configuration file which contains:

_mandatory_

* `shipname`: the convenient name you'd like to give to your ship
* `shippath`: full path to your ship

_most likely_

* `services`: the `rc.d` friendly names for services to run(*)
* `packages`: the packages you'd like to install within your ship

(*) the `rc.d` or _init_ script is generally bundled with the service package,
it is it which is capable of starting or stopping the service. Most of the
times, it has the same name as the service itself, but it is safer to check this
out using `sailor`'s `rc.d` function.

_optional_

* `shipbins`: binaries from the host system you'd like to copy to the ship
* `ro_mounts`: read-only mount points to the ship (NetBSD only for now)
* `rw_mounts`: read/write mount points to the ship (NetBSD only for now)
* `run_at_build`: run command at build time, can be repeated
* `run_at_start`: run command at start time, can be repeated
* `run_at_stop`: run command at stop time, can be repeated
* `run_at_destroy`: run command at destroy time, can be repeated

[0]: https://en.wikipedia.org/wiki/Chroot
[1]: http://pkgin.net
[2]: http://saveosx.org/
