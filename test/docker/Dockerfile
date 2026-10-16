# Linux image matching CI (ubuntu-latest) so golden files are consistent.
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    xvfb \
    libgtk-3-dev \
    cmake \
    ninja-build \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash developer
USER developer
WORKDIR /home/developer

ARG flutter_version
RUN git clone --depth 1 https://github.com/flutter/flutter.git -b ${flutter_version}
ENV PATH="$PATH:/home/developer/flutter/bin"

RUN flutter config --no-analytics && flutter precache --no-android --no-ios --linux

ENV DISPLAY=:99
RUN printf '#!/bin/sh\nXvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &\nexec "$@"\n' > /home/developer/entrypoint.sh \
    && chmod +x /home/developer/entrypoint.sh

ENTRYPOINT ["/home/developer/entrypoint.sh"]
