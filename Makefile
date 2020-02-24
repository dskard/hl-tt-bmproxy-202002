BROWSER?=firefox
DCYML_GRID=${CURDIR}/docker/grid/docker-compose.yml
GRID_HOST=selenium-hub
GRID_PORT=4444
GRID_SCHEME=http
GRID_TIMEOUT=30000
HOURMINSEC=`date +'%H%M%S'`
NETWORK=${PROJECT}_default
PROJECT=hlttnet
SCALE=1
SCALE_CHROME=${SCALE}
SCALE_FIREFOX=${SCALE}
SELENIUM_VERSION=3.141.59-uranium
TRE_IMAGE?=hltt/tew:latest
WORKDIR=/opt/work
BMP_IMAGE?=raul72/browsermob-proxy:2.1.4
BMP_HOST?=bmp
BMP_PORT?=18080
BMP_PORT_RANGE?=18081-18581


# Allocate a tty and keep stdin open when running locally
# Jenkins nodes don't have input tty, so we set this to ""
DOCKER_TTY_FLAGS?=-it

DOCKER_RUN_COMMAND=docker run --rm --init \
	    ${DOCKER_TTY_FLAGS} \
	    --name=tre-${HOURMINSEC} \
	    --network=$(NETWORK) \
	    --volume=${CURDIR}:${WORKDIR} \
	    --user=`id -u`:`id -g` \
	    --env HOME=${WORKDIR} \
	    --env PYTHONPATH="${WORKDIR}" \
	    --workdir=${WORKDIR} \
	    ${TRE_IMAGE}

COMMAND=bash

ifdef DEBUG
	GRID_TIMEOUT=0
endif

# NOTE: This Makefile does not support running with concurrency (-j XX).
.NOTPARALLEL:

all: test

tew:
	docker build -t ${TRE_IMAGE} docker/tew

clean:
	rm -f *.png *.log ${TMP_PIPE} ${RESULT_XML};
	rm -rf .pytest_cache __pycache__;

distclean: clean

run:
	@${DOCKER_RUN_COMMAND} ${COMMAND}

test-env-up: grid-up

test-env-down: network-down

bmp-up: network-up
	@echo -n "Starting ${BMP_HOST} ...";
	@docker run --rm -d \
	    --name=${BMP_HOST} \
	    --network=$(NETWORK) \
	    --volume=${CURDIR}/configs/bmp-logging.yaml:/browsermob-proxy/bin/conf/bmp-logging.yaml \
	    -p :${BMP_PORT}:${BMP_PORT} \
	    -p ${BMP_PORT_RANGE}:${BMP_PORT_RANGE} \
	    -e BMP_PORT=${BMP_PORT} \
	    -e BMP_ADDRESS=0.0.0.0 \
	    -e BMP_PROXY_PORT_RANGE=${BMP_PORT_RANGE} \
	    -e BMP_PROXY_TTL=0 \
	    ${BMP_IMAGE};
	@echo " done";


bmp-down:
	$(eval BMP_EXISTS=$(shell docker container inspect ${BMP_HOST} > /dev/null 2>&1 && echo 0 || echo 1))
	@if [ "${BMP_EXISTS}" = "0" ] ; then \
	    echo -n "Stopping ${BMP_HOST} ..."; \
	    docker stop ${BMP_HOST} -t 0 1>/dev/null ; \
	    echo " done"; \
	fi;

grid-up: network-up
	NETWORK=${NETWORK} \
	GRID_TIMEOUT=${GRID_TIMEOUT} \
	SELENIUM_VERSION=${SELENIUM_VERSION} \
	docker-compose -f ${DCYML_GRID} -p ${PROJECT} up -d --scale firefox=${SCALE_FIREFOX} --scale chrome=${SCALE_CHROME}

grid-down:
	NETWORK=${NETWORK} \
	GRID_TIMEOUT=${GRID_TIMEOUT} \
	SELENIUM_VERSION=${SELENIUM_VERSION} \
	docker-compose -f ${DCYML_GRID} -p ${PROJECT} down

grid-restart:
	NETWORK=${NETWORK} \
	GRID_TIMEOUT=${GRID_TIMEOUT} \
	SELENIUM_VERSION=${SELENIUM_VERSION} \
	docker-compose -f ${DCYML_GRID} -p ${PROJECT} restart

network-up:
	$(eval NETWORK_EXISTS=$(shell docker network inspect ${NETWORK} > /dev/null 2>&1 && echo 0 || echo 1))
	@if [ "${NETWORK_EXISTS}" = "1" ] ; then \
	    echo "Creating network: ${NETWORK}"; \
	    docker network create --driver bridge ${NETWORK} ; \
	fi;

network-down: grid-down
	$(eval NETWORK_EXISTS=$(shell docker network inspect ${NETWORK} > /dev/null 2>&1 && echo 0 || echo 1))
	@if [ "${NETWORK_EXISTS}" = "0" ] ; then \
	    for i in `docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' ${NETWORK}`; do \
	        echo "Removing container \"$${i}\" from network \"${NETWORK}\""; \
	        docker network disconnect -f ${NETWORK} $${i}; \
	    done; \
	    echo "Removing network: ${NETWORK}"; \
	    docker network rm ${NETWORK}; \
	fi;

.PHONY: all
.PHONY: bmp-down
.PHONY: bmp-up
.PHONY: clean
.PHONY: distclean
.PHONY: grid-down
.PHONY: grid-up
.PHONY: network-down
.PHONY: network-up
.PHONY: test-env-down
.PHONY: test-env-up
