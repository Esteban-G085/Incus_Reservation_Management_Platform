#!/bin/bash

echo "Starting up lab..."
echo ""

sudo systemctl start incus.socket && sudo systemctl start incus.service && echo "ON: incus started"

# Orden: storage (ceph) -> database -> monitoring -> app -> control
sudo incus start ceph 2>/dev/null && echo "ON: ceph started" || echo "OK: ceph already running"
sleep 5

sudo incus start db 2>/dev/null && echo "ON: db started" || echo "OK: db already running"
sleep 5

sudo incus start mon 2>/dev/null && echo "ON: mon started" || echo "OK: mon already running"
sleep 3

sudo incus start core 2>/dev/null && echo "ON: core started" || echo "OK: core already running"
sleep 2

sudo incus start api 2>/dev/null && echo "ON: api started" || echo "OK: api already running"
sleep 2

sudo incus start ctl 2>/dev/null && echo "ON: ctl started" || echo "OK: ctl already running"

echo ""
echo "Lab startup complete"
