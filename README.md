# Chrome

A minimal Chrome-in-Docker image with KasmVNC for browser access and a DevTools port for automation.

It runs:
- KasmVNC on port `80`
- Chrome DevTools on port `9222`
- `openbox`, `socat`, and `chrome` under `supervisord`

## Quick Start

```bash
docker run -d \
  --name chrome \
  --shm-size 2g \
  -p 80:80 \
  -p 9222:9222 \
  --security-opt seccomp=unconfined \
  zzci/chrome
```

Then open `http://localhost` and sign in with:

- user: `chrome`
- password: `chrome`

## Build

```bash
./aa build
./aa run
```

## Docker Compose

The included `docker-compose.yml` sets:

- `shm_size: 2g`
- `security_opt: seccomp:unconfined`

If you run the container manually, keep those settings. Chrome is started from `/build/bin/start_chrome`, which prepares `/home/chrome/chrome-data` and then switches to the `chrome` user before launching the browser.

## Runtime Layout

- `rootfs/build/bin/start_vnc`: starts KasmVNC
- `rootfs/build/bin/start_x`: starts DBus and `supervisord`
- `rootfs/build/bin/start_chrome`: initializes Chrome profile directories and launches Chrome as `chrome`
- `rootfs/build/config/supervisord_x.conf`: manages `openbox`, `socat`, and `chrome`

## Notes

- Chrome remote debugging listens internally on `19222` and is forwarded to external port `9222` by `socat`.
- The browser profile lives in `/home/chrome/chrome-data`.
