#!/usr/bin/env bash

# Install dependencies
# sudo yum install gcc-c++ jemalloc-devel git libatomic_ops-devel unzip wget

# Variables
export VERSION_NGINX=1.11.9
export VERSION_PCRE=8.40
export VERSION_ZLIB=1.2.11
export VERSION_LIBRESSL=2.4.4
export VERSION_PAGESPEED=1.12.34.2

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
git clone --recursive https://github.com/cloudflare/ngx_brotli_module.git brotli
wget -qO- https://github.com/pagespeed/ngx_pagespeed/archive/v${VERSION_PAGESPEED}-beta.tar.gz | tar xz --strip-components=1 -C pagespeed

cd pagespeed
psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL)
wget -qO- ${psol_url} | tar xz --strip-components=1 -C psol
cd ../

export BPATH=$(pwd)
export STATICLIBSSL=${BPATH}/libressl

# Build static LibreSSL
echo "Configure & Build LibreSSL..."
cd $STATICLIBSSL
./configure LDFLAGS=-lrt --prefix=${STATICLIBSSL}/.openssl/ && make install-strip -j ${PROC}

# Build nginx
echo "Configure & Build Nginx..."
cd $BPATH/nginx

# wget https://raw.githubusercontent.com/cloudflare/sslconfig/master/patches/nginx__1.11.5_dynamic_tls_records.patch
# patch -p1 < nginx__1.11.5_dynamic_tls_records.patch

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
  --with-http_v2_module \
  --with-libatomic \
  --with-pcre=../pcre \
  --with-pcre-jit \
  --with-ld-opt="-lrt -ljemalloc -Wl,-z,relro" \
  --with-cc-opt="-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2" \
  --with-zlib=../zlib \
  --with-openssl=../libressl \
  --add-module=../brotli \
  --add-module=../pagespeed

touch ${STATICLIBSSL}/.openssl/include/openssl/ssl.h
make -j ${PROC}
