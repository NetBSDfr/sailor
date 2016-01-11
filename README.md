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
likely name for service: apache
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

`run_at_*` commands are run in the chroot:

* `run_at_build`: run command at build time, can be repeated
* `run_at_start`: run command at start time, can be repeated
* `run_at_stop`: run command at stop time, can be repeated
* `run_at_destroy`: run command at destroy time, can be repeated

## real life example

Fire up a fully working [nginx][3] + [php-fpm][4] and isolated stack on
Mac OS X in less than 5 minutes:

[Download and install Save OS X][5]

```
$ git clone https://github.com/NetBSDfr/sailor.git
$ cd sailor
$ sudo -E ./sailor.sh build examples/nginxphp.conf
$ sudo -E ./sailor.sh start examples/nginxphp.conf
Starting nginx.
Starting php_fpm.

nginx is listening on port 1080

$ curl -I localhost:1080
HTTP/1.1 200 OK
Server: nginx/1.9.4
Date: Mon, 11 Jan 2016 15:40:53 GMT
Content-Type: text/html; charset=UTF-8
Connection: keep-alive
X-Powered-By: PHP/5.6.13
```

PHP source code can be found in `nginxphp/var/www/php` which you can `chown` to
your own user and populate with the PHP code you want.

[0]: https://en.wikipedia.org/wiki/Chroot
[1]: http://pkgin.net
[2]: http://saveosx.org/
[3]: http://nginx.org/
[4]: http://php.net/manual/en/install.fpm.php
[5]: http://saveosx.org/download-and-install/
