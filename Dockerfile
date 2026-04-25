FROM zzci/ubase

RUN wget -qO - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - && \
    echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get -y update && env DEBIAN_FRONTEND="noninteractive" apt-get --no-install-recommends -y install  \
    # GUI BASE
    dbus-x11 \
    procps \
    psmisc \
    xdg-utils \
    mesa-utils \
    x11-utils \
    x11-xserver-utils \
    libxv1 \
    xinit \
    xserver-common \
    xvfb \
    # minimal window manager + taskbar + native terminal
    openbox \
    tint2 \
    xterm \
    # fonts + LCD-aware rendering
    fonts-noto-cjk \
    fonts-noto-core \
    fonts-noto-ui-core \
    fonts-liberation \
    fonts-dejavu-core \
    fontconfig \
    # for kasmvnc
    xauth \
    # for port forwarding
    socat \
    # app
    google-chrome-stable && \
    # install kasmvnc
    wget -qO /tmp/kasmvnc.deb https://github.com/kasmtech/KasmVNC/releases/download/v1.4.0/kasmvncserver_jammy_1.4.0_amd64.deb && \
    apt-get install -y /tmp/kasmvnc.deb && rm -f /tmp/kasmvnc.deb && \
    # create runtime user (create_user also writes NOPASSWD sudoers)
    /build/bin/create_user zzci && \
    # do clean
    apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

EXPOSE 80 9222

# Service composition via ubase ZSRV_<KEY>=<conf-filename> env vars.
# X provider: ZSRV_DESKTOP=vnc (KasmVNC + tint2 panel) | xvfb (headless)
# Apps:       ZSRV_CDP=cdp (chrome + 9222 forward)
# Disable any at runtime with -e ZSRV_<KEY>=0
ENV ZSRV_DESKTOP=vnc ZSRV_CDP=cdp

ADD rootfs /

RUN chmod -R 0755 /build && chmod -R 0644 /build/config

CMD ["/start.sh"]
