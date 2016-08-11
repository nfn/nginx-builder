#!/usr/bin/env bash

# Variables
export VERSION_NGINX=1.10.1
export VERSION_PCRE=8.39
export VERSION_ZLIB=1.2.8
export VERSION_LIBRESSL=2.4.2
export VERSION_PAGESPEED=1.11.33.2

# Clean build directory
rm -rf build
mkdir build

# Faster build
PROC=$(grep -c ^processor /proc/cpuinfo)

cd build

# Download the source files
echo "Downloading sources..."

wget -qO- http://nginx.org/download/nginx-${VERSION_NGINX}.tar.gz | tar xz
wget -qO- http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-${VERSION_PCRE}.tar.gz | tar xz
wget -qO- http://zlib.net/zlib-${VERSION_ZLIB}.tar.gz | tar xz
wget -qO- http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${VERSION_LIBRESSL}.tar.gz | tar xz
wget -q https://github.com/pagespeed/ngx_pagespeed/archive/release-${VERSION_PAGESPEED}-beta.zip -O release-${VERSION_PAGESPEED}-beta.zip; unzip -q release-${VERSION_PAGESPEED}-beta.zip; rm release-${VERSION_PAGESPEED}-beta.zip
wget -qO- https://dl.google.com/dl/page-speed/psol/${VERSION_PAGESPEED}.tar.gz | tar xz -C ngx_pagespeed-release-${VERSION_PAGESPEED}-beta

export BPATH=$(pwd)
export STATICLIBSSL=${BPATH}/libressl-${VERSION_LIBRESSL}

# Build static LibreSSL
echo "Configure & Build LibreSSL..."
cd $STATICLIBSSL
./configure LDFLAGS=-lrt --prefix=${STATICLIBSSL}/.openssl/ && make install-strip -j ${PROC}

# Build nginx
echo "Configure & Build Nginx..."
cd $BPATH/nginx-${VERSION_NGINX}

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
  --with-pcre=${BPATH}/pcre-${VERSION_PCRE} \
  --with-pcre-jit \
  --with-zlib=${BPATH}/zlib-${VERSION_ZLIB} \
  --with-openssl=${STATICLIBSSL} \
  --with-ld-opt="-lrt" \
  --add-module=${BPATH}/ngx_pagespeed-release-${VERSION_PAGESPEED}-beta

touch ${STATICLIBSSL}/.openssl/include/openssl/ssl.h
make -j ${PROC}

echo "----------------------------------------------------------------------------------------";
echo "Done.";
echo "You can now 'make install' or just copy the nginx binary to /usr/sbin folder!";
echo "Don't forget to copy 'nginx.service' to /lib/systemd/system/ and logrotate to it's place";
