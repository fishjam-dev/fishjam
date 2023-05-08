#!/bin/sh

log_debug() {
    if [ "$DOCKER_DEBUG" = 'true' ]; then
        echo -e $1
    fi
}

# root has always UID 0 no matter if we are in docker
# or on the host
if [ "$(id -u)" = '0' ]; then

    log_debug "Running as root. Fixing permissions for: \ 
    $(find . \! -user jellyfish -exec echo '{} \n' \;)"
        
    find . \! -user jellyfish -exec chown jellyfish '{}' +
    exec gosu jellyfish "$0" "$@"
fi

log_debug "Running as user with UID: $(id -u) GID: $(id -g)"

exec "$@"
