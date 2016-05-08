#!/usr/bin/env bash

# Variables
export VERSION_NGINX=nginx-1.10.0
export VERSION_PCRE=pcre-8.38
export VERSION_LIBRESSL=libressl-2.3.4

export SOURCE_LIBRESSL=http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/
export SOURCE_PCRE=http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/
export SOURCE_NGINX=http://nginx.org/download/

# Clean build directory
rm -rf build
mkdir build

# Faster build
PROC=$(grep -c ^processor /proc/cpuinfo)

cd build

# Download the source files
echo "Downloading sources"

wget -P ./ $SOURCE_NGINX$VERSION_NGINX.tar.gz
tar xzf $VERSION_NGINX.tar.gz
rm $VERSION_NGINX.tar.gz

wget -P ./ $SOURCE_LIBRESSL$VERSION_LIBRESSL.tar.gz
tar xzf $VERSION_LIBRESSL.tar.gz
rm $VERSION_LIBRESSL.tar.gz

wget -P ./ $SOURCE_PCRE$VERSION_PCRE.tar.gz
tar xzf $VERSION_PCRE.tar.gz
rm $VERSION_PCRE.tar.gz

wget -P ./ http://www.linuxfromscratch.org/patches/blfs/svn/pcre-8.38-upstream_fixes-1.patch

# Patch PCRE
cd $VERSION_PCRE
patch -Np1 -i ../pcre-8.38-upstream_fixes-1.patch

cd ../
export BPATH=$(pwd)
export STATICLIBSSL=$BPATH/$VERSION_LIBRESSL

# Build static LibreSSL
echo "Configure & Build LibreSSL"
cd $STATICLIBSSL
./configure LDFLAGS=-lrt --prefix=${STATICLIBSSL}/.openssl/ && make install-strip -j $PROC

# Build nginx
echo "Configure & Build Nginx"
cd $BPATH/$VERSION_NGINX

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
  --with-pcre=$BPATH/$VERSION_PCRE \
  --with-pcre-jit \
  --with-openssl=$STATICLIBSSL \
  --with-ld-opt="-lrt" \

touch $STATICLIBSSL/.openssl/include/openssl/ssl.h
make -j $PROC

echo "----------------------------------------------------------------------------------------";
echo "Done.";
echo "You can now 'make install' or just copy the nginx binary to /usr/sbin folder!";
echo "Don't forget to copy 'nginx.service' to /lib/systemd/system/ and logrotate to it's place";
