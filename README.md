# sailor

## Wannabe portable container system

**WARNING** this project is still under heavy development, use it at your own
risk and `pull` frequently!

`sailor` is based on [chroot][0] and [pkgin][1], it will create a `chrooted`
environment containing _only_ the needed pieces in order to install and  / or
run a service.

**For now** _NetBSD_ and _Darwin / Mac OS X_ are the primary targets of this
project.

## demo

![gif](http://imil.net/stuff/sailor.gif)

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

* Run commands in the ship

```
# ./sailor.sh run 4ecd1896d35a66c7 ps axuwww
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
* `ip_<iface>`: IP alias to add to `<iface>`

`run_at_*` commands are run in the chroot:

* `run_at_build`: run command at build time, can be repeated
* `run_at_start`: run command at start time, can be repeated
* `run_at_stop`: run command at stop time, can be repeated
* `run_at_destroy`: run command at destroy time, can be repeated

## real life examples

#### Fire up a fully working and isolated [nginx][3] + [php-fpm][4] stack

[Download and install Save OS X][5] if running Mac OS X

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

`nginx` configuration is located in `nginxphp/opt/pkg/etc/nginx` (on OSX), you
might want to change its listen port in
`nginxphp/opt/pkg/etc/nginx/global.conf`

#### Fire up a fully working and isolated [nginx][3] + [nodejs][6] stack

[Download and install Save OS X][5] if running Mac OS X

```
$ git clone https://github.com/NetBSDfr/sailor.git
$ cd sailor
$ sudo -E ./sailor.sh build examples/nginxnode.conf
$ sudo -E ./sailor.sh start examples/nginxnode.conf 
Starting nginx.
[PM2] Spawning PM2 daemon
[PM2] PM2 Successfully daemonized
[PM2] Starting hello.js in fork_mode (1 instance)
[PM2] Done.
┌──────────┬────┬──────┬───────┬────────┬─────────┬────────┬────────┬──────────┐
│ App name │ id │ mode │ pid   │ status │ restart │ uptime │ memory │ watching │
├──────────┼────┼──────┼───────┼────────┼─────────┼────────┼────────┼──────────┤
│ hello    │ 0  │ fork │ 12874 │ online │ 0       │ 0s     │ 0 B    │ disabled │
└──────────┴────┴──────┴───────┴────────┴─────────┴────────┴────────┴──────────┘
 Use `pm2 show <id|name>` to get more details about an app

nginx is listening on port 1080

$ curl http://localhost:1080/
Hello from inside the chroot!
```

In this example, an [nginx][3] server is configured to act as a reverse proxy
to a `nodejs` small web app. The application is started by the [pm2][7] process
manager and listens on port 8080. This setup is based on [this great
documentation][8] and automatize all the steps described.

`node` source code can be found in `nginxphp/var/node` which you can `chown` to
your own user and populate with the `node` code you want.


[0]: https://en.wikipedia.org/wiki/Chroot
[1]: http://pkgin.net
[2]: http://saveosx.org/
[3]: http://nginx.org/
[4]: http://php.net/manual/en/install.fpm.php
[5]: http://saveosx.org/download-and-install/
[6]: https://nodejs.org/en/
[7]: http://pm2.keymetrics.io/
[8]: https://www.digitalocean.com/community/tutorials/how-to-set-up-a-node-js-application-for-production-on-ubuntu-14-04
