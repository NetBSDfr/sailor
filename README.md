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

[0]: https://en.wikipedia.org/wiki/Chroot
[1]: http://pkgin.net
