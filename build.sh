#/bin/bash
if  [[ "$(which jq)" = "" ]]; then
    whiptail --title "Missing Required File" --yesno "jq is required for this script to function.\nShould I install it for you?" 8 48 "$TZ"  3>&1 1>&2 2>&3
    exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
    apt-get update
    apt-get install -y jq
fi
BASEDIR="${BASEDIR:-/srv/docker/buildpack-deps/}"
REPO=buildpack-deps
echo "BASEDIR:$BASEDIR"
# Always remove and refresh
[[ -d  "$BASEDIR/$REPO" ]] &&  \
  rm -rf "$BASEDIR/$REPO"

cd "$BASEDIR"
git clone https://github.com/docker-library/buildpack-deps.git
### patch ###
cd $REPO/jessie/
sed -i 's_FROM debian:jessie_FROM whw3/rpi_' ./curl/Dockerfile
sed -i 's/^RUN apt-get update \&\& apt-get install/RUN apt-get update \&\& apt-get upgrade \&\& apt-get install/' ./curl/Dockerfile
find . -name Dockerfile -exec sed -i 's_FROM buildpack-deps:jessie_FROM whw3/buildpack-deps:rpi_' {} +
### build ###
cd ./curl
docker build -t whw3/buildpack-deps:rpi-curl -t whw3/buildpack-deps:curl .
cd ../scm
docker build -t whw3/buildpack-deps:rpi-scm -t whw3/buildpack-deps:scm .
cd ..
docker build -t whw3/buildpack-deps:rpi .

### Its quicker to ADD s6-overlay to the cached images we just built than to re-baseline from whw3/rpi-s6
cd "$BASEDIR"

wget -qO s6-tags.json https://api.github.com/repos/just-containers/s6-overlay/tags
eval "$(jq -r '.[0] | @sh "S6_VERSION=\(.name)"' s6-tags.json )"
rm s6-tags.json

[[ ! -f s6-overlay-$S6_VERSION-armhf.tar.gz ]] && \
    wget -O s6-overlay-"$S6_VERSION"-armhf.tar.gz https://github.com/just-containers/s6-overlay/releases/download/"$S6_VERSION"/s6-overlay-armhf.tar.gz

declare -a tags=("-curl" "-scm" "")
for tag in "${tags[@]}"
do
    cat << EOF > Dockerfile
FROM whw3/buildpack-deps:rpi$tag
ADD s6-overlay-$S6_VERSION-armhf.tar.gz /
COPY 01-docker-entrypoint.sh /etc/cont-init.d
RUN chmod +x /etc/cont-init.d/01-docker-entrypoint.sh
ENTRYPOINT ["/init"]
EOF
    _tag=${tag//-/}
    _tag="$_tag-s6"
    [[ -z $tag ]] && _tag="latest"
    docker build -t whw3/buildpack-deps:rpi-s6$tag -t whw3/buildpack-deps:$_tag .
done
rm Dockerfile
