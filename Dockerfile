FROM debian:9.9 as nginx-brotli-builder
MAINTAINER FOUCHARD Tony <t.fouchard@qwant.com>

ENV BUILD_DIR /root
ENV NGINX_VERSION 1.16.0
ENV OPENSSL_VERSION 1.1.1b
ENV ROOTFS /rootfs
ENV NGX_BROTLI_GIT_HASH 7df1e381d7abefa53a226306057453a202cd60c2

RUN apt-get update && apt-get install -y build-essential ftp git libtool autoconf automake curl

WORKDIR ${BUILD_DIR}
RUN git clone https://github.com/cloudflare/ngx_brotli_module
WORKDIR ${BUILD_DIR}/ngx_brotli_module
RUN git checkout ${NGX_BROTLI_GIT_HASH}
RUN git submodule init && git submodule update

WORKDIR ${BUILD_DIR}
RUN curl -L "ftp://ftp.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" -o openssl.tar.gz && \
    tar xvzf openssl.tar.gz
RUN curl -L "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -o nginx.tar.gz && \
    tar xvzf nginx.tar.gz

WORKDIR ${BUILD_DIR}/nginx-${NGINX_VERSION}

RUN apt-get install -y zlib1g-dev libpcre3-dev libperl-dev

RUN ./configure \
      --user=www-data \
      --group=www-data \
      --with-openssl=${BUILD_DIR}/openssl-${OPENSSL_VERSION} \ 
      --add-module=${BUILD_DIR}/ngx_brotli_module \
      --with-cc-opt="-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic" \
      --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --conf-path=/etc/nginx/nginx.conf \
      --pid-path=/run/nginx.pid \
      --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log

RUN mkdir -p ${ROOTFS} ${ROOTFS}/etc/nginx/sites-enabled ${ROOTFS}/etc/nginx/sites-available

WORKDIR ${BUILD_DIR}/nginx-${NGINX_VERSION}
RUN make -j $(nproc) && make DESTDIR=${ROOTFS} install

FROM debian:9.9-slim
RUN apt-get update && apt-get install -y procps
COPY --from=nginx-brotli-builder /rootfs /
EXPOSE 80 443
STOPSIGNAL SIGTERM
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
