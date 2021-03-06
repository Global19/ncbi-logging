#!/bin/bash

# shellcheck source=/home/vartanianmh/strides/strides_env.sh
. "$HOME/strides/strides_env.sh"

set +o errexit # same as -e
set +o pipefail

cd /home/vartanianmh || exit

PGSTATUS=$(pg_ctl status)
echo "$PGSTATUS"
if [[ "$PGSTATUS" = "pg_ctl: no server running" ]]; then
    echo "Starting Postgres"
    mkdir -p "$PGVER/logs"
    pg_ctl -l "$PGVER/logs/logfile" start
fi

pgrep -l grafana
if [ "$?" -eq 1 ]; then
    echo "Starting Grafana"
    nohup "$HOME/$GRAFANAVER/bin/grafana-server" \
        -config "$HOME/$GRAFANAVER/conf/grafana.ini" \
        -homepath "$HOME/$GRAFANAVER" \
        web > grafana.log 2>&1 &
fi


pgrep -l gunicorn
if [ "$?" -eq 1 ]; then
    echo "Starting Gunicorn"
    cd ~/strides || exit
    gunicorn -b "0.0.0.0:$GUNIPORT" --timeout 1800 -D -w 2 --reload \
        --capture-output \
        --access-logfile ~/gunicorn-access.log \
        --error-logfile  ~/gunicorn-error.log \
        myapp:app
fi

# Attempt to pin DB to RAM
#tar -cf - ~/pgdata/ > /dev/zero 2>&1
#find ~/pgdata/ -type f -exec cat {} \; > /dev/null 2>&1

