#!/bin/bash


[ ! -f ../.VERSION.mk ] && make -C .. .VERSION.mk

. ../.VERSION.mk

if ! git show-ref --tags | grep -q "$(git rev-parse HEAD)"; then
	# HEAD is not tagged, add the date, time and commit hash to the revision
	BUILD_TIME="$(date +%Y%m%d%H%M)"
	DEB_REVISION="${BUILD_TIME}~${REVISION}"
	RPM_REVISION=".${BUILD_TIME}.${REVISION}"
fi


URL="http://logstash.net"
DESCRIPTION="An extensible logging pipeline"

if [ "$#" -ne 2 ] ; then
  echo "Usage: $0 <os> <release>"
  echo 
  echo "Example: $0 ubuntu 12.10"
  exit 1
fi

os=$1
release=$2

echo "Building package for $os $release"

destdir=build/$(echo "$os" | tr ' ' '_')
prefix=/opt/logstash

if [ "$destdir/$prefix" != "/" -a -d "$destdir/$prefix" ] ; then
  rm -rf "$destdir/$prefix"
fi

mkdir -p $destdir/$prefix


# install logstash.jar
jar="$(dirname $0)/../build/logstash-$VERSION-flatjar.jar"
if [ ! -f "$jar" ] ; then
  echo "Unable to find $jar"
  exit 1
fi

cp $jar $destdir/$prefix/logstash.jar

case $os@$release in
  ubuntu@*)
    mkdir -p $destdir/etc/logstash/conf.d
    mkdir -p $destdir/etc/logrotate.d
    mkdir -p $destdir/etc/supervisor/conf.d
    mkdir -p $destdir/var/lib/logstash
    mkdir -p $destdir/var/log/logstash
    install -m644 logrotate.conf $destdir/etc/logrotate.d/logstash
    install -m644 logstash.conf $destdir/etc/supervisor/conf.d
    install -m644 default.conf $destdir/etc/logstash/conf.d
    install -m755 logstash.sh $destdir/opt/logstash
    ;;
  *) 
    echo "Unknown OS: $os $release"
    exit 1
    ;;
esac

description="logstash is a system for managing and processing events and logs"
case $os in
  ubuntu|debian)
    if ! echo $RELEASE | grep -q '\.(dev\|rc.*)'; then
      # This is a dev or RC version... So change the upstream version
      # example: 1.2.2.dev => 1.2.2~dev
      # This ensures a clean upgrade path.
      RELEASE="$(echo $RELEASE | sed 's/\.\(dev\|rc.*\)/~\1/')"
    fi

    fpm -s dir -t deb -n logstash -v "$RELEASE" \
      -a all --iteration "1+${os}${DEB_REVISION}" \
      --url "$URL" \
      --description "$DESCRIPTION" \
      -d "default-jre-headless" \
      --deb-user root --deb-group root \
      --before-install $os/before-install.sh \
      --before-remove $os/before-remove.sh \
      --after-install $os/after-install.sh \
      --config-files /etc/logrotate.d/logstash \
      --config-files /etc/supervisor/conf.d \
      -f -C $destdir .
    ;;
esac
