FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ARG ONEC_VERSION=8.5.1.1529

# 1. Установка графического окружения (Xvfb + XFCE + x11vnc), шрифтов и русской локали
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    tzdata \
    ca-certificates \
    wget \
    curl \
    unzip \
    xvfb \
    x11vnc \
    xauth \
    xfce4 \
    dbus-x11 \
    libwebkit2gtk-4.0-37 \
    libgtk-3-0 \
    libx11-6 \
    libxcursor1 \
    libxft2 \
    libxrandr2 \
    libxtst6 \
    libfontconfig1 \
    libgsf-1-114 \
    libglib2.0-0 \
    libodbc1 \
    libkrb5-3 \
    ttf-mscorefonts-installer \
    fontconfig \
    && locale-gen ru_RU.UTF-8 \
    && update-locale LANG=ru_RU.UTF-8 \
    && fc-cache -fv \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_ALL=ru_RU.UTF-8 \
    TZ=Europe/Moscow \
    DISPLAY=:99

# 2. Установка OneScript 1.9.0 и LTS-версии vanessa-runner@2.6.1
RUN wget -q https://github.com/EvilBeaver/OneScript/releases/download/v1.9.4/onescript-engine_1.9.4_all.deb \
    && apt-get update \
    && apt-get install -y ./onescript-engine_1.9.4_all.deb \
    && rm onescript-engine_1.9.4_all.deb \
    && opm update opm \
    && opm install vanessa-runner@2.6.1 \
    && opm install add \
    && rm -rf /var/lib/apt/lists/*

# 3. Установка платформы 1С 8.5.1.1529 (Толстый + Тонкий клиент + Серверные библиотеки)
COPY dist/setup-full-${ONEC_VERSION}-x86_64.run /tmp/setup.run
RUN chmod +x /tmp/setup.run \
    && /tmp/setup.run --mode unattended --enable-components server,client_full,client_thin,ru \
    && rm -f /tmp/setup.run

# Путь к исполняемым файлам 1С 8.5
ENV PATH="/opt/1cv8/x86_64/${ONEC_VERSION}:${PATH}"

# 4. Копируем обработку vanessa-automation-single.epf
RUN mkdir -p /opt/vanessa
COPY dist/vanessa-automation/ /opt/vanessa/

RUN apt-get update && apt-get install -y --no-install-recommends \
    libglu1-mesa \
    libgl1 \
    libenchant-2-2 \
    libharfbuzz-icu0 \
    libsecret-1-0 \
    libnotify4 \
    libxslt1.1 \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# 5. Скрипт запуска виртуального монитора + VNC (поддержка динамических дисплеев)
RUN printf '#!/bin/bash\n\
DISPLAY_NUM=${DISPLAY:-:99}\n\
LOCK_FILE="/tmp/.X${DISPLAY_NUM#:}-lock"\n\
rm -f $LOCK_FILE\n\
Xvfb $DISPLAY_NUM -screen 0 1920x1080x24 -ac &\n\
sleep 2\n\
startxfce4 &\n\
x11vnc -display $DISPLAY_NUM -forever -nopw -quiet -rfbport 5900 &\n\
exec "$@"\n' > /entrypoint.sh && chmod +x /entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]