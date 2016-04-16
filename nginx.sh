#!/usr/bin/env bash

# Variables
export VERSION_NGINX=nginx-1.9.14
export VERSION_PCRE=pcre-8.38
export VERSION_LIBRESSL=libressl-2.3.3
export VERSION_NGX_BROTLI=master

export SOURCE_LIBRESSL=http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/
export SOURCE_PCRE=http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/
export SOURCE_NGINX=http://nginx.org/download/
export SOURCE_NGX_BROTLI=https://github.com/cloudflare/ngx_brotli_module/archive/

# Clean build directory
rm -rf build
mkdir build

# Faster build
PROC=$(grep -c ^processor /proc/cpuinfo)

# Download the source files
echo "Downloading sources"
wget -P ./build $SOURCE_PCRE$VERSION_PCRE.tar.gz
wget -P ./build $SOURCE_LIBRESSL$VERSION_LIBRESSL.tar.gz
wget -P ./build $SOURCE_NGINX$VERSION_NGINX.tar.gz
wget -P ./build $SOURCE_NGX_BROTLI$VERSION_NGX_BROTLI.tar.gz

# Extract the source files
echo "Extracting Packages"
cd build
tar xzf $VERSION_NGINX.tar.gz
tar xzf $VERSION_LIBRESSL.tar.gz
tar xzf $VERSION_PCRE.tar.gz
tar zxf $VERSION_NGX_BROTLI.tar.gz

cd ../

export BPATH=$(pwd)/build
export STATICLIBSSL=$BPATH/$VERSION_LIBRESSL

# Build static LibreSSL
echo "Configure & Build LibreSSL"
cd $STATICLIBSSL
./configure LDFLAGS=-lrt --prefix=${STATICLIBSSL}/.openssl/ && make install-stri                                                                                                                p -j $PROC

# Build nginx
echo "Configure & Build Nginx"
cd $BPATH/$VERSION_NGINX

mkdir -p $BPATH/nginx
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
  --with-pcre=$BPATH/$VERSION_PCRE \
  --with-pcre-jit \
  --with-openssl=$STATICLIBSSL \
  --with-ld-opt="-lrt" \
  --add-module=$BPATH/ngx_brotli_module-master

touch $STATICLIBSSL/.openssl/include/openssl/ssl.h
make -j $PROC
echo "Done.";
echo "You can now 'make install' or just copy the nginx binary to /usr/sbin folder!";
echo "Don't forget to copy 'nginx.service' to /lib/systemd/system/ and logrotate to it's place";
