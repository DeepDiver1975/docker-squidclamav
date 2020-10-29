FROM debian:10

ARG SQUIDCLAMAV_GIT_URL=https://github.com/darold/squidclamav.git
ARG SQUIDCLAMAV_VERSION=v7.1

RUN echo "deb http://http.debian.net/debian/ buster main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://http.debian.net/debian/ buster-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://security.debian.org/ buster/updates main contrib non-free" >> /etc/apt/sources.list && \
    apt-get update \
	&& apt-get install -y --no-install-recommends \
		git \
		c-icap \
		ca-certificates \
		patch \
		libicapapi5 \
		libicapapi-dev \
		libc-dev \
		libssl-dev \
		gcc \
		make \
		file \
        clamav-daemon \
        clamav-freshclam \
        libclamunrar9 \
        ca-certificates \
        netcat-openbsd \
        wget \
	&& apt-mark auto \
		git \
		ca-certificates \
		patch \
		libicapapi-dev \
		libc-dev \
		gcc \
		make \
		file \
\
	&& git clone --recursive "${SQUIDCLAMAV_GIT_URL}" "/usr/src/squidclamav" \
	&& (cd /usr/src/squidclamav \
		&& ./configure \
		&& make -j$(nproc) \
		&& make install \
	) \
	&& rm -rf /usr/src/squidclamav \
\
	&& apt-get autoremove --purge -y \
	&& apt-get clean \
	&& rm -rf /var/tmp/* /tmp/* /var/lib/apt/cache/*

# initial update of av databases
RUN wget -O /var/lib/clamav/main.cvd http://database.clamav.net/main.cvd && \
    wget -O /var/lib/clamav/daily.cvd http://database.clamav.net/daily.cvd && \
    wget -O /var/lib/clamav/bytecode.cvd http://database.clamav.net/bytecode.cvd && \
    chown clamav:clamav /var/lib/clamav/*.cvd

# permission juggling
RUN mkdir /var/run/clamav && \
    chown clamav:clamav /var/run/clamav && \
    chmod 750 /var/run/clamav

# av configuration update
RUN sed -i 's/^Foreground .*$/Foreground true/g' /etc/clamav/clamd.conf && \
    echo "TCPSocket 3310" >> /etc/clamav/clamd.conf && \
    if [ -n "$HTTPProxyServer" ]; then echo "HTTPProxyServer $HTTPProxyServer" >> /etc/clamav/freshclam.conf; fi && \
    if [ -n "$HTTPProxyPort"   ]; then echo "HTTPProxyPort $HTTPProxyPort" >> /etc/clamav/freshclam.conf; fi && \
    if [ -n "$DatabaseMirror"  ]; then echo "DatabaseMirror $DatabaseMirror" >> /etc/clamav/freshclam.conf; fi && \
    if [ -n "$DatabaseMirror"  ]; then echo "ScriptedUpdates off" >> /etc/clamav/freshclam.conf; fi && \
    sed -i 's/^Foreground .*$/Foreground true/g' /etc/clamav/freshclam.conf


RUN (echo "acl all src 0.0.0.0/0.0.0.0" \
		&& echo "Service squidclamav squidclamav.so" \
		&& echo "ServerLog /proc/self/fd/1" \
		&& echo "AccessLog /proc/self/fd/1" \
		&& echo "icap_access allow all") >> /etc/c-icap/c-icap.conf

COPY entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/* \
	&& sed -i 's,\r,,g' /usr/local/bin/*

ENTRYPOINT ["docker-entrypoint"]
