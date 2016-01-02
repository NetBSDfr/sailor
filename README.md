# sailor

Wanabe portable container system

**THIS IS A WORK IN PROGRESS, DO NOT USE IT!**

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
