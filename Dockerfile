FROM alpine:3.12

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL maintainer="Szabolcs Toth <szabix@szabix.hu>" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="mosquitto MQTT Broker with auth-plugin" \
      org.label-schema.description="This project builds mosquitto with auth-plugin. \
      It also has mosquitto_pub, mosquitto_sub and np." \
      org.label-schema.url="https://hub.docker.com/r/szabix/sbx-mosquitto" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/szabix/sbx-mosquitto" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

RUN addgroup -S mosquitto && \
    adduser -S -H -h /var/empty -s /sbin/nologin -D -G mosquitto mosquitto

ENV PATH=/usr/local/bin:/usr/local/sbin:$PATH
ENV MOSQUITTO_VERSION=1.6.12

COPY run.sh /

RUN apk --no-cache add --virtual buildDeps git cmake build-base openssl-dev c-ares-dev util-linux-dev curl-dev libwebsockets-dev; \
    apk --no-cache add libwebsockets; \
    chmod +x /run.sh && \
    mkdir -p /var/lib/mosquitto && \
    touch /var/lib/mosquitto/.keep && \
    mkdir -p /etc/mosquitto.d && \
    apk add libuuid c-ares openssl curl ca-certificates && \
    cd .. && \
    wget http://mosquitto.org/files/source/mosquitto-${MOSQUITTO_VERSION}.tar.gz && \
    tar xzfv mosquitto-${MOSQUITTO_VERSION}.tar.gz && \
    mv mosquitto-${MOSQUITTO_VERSION} mosquitto && \
    rm mosquitto-${MOSQUITTO_VERSION}.tar.gz && \
    cd mosquitto && \
    make -j "$(nproc)" \
      CFLAGS="-Wall -O2 -I/usr/include/libwebsockets" \
      LDFLAGS="-L/usr/lib" \
      WITH_SRV=yes \
      WITH_STRIP=yes \
      WITH_ADNS=no \
      WITH_DOCS=no \
      WITH_MEMORY_TRACKING=no \
      WITH_TLS_PSK=no \
      WITH_WEBSOCKETS=yes \
    binary && \
    mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log && \
    install -s -m755 client/mosquitto_pub /usr/bin/mosquitto_pub && \
    install -s -m755 client/mosquitto_rr /usr/bin/mosquitto_rr && \
    install -s -m755 client/mosquitto_sub /usr/bin/mosquitto_sub && \
    install -s -m644 lib/libmosquitto.so.1 /usr/lib/libmosquitto.so.1 && \
    ln -sf /usr/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so && \
    install -s -m755 src/mosquitto /usr/sbin/mosquitto && \
    install -s -m755 src/mosquitto_passwd /usr/bin/mosquitto_passwd && \
    git clone https://github.com/vankxr/mosquitto-auth-plug && \
    cd mosquitto-auth-plug && \
    cp config.mk.in config.mk && \
    sed -i "s/BACKEND_CDB ?= no/BACKEND_CDB ?= no/" config.mk && \
    sed -i "s/BACKEND_MYSQL ?= yes/BACKEND_MYSQL ?= no/" config.mk && \
    sed -i "s/BACKEND_SQLITE ?= no/BACKEND_SQLITE ?= no/" config.mk && \
    sed -i "s/BACKEND_REDIS ?= no/BACKEND_REDIS ?= no/" config.mk && \
    sed -i "s/BACKEND_POSTGRES ?= no/BACKEND_POSTGRES ?= no/" config.mk && \
    sed -i "s/BACKEND_LDAP ?= no/BACKEND_LDAP ?= no/" config.mk && \
    sed -i "s/BACKEND_HTTP ?= no/BACKEND_HTTP ?= yes/" config.mk && \
    sed -i "s/BACKEND_JWT ?= no/BACKEND_JWT ?= no/" config.mk && \
    sed -i "s/BACKEND_MONGO ?= no/BACKEND_MONGO ?= no/" config.mk && \
    sed -i "s/BACKEND_FILES ?= no/BACKEND_FILES ?= no/" config.mk && \
    sed -i "s/BACKEND_MEMCACHED ?= no/BACKEND_MEMCACHED ?= no/" config.mk && \
    sed -i "s/MOSQUITTO_SRC =/MOSQUITTO_SRC = ..\//" config.mk && \
    make -j "$(nproc)" && \
    install -s -m755 auth-plug.so /usr/lib/ && \
    install -s -m755 np /usr/bin/ && \
    cd / && rm -rf mosquitto && \
    rm -rf libwebsockets && \
    apk del buildDeps && rm -rf /var/cache/apk/*

ADD mosquitto.conf /mosquitto/config/mosquitto.conf

# MQTT default port and default port over TLS
EXPOSE 1883 8883
# MQTT over websocket default port and default port over TLS
EXPOSE 9001 9002

VOLUME ["/mosquitto/data", "/mosquitto/log"]

ENTRYPOINT ["/run.sh"]
CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]
