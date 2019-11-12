#!/bin/bash
set -e

export HOME=`pwd`

# make sure you have installed build tools in this system before you run this script.
# dependence: gcc/clang g++/clang++ gzip bzip2 make glibc-static curl
# Working directory, this directory must be clean or not exists, or your data in this directory may lost.

WORKING_DIR=$HOME/build-deps
DEPS_DIR=$WORKING_DIR/.build
PREFIX=/nginx
CFLAGS="-static"
LDFLAGS="-static"

NGINX_VER=${NGINX_VER:-1.18.0}
PCRE_VER=${PCRE_VER:-8.44}
OPENSSL_VER=${OPENSSL_VER:-1.1.1g}
ZLIB_VER=${ZLIB_VER:-1.2.11}

NGINX_URL=https://nginx.org/download/nginx-$NGINX_VER.tar.gz
PCRE_URL=https://ftp.pcre.org/pub/pcre/pcre-$PCRE_VER.tar.gz
OPENSSL_URL=https://www.openssl.org/source/openssl-$OPENSSL_VER.tar.gz
ZLIB_URL=https://zlib.net/zlib-$ZLIB_VER.tar.xz

mkdir -p $WORKING_DIR
cd $WORKING_DIR
sudo mkdir $PREFIX
sudo chmod o+w $PREFIX

curl -L $NGINX_URL | tar xz
curl -L $PCRE_URL | tar xz
curl -L $OPENSSL_URL | tar xz
curl -L $ZLIB_URL | tar xJ

PCRE_DIR=$WORKING_DIR/`ls | grep ^pcre-`
OPENSSL_DIR=$WORKING_DIR/`ls | grep ^openssl-`
ZLIB_DIR=$WORKING_DIR/`ls | grep ^zlib-`

export CC=${CC:-clang}
export CXX=${CXX:-clang++}

cd $WORKING_DIR/nginx-*
./configure --prefix=$PREFIX\
 --sbin-path=$PREFIX/nginx\
 --conf-path=$PREFIX/nginx.conf\
 --modules-path=$PREFIX/modules\
 --error-log-path=/dev/null\
 --pid-path=/var/run/nginx.pid\
 --lock-path=/var/run/nginx.lock\
 --http-log-path=/dev/null\
 --with-cc-opt="$CFLAGS"\
 --with-ld-opt="$LDFLAGS"\
 --with-select_module\
 --with-poll_module\
 --with-threads\
 --with-file-aio\
 --with-http_ssl_module\
 --with-http_v2_module\
 --with-http_realip_module\
 --with-http_addition_module\
 --with-http_sub_module\
 --with-http_dav_module\
 --with-http_flv_module\
 --with-http_mp4_module\
 --with-http_gunzip_module\
 --with-http_gzip_static_module\
 --with-http_auth_request_module\
 --with-http_random_index_module\
 --with-http_secure_link_module\
 --with-http_degradation_module\
 --with-http_slice_module\
 --with-http_stub_status_module\
 --with-mail\
 --with-mail_ssl_module\
 --with-stream\
 --with-stream_ssl_module\
 --with-stream_realip_module\
 --with-stream_ssl_preread_module\
 --with-pcre=$PCRE_DIR\
 --with-zlib=$ZLIB_DIR\
 --with-openssl=$OPENSSL_DIR
make -j`nproc` && make install

pack_and_upload() {
  echo 'Uploading artifacts...'
  cd $HOME
  local build_time=`date +"%Y%m%d%H%M%S"`
  tar --owner=0 --group=0 -cJf $HOME/nginx-static.tar.xz nginx-static-$NGINX_VER
  curl -T "$HOME/nginx-static.tar.xz" "https://transfer.sh/nginx-static-$build_time.$NGINX_VER.tar.xz"
  echo
  [ -n "$TELEGRAM_BOTOKEN" ] && curl -s \
    -F "chat_id=${TELEGRAM_BOTOKEN#*/}" \
    -F "document=@$HOME/nginx-static.tar.xz" \
    -F "caption=Nginx-static-$NGINX_VER-$build_time" \
    "https://api.telegram.org/bot${TELEGRAM_BOTOKEN%/*}/sendDocument" >/dev/null
  [ -n "$TERACLOUD_TOKEN" ] && curl -s -u "${TERACLOUD_TOKEN%@*}" -T "$HOME/nginx-static.tar.xz" \
    "https://${TERACLOUD_TOKEN#*@}/dav/artifacts/nginx-static-$build_time.$NGINX_VER.tar.xz" >/dev/null
}

if [ -f "$PREFIX/nginx" ]; then
  strip -s -x $PREFIX/nginx || true
  echo "build finished"
  mv $PREFIX/nginx $HOME/nginx-static/nginx
  mv $HOME/nginx-static $HOME/nginx-static-$NGINX_VER
  [ -n "$SHARE_ARTIFACTS" ] && pack_and_upload || true
  exit 0
fi
echo "no nginx binary file found!"
exit 1
