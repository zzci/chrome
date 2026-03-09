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
    xserver-xorg-video-dummy \
    # minimal window manager
    openbox \
    # fonts
    fonts-noto-cjk \
    fonts-noto-core \
    fonts-noto-ui-core \
    # for kasmvnc
    xauth \
    # for port forwarding
    socat \
    # app
    google-chrome-stable && \
    # install kasmvnc
    wget -qO /tmp/kasmvnc.deb https://github.com/kasmtech/KasmVNC/releases/download/v1.4.0/kasmvncserver_jammy_1.4.0_amd64.deb && \
    apt-get install -y /tmp/kasmvnc.deb && rm -f /tmp/kasmvnc.deb && \
    # create runtime user for chrome sandbox
    id -u chrome >/dev/null 2>&1 || useradd -m -s /bin/bash chrome && \
    mkdir -p /home/chrome/chrome-data && chown -R chrome:chrome /home/chrome && \
    # do clean
    apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*

EXPOSE 80 9222

ADD rootfs /

RUN chmod -R 0755 /build && chmod -R 0644 /build/config

CMD ["/start.sh"]
