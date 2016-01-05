# sailor

Wanabe portable container system

**THIS IS A WORK IN PROGRESS, DO NOT USE IT!**

**ONLY WORKS ON NetBSD BY NOW** (and limited support for OSX)

`sailor` is based on [chroot][0] and [pkgin][1], it will create a `chrooted`
environment containing _only_ the needed pieces in order to install and run a
service.

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

## configuration file

A ship is defined by its configuration file which contains:

* `services`: the `rc.d` friendly names for services to run
* `shipname`: the convenient name you'd like to give to your ship
* `packages`: the packages you'd like to install within your ship
* `shippath`: full path to your ship
* `shipbins`: binaries from the host system you'd like to copy to the ship
* `ro_mounts`: read-only mount points to the ship
* `rw_mounts`: read/write mount points to the ship

[0]: https://en.wikipedia.org/wiki/Chroot
[1]: http://pkgin.net
