# Local example

Applies circuit-selenium to a throwaway Rocky Linux 10 container with systemd. You need Conn3x, Podman, and about 3 GB of memory free for the container.

The Grid runs under Podman inside that container, so the host container is privileged, which is simplest with rootful Podman. On a Mac, use the Podman machine's root connection. On Linux, use `sudo podman`:

```sh
export CONTAINER_CONNECTION=podman-machine-default-root   # macOS
export PODMAN="sudo podman"                               # Linux
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The first apply pulls about 3 GB of images. The second plan says `No changes.`

The Grid listens on `127.0.0.1:4444` inside the container, which is where its loopback default keeps it, so you can't reach it from your own machine. To see it work, `check.sh` asks it for a real browser session, loads a page served only inside the node, and reads the page's title back:

```sh
podman exec -i circuit-selenium sh -s chromium < check.sh
```

To try Firefox as well, apply with `-var 'browsers=["chromium","firefox"]'`, then run `check.sh` with `chromium firefox` in place of `chromium`.

`up.sh` listens on `127.0.0.1:2222`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` stops the container, which removes it and its volume, and deletes the key and the state.
