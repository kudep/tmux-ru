# Clean Ubuntu. We deliberately do NOT install tmux/git/xsel here — install.sh
# must bring them itself, so the test proves the one-command install on a clean
# box. Only test-harness prerequisites are added (python3 for the pty driver,
# a UTF-8 locale so the client decodes Cyrillic).
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TERM=xterm-256color
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 locales ca-certificates && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /repo
COPY . /repo
CMD ["bash", "test/test.sh"]
