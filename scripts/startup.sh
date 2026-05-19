#!/bin/bash

echo "Starting up lab..."
echo ""

sudo systemctl start incus.socket && sudo systemctl start incus.service && echo "ON: incus.socket and incus.service started"

sudo incus start ceph && echo "ON: ceph started" || echo "FAIL: ceph"
#sleep 3

sudo incus start db && echo "ON: db started" || echo "FAIL: db"
#sleep 5

sudo incus start mon && echo "ON: mon started" || echo "FAIL: mon"
#sleep 2

sudo incus start core && echo "ON: core started" || echo "FAIL: core"
#sleep 2

sudo incus start api && echo "ON: api started" || echo "FAIL: api"
#sleep 2

sudo incus start ctl && echo "ON: ctl started" || echo "FAIL: ctl"

echo ""
echo "Lab startup complete"