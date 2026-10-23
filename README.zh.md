# Chrome

[English](./README.md)

最小化的 Chrome-in-Docker 镜像，提供基于浏览器的 KasmVNC 桌面访问和用于自动化的 CDP（Chrome DevTools Protocol）端口。

## 包含组件

- **KasmVNC** 监听 `80` 端口 —— 集成 X server 与 web 客户端
- **Chrome** 与 **Firefox** + tint2 任务栏 + openbox 窗口管理器,跑在同一个 X 会话中
- **Chrome DevTools Protocol** 监听 `9222` 端口(由内部 `19222` 转发而来)
- **GPU 加速**:透传 `/dev/dri` 后自动启用,没有则退回软件渲染:Chrome 渲染 + 桌面画面流的硬件 H.264/HEVC/AV1 编码(KasmVNC 1.5,WebCodecs)
- **fcitx5 + rime** 中文输入(拼音,默认 `Ctrl+\` 切换)
- **彩色 emoji** 通过 `fonts-noto-color-emoji`
- **xterm 终端**、**Chrome**、**Firefox** 启动器,集成在底部 panel

服务编排基于 [zzci/ubase](https://hub.docker.com/r/zzci/ubase) 的 `ZSRV_<KEY>=<conf>` 机制 —— 每个服务都可独立启停。

## 快速开始

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

打开 `http://localhost` 即可访问桌面，CDP 端点为 `ws://localhost:9222/devtools/browser`。无需登录。

`/home/zzci` 挂载持久化整个用户家目录（chrome profile、扩展、历史、dotfile）。容器启动时会自动把内部用户 UID/GID 对齐到宿主目录的属主，无需任何额外配置。

## 模式选择

通过 `ZSRV_DESKTOP` 选择 X 提供方：

| 环境变量 | 启用栈 | Web 端口 | 适用场景 |
|---------|-------|---------|---------|
| `ZSRV_DESKTOP=vnc`（默认） | KasmVNC + openbox | 80 | 完整 web 桌面 |
| `ZSRV_DESKTOP=xvfb` | Xvfb（无显示） | — | 仅 CDP / 最小开销 |
| `ZSRV_DESKTOP=0` | 无 X | — | 自带 X 提供方 |

通过 `ZSRV_CDP` 与 `CDP_MODE` 控制 CDP 行为：

| 环境变量 | 行为 |
|---------|------|
| `ZSRV_CDP=cdp`（默认） | chrome 自动启动，并会被保活（CDP 客户端始终能连） |
| `ZSRV_CDP=0` | 不自动启动 chrome（用户自己从 panel 启动） |
| `CDP_MODE=remote`（默认） | `socat` 把 chrome 的 19222 暴露到 `0.0.0.0:9222` |
| `CDP_MODE=local` | 不做端口转发；CDP 仅容器内 `127.0.0.1:19222` 可达 |

桌面会话服务，各自由 supervisord 独立守护、挂了自动拉起（默认全部开启）：

| 环境变量 | 行为 |
|---------|------|
| `ZSRV_dbus=true` | 会话 DBus，固定地址 `unix:path=/tmp/.dbus-session` |
| `ZSRV_fcitx5=true` | fcitx5 + rime 输入法（依赖 `ZSRV_dbus`） |
| `ZSRV_panel=true` | tint2 面板（启动器、任务栏、输入法指示、时钟） |

任一项设为 `0` 即可关闭，例如 xvfb 模式下没人看面板，可加 `-e ZSRV_panel=0`。

其它运行时配置:

| 环境变量 | 默认 | 说明 |
|---------|------|------|
| `RUN_USER` | `zzci` | 运行时用户名,首次启动时若不存在会自动创建 |
| `PUID` / `PGID` | 自动 | 显式指定 RUN_USER 的 uid/gid(默认根据 `/home/$RUN_USER` 属主自动检测) |
| `ROOT_BG` | `#cce8cf` | 桌面背景色,任意 `xsetroot` 接受的色值 |
| `GPU` | `auto` | `auto` 在 `/dev/dri` 存在且可访问时启用硬件加速;`off` 强制软件渲染 |
| `DRI_NODE` | `/dev/dri/renderD128` | 宿主机多卡时指定使用哪个 render node |

### 常见组合

```bash
# 默认 —— 桌面 + 远程 CDP
docker run -d -p 80:80 -p 9222:9222 ... zzci/chrome

# 仅 CDP（无桌面，最小占用）
docker run -d -p 9222:9222 -e ZSRV_DESKTOP=xvfb zzci/chrome

# 仅桌面，不自动开 chrome（用户自己开）
docker run -d -p 80:80 -e ZSRV_CDP=0 zzci/chrome

# 仅容器内 CDP（同一 docker network 的兄弟容器调用）
docker run -d -e CDP_MODE=local zzci/chrome
```

## 构建

```bash
./aa build       # 构建镜像，tag 为 `chrome`
./aa run         # docker compose up
```

## Docker Compose

自带的 `docker-compose.yml` 已经设好了 `shm_size: 2g`、`seccomp:unconfined` 和 `/dev/dri` 透传。前两项是**必需**的 —— 默认 64MB 的 shm 会让 Chrome 渲染进程卡死，默认 seccomp 配置会让沙箱起不来。

文件里的可选段按需打开：

- `./home:/home/zzci` 挂载持久化用户家目录
- `PUID` / `PGID` 显式指定（默认会自动检测）

宿主机没有 `/dev/dri` 时，删掉 `devices:` 段或设置 `GPU=off`。

## 目录结构

```
rootfs/build/services/         服务清单（默认全部禁用，由 ZSRV 启用）
  vnc.conf                     KasmVNC + openbox
  xvfb.conf                    Xvfb（轻量 X 提供方）
  cdp.conf                     chrome（保活循环）+ socat 9222→19222
  dbus.conf                    会话 DBus（固定地址）
  fcitx5.conf                  fcitx5 输入法守护进程
  panel.conf                   tint2 面板

rootfs/build/bin/
  init_user                    一次性 root 初始化:用户/UID/GID/家目录
  start_vnc                    KasmVNC 入口,先 init_user 再切到 RUN_USER
  start_x                      xstartup: openbox
  start_dbus                   在固定地址启动会话 DBus
  start_fcitx5                 fcitx5(首次配置 + 前台运行)
  start_panel                  tint2 面板
  session_exec                 等 X 会话就绪后以 RUN_USER 执行命令
  session_env                  会话公共环境(DISPLAY、DBus 地址、输入法变量)
  start_xvfb                   启动 Xvfb :1(无显示模式)
  start_cdp                    chrome 保活循环 + socat 端口转发
  start_chrome                 CDP 模式 chrome 启动(被 start_cdp 调用)
  chrome_flags                 chrome 公共参数集(两个启动器共同 source)
  launch_chrome                交互式 chrome(panel 启动器目标)
  launch_firefox               交互式 firefox(panel 启动器目标)
  gpu_node                     输出可用的 DRI render node,没有则输出空
  open_terminal                xterm 终端启动器
  wait_for_x                   阻塞等待 :1 display ready

rootfs/build/config/
  kasmvnc.yaml                 KasmVNC 配置
  tint2rc                      panel 布局(启动器 + 任务列表 + 时钟)
  fcitx5-config                fcitx5 热键(Ctrl+\ 切换)
  fcitx5-profile               默认输入法组(keyboard-us + rime)
  fcitx5-rime.conf             强制加载 rime addon(覆盖 OnDemand=True)
  rime-default.custom.yaml     rime schema 列表(仅 pinyin_simp)

rootfs/build/share/applications/
  terminal.desktop             tint2 启动器 — 终端
  chrome.desktop               tint2 启动器 — chrome(→ launch_chrome)
  firefox.desktop              tint2 启动器 — firefox(→ launch_firefox)

rootfs/etc/fonts/local.conf    LCD 子像素抗锯齿,文字更清晰
```

## 输入法

`fcitx5 + rime` 默认启用简体拼音 schema。

| 快捷键 | 行为 |
|--------|------|
| `Ctrl+\` | 在 `keyboard-us`(直通)和 `rime`(拼音)间切换 |
| `Shift+空格` | 备用触发键(防止宿主系统拦截 `Ctrl+\`) |

改快捷键编辑容器内 `~/.config/fcitx5/config`,例如:

```ini
[Hotkey/TriggerKeys]
0=Control+space
```

换 rime schema 编辑 `~/.local/share/fcitx5/rime/default.custom.yaml`。镜像只内置了 `pinyin_simp`,如需注音、仓颉等先装对应的 `rime-data-*` 包。

## 运行时服务管理

```bash
docker exec chrome sctl status                # 列出所有服务状态
docker exec chrome sctl restart cdp           # 重启 chrome+转发服务
docker exec chrome sctl disable cdp           # 关闭 cdp，下次启动不再加载
```

## 配合 agent-browser

[agent-browser](https://www.npmjs.com/package/agent-browser) 是给 AI agent 用的浏览器自动化 CLI，通过 CDP 控制浏览器。

```bash
# CDP 模式 —— 连容器内运行的 chrome
agent-browser connect 9222

# 或者通过 WebSocket URL 连远程 host
agent-browser --cdp "ws://your-host:9222/devtools/browser" snapshot
```

`~/.agent-browser/config.json` 配上之后就不用每次带 `--cdp`：

```json
{
  "native": true,
  "cdp": "ws://localhost:9222/devtools/browser"
}
```

| 命令 | 说明 |
|------|------|
| `agent-browser connect <port>` | 连接到 CDP 端点 |
| `agent-browser snapshot` | 截图当前页面 |
| `agent-browser navigate <url>` | 跳转到指定 URL |
| `agent-browser click <x> <y>` | 在坐标点击 |
| `agent-browser type "text"` | 在焦点元素输入文本 |
| `agent-browser scroll <dx> <dy>` | 滚动页面 |

## 注意事项

- chrome CDP 内部监听 `19222`,由 `socat` 转发到对外 `9222`(仅 `CDP_MODE=remote` 时)
- CDP 服务和 panel 启动的 chrome 共享 `--user-data-dir=$HOME/.config/chrome`,登录一次两边都识别。挂载 `/home/$RUN_USER` 持久化
- 整个 X 会话(vncserver、openbox、tint2、fcitx5、chrome)都跑在 `RUN_USER` 下,桌面里没有 root 进程。终端里可以直接 `sudo` 无需密码
- 容器重启时会自动清理上次残留的 SingletonLock,不会出现 "profile in use by another chrome" 的错误
- vnc 模式下若想让用户能从桌面里关 chrome 不被自动拉起,加 `-e ZSRV_CDP=0`
