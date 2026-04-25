# Chrome

[中文文档](./README.zh.md)

A minimal Chrome-in-Docker image with KasmVNC for browser-based desktop access and a Chrome DevTools Protocol (CDP) port for automation.

## What's inside

- **KasmVNC** on port `80` — X server + web client in one
- **Chrome** + tint2 panel + openbox WM on the X session
- **Chrome DevTools Protocol** on port `9222` (forwarded from internal `19222`)
- **xterm** terminal launcher in the panel for in-desktop shell access

Composition is driven by [zzci/ubase](https://hub.docker.com/r/zzci/ubase)'s `ZSRV_<KEY>=<conf>` mechanism — every service is independently toggleable.

## Quick Start

```bash
docker run -d \
  --name chrome \
  --shm-size 2g \
  --security-opt seccomp=unconfined \
  -p 80:80 \
  -p 9222:9222 \
  -v $(pwd)/home:/home/zzci \
  zzci/chrome
```

Open `http://localhost` for the desktop, connect to `ws://localhost:9222/devtools/browser` for CDP. No login required.

The `/home/zzci` mount persists the entire user home (chrome profile, extensions, history, dotfiles). UID/GID are auto-reconciled at startup to match the host directory's owner — no extra config needed.

## Modes

Switch X provider via `ZSRV_DESKTOP`:

| ENV | Stack | Web port | Use case |
|-----|-------|----------|----------|
| `ZSRV_DESKTOP=vnc` (default) | KasmVNC + tint2 + openbox | 80 | Full web desktop |
| `ZSRV_DESKTOP=xvfb` | Xvfb (headless) | — | CDP-only / lowest overhead |
| `ZSRV_DESKTOP=0` | none | — | Bring-your-own X |

Switch CDP behavior via `ZSRV_CDP` and `CDP_MODE`:

| ENV | Effect |
|-----|--------|
| `ZSRV_CDP=cdp` (default) | chrome auto-starts and is kept alive for CDP clients |
| `ZSRV_CDP=0` | no chrome auto-launch (start it manually from the panel) |
| `CDP_MODE=remote` (default) | `socat` exposes chrome's 19222 on `0.0.0.0:9222` |
| `CDP_MODE=local` | no port forward; CDP only reachable inside the container at `127.0.0.1:19222` |

### Examples

```bash
# Default — desktop + remote CDP
docker run -d -p 80:80 -p 9222:9222 ... zzci/chrome

# Headless CDP only (no web desktop, smaller footprint)
docker run -d -p 9222:9222 -e ZSRV_DESKTOP=xvfb zzci/chrome

# Pure desktop, no chrome auto-start (user opens chrome from the panel)
docker run -d -p 80:80 -e ZSRV_CDP=0 zzci/chrome

# Internal-only CDP (other container in the same docker network)
docker run -d -e CDP_MODE=local zzci/chrome
```

## Build

```bash
./aa build       # build image as `chrome`
./aa run         # docker compose up
```

## Docker Compose

The bundled `docker-compose.yml` sets the required `shm_size: 2g` and `seccomp:unconfined`. Uncomment the optional sections in it to enable:

- volume mount of `./home:/home/zzci` for persistent profile
- `PUID` / `PGID` env override (auto-detected by default)
- `/dev/dri` passthrough for VAAPI hardware video encoding (KasmVNC encoder; needs Intel/AMD GPU)

## Layout

```
rootfs/.init/services/         service catalog (default-disabled, enabled via ZSRV)
  vnc.conf                     KasmVNC + dbus + tint2 + openbox
  xvfb.conf                    Xvfb (alternative X provider)
  cdp.conf                     chrome (kept alive) + socat 9222->19222

rootfs/build/bin/
  init_user                    one-shot UID/GID reconcile + home chown (root)
  start_vnc                    KasmVNC bootstrap, runs init_user first
  start_x                      vncserver xstartup: dbus + tint2 + openbox
  start_xvfb                   Xvfb :1
  start_cdp                    chrome keep-alive loop + socat
  start_chrome                 single-shot chrome launch (used by start_cdp)
  open_terminal                opens xterm as zzci (panel terminal launcher)
  wait_for_x                   blocks until DISPLAY :1 is ready

rootfs/build/config/
  kasmvnc.yaml                 KasmVNC settings (encoding tuning, idle timeout, ...)
  tint2rc                      panel layout (terminal launcher + taskbar + clock)

rootfs/etc/fonts/local.conf    LCD subpixel rendering for sharper text
```

## Service control at runtime

```bash
docker exec chrome sctl status                # list all services
docker exec chrome sctl stop chrome           # not applicable; chrome lives inside cdp
docker exec chrome sctl restart cdp           # restart the chrome+forwarder service
docker exec chrome sctl disable cdp           # turn cdp off until next start
```

## Using with agent-browser

[agent-browser](https://www.npmjs.com/package/agent-browser) is a CLI for AI agents that drives a browser via CDP.

```bash
# CDP mode — connect to the running chrome inside the container
agent-browser connect 9222

# Or via WebSocket URL on a remote host
agent-browser --cdp "ws://your-host:9222/devtools/browser" snapshot
```

`~/.agent-browser/config.json` to skip the flag every time:

```json
{
  "native": true,
  "cdp": "ws://localhost:9222/devtools/browser"
}
```

| Command | Description |
|---------|-------------|
| `agent-browser connect <port>` | Connect to a CDP endpoint |
| `agent-browser snapshot` | Take a screenshot |
| `agent-browser navigate <url>` | Navigate to a URL |
| `agent-browser click <x> <y>` | Click at coordinates |
| `agent-browser type "text"` | Type into the focused element |
| `agent-browser scroll <dx> <dy>` | Scroll |

## Notes

- Chrome's CDP listens internally on `19222` and is forwarded to external `9222` by `socat` (only in `CDP_MODE=remote`).
- The browser profile lives at `/home/zzci/.config/google-chrome/` (chrome's default location). Mount `/home/zzci` to persist it.
- `chrome` runs as the `zzci` user (UID 1000). Inside the panel terminal you can `sudo` without a password.
- Singleton lock files left over from a previous container are automatically cleaned at chrome start.
