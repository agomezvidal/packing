#!/bin/sh

HOSTS_FILE="/etc/hosts"

# Get current Docker IP
DOCKER_IP="127.0.0.1"
if docker-machine ls | grep default; then
	DOCKER_IP=$(docker-machine ip default)
fi

# Traverse all sites and add/update them in the hosts file
cd "sites"

for d in */ ; do
	CURRENT_IP=$(awk '/^[[:space:]]*($|#)/{next} /'dev.${d%?}'/{print $1; exit}' ${HOSTS_FILE})

	if [[ "${CURRENT_IP}" == "" ]]; then
		printf "[INFO]: Adding the Docker host IP for %s to ${HOSTS_FILE}...\n" "dev.${d%?}"
		echo "${DOCKER_IP} dev.${d%?}" | sudo tee -a ${HOSTS_FILE} > /dev/null
	elif [ "${CURRENT_IP}" != "${DOCKER_IP}" ]; then
		printf "[INFO]: Updating the Docker host IP for %s in ${HOSTS_FILE} file...\n" "dev.${d%?}"
		sudo sed -ie "/dev.${d%?}/ s/.*/$DOCKER_IP\ dev.${d%?}/g" ${HOSTS_FILE}
	fi
done