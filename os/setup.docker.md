# Install packages

```bash
apt-get install -y build-essential
cd /tmp; curl https://www.kernel.org/pub/linux/utils/util-linux/v2.24/util-linux-2.24.tar.gz | tar -zxf-; cd util-linux-2.24;
./configure --without-ncurses
make nsenter && sudo cp nsenter /usr/local/bin
```

# Setup funcs

```bash
function docker-enter() {
    PID=$(docker inspect --format "{{ .State.Pid }}" $1)
    nsenter --target $PID --mount --uts --ipc --net --pid
}

function cip() {
    docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1
}
```
