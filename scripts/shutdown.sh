#!/bin/bash

echo "Shutting down lab..."
echo ""

sudo incus stop api 2>/dev/null && echo "OFF: api stopped" || echo "FAIL: api"
sudo incus stop core 2>/dev/null && echo "OFF: core stopped" || echo "FAIL: core"
#sleep 2

sudo incus stop mon 2>/dev/null && echo "OFF: mon stopped" || echo "FAIL: mon"
#sleep 2

sudo incus stop ceph 2>/dev/null && echo "OFF: ceph stopped" || echo "FAIL: ceph"
#sleep 2

sudo incus stop db 2>/dev/null && echo "OFF: db stopped" || echo "FAIL: db"
#sleep 3

sudo incus stop ctl 2>/dev/null && echo "OFF: ctl stopped" || echo "FAIL: ctl"

sudo systemctl stop incus.socket && sudo systemctl stop incus.service && echo "OFF: incus.socket and incus.service stopped"

echo ""
echo "Lab shutdown complete"