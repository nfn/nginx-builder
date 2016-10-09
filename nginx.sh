#!/usr/bin/env bash

# Variables
export VERSION_NGINX=1.11.4
export VERSION_PCRE=8.39
export VERSION_ZLIB=1.2.8
export VERSION_LIBRESSL=2.5.0
export VERSION_PAGESPEED=latest-stable
export VERSION_PSOL=1.11.33.4

# Clean build directory
rm -rf build
mkdir build

# Faster build
PROC=$(grep -c ^processor /proc/cpuinfo)

cd build

# Download the source files
echo "Downloading sources..."

mkdir nginx pcre zlib libressl pagespeed pagespeed/psol
wget -qO- http://nginx.org/download/nginx-${VERSION_NGINX}.tar.gz | tar xz --strip-components=1 -C nginx
wget -qO- http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-${VERSION_PCRE}.tar.gz | tar xz --strip-components=1 -C pcre
wget -qO- http://zlib.net/zlib-${VERSION_ZLIB}.tar.gz | tar xz --strip-components=1 -C zlib
wget -qO- http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${VERSION_LIBRESSL}.tar.gz | tar xz --strip-components=1 -C libressl
wget -qO- https://github.com/pagespeed/ngx_pagespeed/archive/${VERSION_PAGESPEED}.tar.gz | tar xz --strip-components=1 -C pagespeed
wget -qO- https://dl.google.com/dl/page-speed/psol/${VERSION_PSOL}.tar.gz | tar xz --strip-components=1 -C pagespeed/psol
git clone --recursive https://github.com/cloudflare/ngx_brotli_module.git

export BPATH=$(pwd)
export STATICLIBSSL=${BPATH}/libressl

# Build static LibreSSL
echo "Configure & Build LibreSSL..."
cd $STATICLIBSSL
./configure LDFLAGS=-lrt --prefix=${STATICLIBSSL}/.openssl/ && make install-strip -j ${PROC}

# Build nginx
echo "Configure & Build Nginx..."
cd $BPATH/nginx

./configure \
  --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid \
  --lock-path=/var/run/nginx.lock \
  --http-client-body-temp-path=/dev/shm/nginx_client_temp \
  --http-proxy-temp-path=/dev/shm/nginx_proxy_temp \
  --http-fastcgi-temp-path=/dev/shm/nginx_fastcgi_temp \
  --http-uwsgi-temp-path=/dev/shm/nginx_uwsgi_temp \
  --http-scgi-temp-path=/dev/shm/nginx_scgi_temp \
  --user=nginx \
  --group=nginx \
  --with-http_ssl_module \
  --with-http_realip_module \
  --with-http_gunzip_module \
  --with-http_stub_status_module \
  --with-http_auth_request_module \
  --with-threads \
  --with-file-aio \
  --with-ipv6 \
  --with-http_v2_module \
  --with-libatomic \
  --with-pcre=${BPATH}/pcre \
  --with-pcre-jit \
  --with-zlib=${BPATH}/zlib \
  --with-openssl=${STATICLIBSSL} \
  --with-ld-opt="-lrt" \
  --add-module=${BPATH}/ngx_brotli_module \
  --add-module=${BPATH}/pagespeed

touch ${STATICLIBSSL}/.openssl/include/openssl/ssl.h
make -j ${PROC}

echo "----------------------------------------------------------------------------------------";
echo "Done.";
echo "You can now 'make install' or just copy the nginx binary to /usr/sbin folder!";
echo "Don't forget to copy 'nginx.service' to /lib/systemd/system/ and logrotate to it's place";
