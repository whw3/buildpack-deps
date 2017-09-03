#!/usr/bin/with-contenv bash
if [[ -x /usr/local/bin/docker-entrypoint ]]; then
    exec /usr/local/bin/docker-entrypoint
elif [[ -x /docker-entrypoint ]]; then
    exec /docker-entrypoint
elif [[ -x /entrypoint.sh ]]; then
    exec /entrypoint.sh
fi
