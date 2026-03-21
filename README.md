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

## Using with agent-browser

[agent-browser](https://www.npmjs.com/package/agent-browser) is a CLI tool that lets AI agents control a browser via CDP (Chrome DevTools Protocol). This image exposes CDP on port `9222`, making it easy to connect.

### Connect via CDP port

```bash
# Start the container
docker run -d --name chrome --shm-size 2g \
  -p 80:80 -p 9222:9222 \
  --security-opt seccomp=unconfined \
  zzci/chrome

# Connect agent-browser to the running Chrome instance
agent-browser connect 9222
```

### Connect via CDP WebSocket URL

If the container is running on a remote host, use the full WebSocket URL:

```bash
agent-browser --cdp "ws://your-host:9222/devtools/browser" snapshot
```

### Configure as default CDP endpoint

Create `~/.agent-browser/config.json` to avoid passing the flag every time:

```json
{
  "cdp": "ws://localhost:9222/devtools/browser"
}
```

Then simply run commands without the `--cdp` flag:

```bash
agent-browser snapshot
agent-browser navigate "https://example.com"
agent-browser click 500 300
```

### Full configuration reference

`~/.agent-browser/config.json` has two mutually exclusive modes:

**CDP mode** — connect to an existing browser (recommended with this Docker image):

```json
{
  "native": true,
  "cdp": "ws://localhost:9222/devtools/browser"
}
```

**Local launch mode** — let agent-browser start its own browser:

```json
{
  "native": true,
  "executablePath": "/usr/bin/google-chrome-stable",
  "profile": "/home/chrome/chrome-data",
  "args": "--no-sandbox,--disable-gpu,--disable-software-rasterizer"
}
```

| Field | Mode | Description |
|-------|------|-------------|
| `native` | Both | Use the native Rust binary for faster CLI performance |
| `cdp` | CDP | WebSocket URL of the running browser's DevTools endpoint |
| `executablePath` | Local | Path to the Chrome/Chromium binary |
| `profile` | Local | Browser profile directory |
| `args` | Local | Comma-separated Chrome launch flags |

When `cdp` is set, the `executablePath`, `profile`, and `args` fields are ignored.

### Docker Compose with agent-browser

```yaml
services:
  chrome:
    image: zzci/chrome
    shm_size: 2g
    security_opt:
      - seccomp:unconfined
    ports:
      - "9222:9222"
```

Then connect:

```bash
agent-browser connect 9222
agent-browser navigate "https://example.com"
agent-browser snapshot
```

### Common commands

| Command | Description |
|---------|-------------|
| `agent-browser connect <port>` | Connect to a CDP endpoint |
| `agent-browser snapshot` | Take a screenshot of the current page |
| `agent-browser navigate <url>` | Navigate to a URL |
| `agent-browser click <x> <y>` | Click at coordinates |
| `agent-browser type "text"` | Type text into the focused element |
| `agent-browser scroll <deltaX> <deltaY>` | Scroll the page |

## Notes

- Chrome remote debugging listens internally on `19222` and is forwarded to external port `9222` by `socat`.
- The browser profile lives in `/home/chrome/chrome-data`.
