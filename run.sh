#!/bin/bash

# We use the autobuild to always test our new functionality. But YOU should not do that!
# Instead use the latest tagged version as the next row
# DOCKER_CONTAINER=sitespeedio/sitespeed.io:10.1.0

DOCKER_CONTAINER=sitespeedio/sitespeed.io:10.3.2
DOCKER_SETUP="--cap-add=NET_ADMIN  --shm-size=2g --rm -v /config:/config -v "$(pwd)":/sitespeed.io -v /etc/localtime:/etc/localtime:ro -e MAX_OLD_SPACE_SIZE=3072 --network=cable "
CONFIG="--config /sitespeed.io/config"
BROWSERS=(chrome firefox)


# Setup the network throttling in Docker
docker network create --driver bridge --subnet=172.18.0.0/24 --gateway=172.18.0.1 --opt "com.docker.network.bridge.name"="docker1" cable
sudo tc qdisc add dev docker1 root handle 1: htb default 12
sudo tc class add dev docker1 parent 1:1 classid 1:12 htb rate 5mbit ceil 5mbit
sudo tc qdisc add dev docker1 parent 1:12 netem delay 14ms

# We loop through all directories we have
# We run many tests to verify the functionality of sitespeed.io and you can simplify this by
# removing things you don't need!

for url in tests/$TEST/desktop/urls/*.txt ; do
    [ -e "$url" ] || continue
    for browser in "${BROWSERS[@]}" ; do
        POTENTIAL_CONFIG="./config/$(basename ${url%%.*}).json"
        [[ -f "$POTENTIAL_CONFIG" ]] && CONFIG_FILE="$(basename ${url%.*}).json" || CONFIG_FILE="desktopWithExtras.json"
        NAMESPACE="--graphite.namespace sitespeed_io.$(basename ${url%%.*})"
        sudo docker run $DOCKER_SETUP $DOCKER_CONTAINER $NAMESPACE $CONFIG/$CONFIG_FILE -b $browser $url
        control
    done
done

for script in tests/$TEST/desktop/scripts/*.js ; do
    [ -e "$script" ] || continue
    for browser in "${BROWSERS[@]}"  ; do
        POTENTIAL_CONFIG="./config/$(basename ${script%%.*}).json"
        [[ -f "$POTENTIAL_CONFIG" ]] && CONFIG_FILE="$(basename ${script%.*}).json" || CONFIG_FILE="desktop.json"
        NAMESPACE="--graphite.namespace sitespeed_io.$(basename ${script%%.*})"
        sudo docker run $DOCKER_SETUP $DOCKER_CONTAINER $NAMESPACE $CONFIG/$CONFIG_FILE --multi -b $browser --spa $script
        control
    done
done

#for url in tests/$TEST/emulatedMobile/urls/*.txt ; do
#    [ -e "$url" ] || continue
#    POTENTIAL_CONFIG="./config/$(basename ${url%%.*}).json"
#    [[ -f "$POTENTIAL_CONFIG" ]] && CONFIG_FILE="$(basename ${url%.*}).json" || CONFIG_FILE="emulatedMobile.json"
#    NAMESPACE="--graphite.namespace sitespeed_io.$(basename ${url%%.*})"
#    docker run $DOCKER_SETUP $DOCKER_CONTAINER $NAMESPACE $CONFIG/$CONFIG_FILE $url
#    control
#done

#for script in tests/$TEST/emulatedMobile/scripts/*.js ; do
#    [ -e "$script" ] || continue
#    POTENTIAL_CONFIG="./config/$(basename ${script%%.*}).json"
#    [[ -f "$POTENTIAL_CONFIG" ]] && CONFIG_FILE="$(basename ${script%.*}).json" || CONFIG_FILE="emulatedMobile.json"
#    NAMESPACE="--graphite.namespace sitespeed_io.$(basename ${script%%.*})"
#    docker run $DOCKER_SETUP $DOCKER_CONTAINER $NAMESPACE $CONFIG/$CONFIG_FILE --multi --spa $script
#    control
#done

# We run WebPageReplay just to verify that it works
#for url in tests/$TEST/replay/urls/*.txt ; do
#    [ -e "$url" ] || continue
#    POTENTIAL_CONFIG="./config/$(basename ${url%%.*}).json"
#    [[ -f "$POTENTIAL_CONFIG" ]] && CONFIG_FILE="$(basename ${url%.*}).json" || CONFIG_FILE="replay.json"
#    NAMESPACE="--graphite.namespace sitespeed_io.$(basename ${url%%.*})"
#    docker run $DOCKER_SETUP -e REPLAY=true -e LATENCY=100 $DOCKER_CONTAINER $NAMESPACE $CONFIG/$CONFIG_FILE $url
#    control
#done

# We run WebPageTest runs to verify the WebPageTest functionality and dashboards
#for url in tests/$TEST/webpagetest/desktop/urls/*.txt ; do
#    [ -e "$url" ] || continue
#    NAMESPACE="--graphite.namespace sitespeed_io.$(basename ${url%%.*})"
#    docker run $DOCKER_SETUP $DOCKER_CONTAINER $NAMESPACE $CONFIG/webpagetest.json $url
#    control
#done

# You can also test using WebPageTest scripts
#for script in tests/$TEST/webpagetest/desktop/scripts/* ; do
#    [ -e "$script" ] || continue
#    NAMESPACE="--graphite.namespace sitespeed_io.$(basename ${script%%.*})"
#    docker run $DOCKER_SETUP $DOCKER_CONTAINER $NAMESPACE $CONFIG/webpagetest.json --plugins.remove browsertime --webpagetest.file $script https://www.example.org/
#    control
#done

#Remove the docker network stuff
net_id=`docker network ls --filter 'name=cable' | grep -v NETWORK | cut -d\   -f1`
docker network rm ${net_id}

# Remove the current container so we fetch the latest autobuild the next time
# If you run a stable version (as YOU should), you don't need to remove the container,
# instead make sure you remove all volumes (of data)
# docker volume prune -f
#docker system prune --all --volumes -f
docker system prune --volumes -f
#clean up old local result files older than 14 days
find "$(pwd)"/sitespeed-result -mtime +14 -exec rm {} \;
sleep 60
