FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ARG ONEC_VERSION=8.5.1.1529
ARG GH_HOST=github.com
ARG OSCRIPT_VER=1.9.4

# 1. Установка графического окружения (Xvfb + XFCE + x11vnc), шрифтов, imagemagick и русской локали
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
    imagemagick \
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

# 2. Установка OneScript 1.9.4 и LTS-версии vanessa-runner@2.6.1
RUN wget -q -O /tmp/onescript-engine.deb "https://${GH_HOST}/EvilBeaver/OneScript/releases/download/v${OSCRIPT_VER}/onescript-engine_${OSCRIPT_VER}_all.deb" \
    && apt-get update \
    && apt-get install -y /tmp/onescript-engine.deb \
    && rm -f /tmp/onescript-engine.deb \
    && opm update opm \
    && opm install vanessa-runner@2.6.1 \
    && opm install add \
    && rm -rf /var/lib/apt/lists/*

# 3. Установка платформы 1С 8.5.1.1529 (Толстый + Тонкий клиент + Серверные библиотеки)
COPY dist/setup-full-${ONEC_VERSION}-x86_64.run /tmp/setup.run
RUN chmod +x /tmp/setup.run \
    && /tmp/setup.run --mode unattended --enable-components server,client_full,client_thin,ru \
    && rm -f /tmp/setup.run

# 4. Глобальное отключение поиска аппаратных ключей HASP (UseHwLicenses=0 в UTF-16LE для 1cestart.cfg)
RUN mkdir -p /root/.1C/1cestart /opt/1cv8/conf /var/1C/licenses \
    && printf "UseHwLicenses=0\r\nAppAutoInstallLastVersion=0\r\n" | iconv -f UTF-8 -t UTF-16LE > /root/.1C/1cestart/1cestart.cfg \
    && printf "UseHwLicenses=0\n" >> /opt/1cv8/conf/conf.cfg

# Путь к исполняемым файлам 1С 8.5
ENV PATH="/opt/1cv8/x86_64/${ONEC_VERSION}:${PATH}"

# 5. Копируем обработку vanessa-automation.epf
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

# 6. Скрипт запуска виртуального монитора + VNC (поддержка динамических дисплеев)
RUN printf '#!/bin/bash\n\
DISPLAY_NUM=${DISPLAY:-:99}\n\
LOCK_FILE="/tmp/.X${DISPLAY_NUM#:}-lock"\n\
rm -f $LOCK_FILE\n\
mkdir -p /root/.1C/1cestart\n\
printf "UseHwLicenses=0\\r\\nAppAutoInstallLastVersion=0\\r\\n" | iconv -f UTF-8 -t UTF-16LE > /root/.1C/1cestart/1cestart.cfg\n\
Xvfb $DISPLAY_NUM -screen 0 1920x1080x24 -ac &\n\
sleep 2\n\
startxfce4 &\n\
x11vnc -display $DISPLAY_NUM -forever -nopw -quiet -rfbport 5900 &\n\
exec "$@"\n' > /entrypoint.sh && chmod +x /entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]
