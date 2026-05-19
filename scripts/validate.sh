#!/bin/bash

echo "=========================================="
echo "Validating Incus Lab Infrastructure..."

PASS=0

sudo incus network show incusbr0 >/dev/null 2>&1 && echo "OK: incusbr0 exists" && ((PASS++))
sudo incus network show lab-net >/dev/null 2>&1 && echo "OK: lab-net OVN" && ((PASS++))

sudo incus profile show ctl >/dev/null 2>&1 && echo "OK: Profile ctl" && ((PASS++))
sudo incus profile show api >/dev/null 2>&1 && echo "OK: Profile api" && ((PASS++))
sudo incus profile show core >/dev/null 2>&1 && echo "OK: Profile core" && ((PASS++))
sudo incus profile show db >/dev/null 2>&1 && echo "OK: Profile db" && ((PASS++))
sudo incus profile show mon >/dev/null 2>&1 && echo "OK: Profile mon" && ((PASS++))
sudo incus profile show ceph >/dev/null 2>&1 && echo "OK: Profile ceph" && ((PASS++))

sudo incus storage volume show default postgres-data >/dev/null 2>&1 && echo "OK: Volume postgres-data" && ((PASS++))
sudo incus storage volume show default prometheus-data >/dev/null 2>&1 && echo "OK: Volume prometheus-data" && ((PASS++))
sudo incus storage volume show default grafana-data >/dev/null 2>&1 && echo "OK: Volume grafana-data" && ((PASS++))
sudo incus storage volume show default ceph-data >/dev/null 2>&1 && echo "OK: Volume ceph-data" && ((PASS++))
sudo incus storage volume show default app-data >/dev/null 2>&1 && echo "OK: Volume app-data" && ((PASS++))

sudo incus info ctl | grep -q RUNNING && echo "OK: Container ctl RUNNING" && ((PASS++))
sudo incus info api | grep -q RUNNING && echo "OK: Container api RUNNING" && ((PASS++))
sudo incus info core | grep -q RUNNING && echo "OK: Container core RUNNING" && ((PASS++))
sudo incus info db | grep -q RUNNING && echo "OK: Container db RUNNING" && ((PASS++))
sudo incus info mon | grep -q RUNNING && echo "OK: Container mon RUNNING" && ((PASS++))
sudo incus info ceph | grep -q RUNNING && echo "OK: Container ceph RUNNING" && ((PASS++))

sudo incus exec ctl -- ping -c 1 api >/dev/null 2>&1 && echo "OK: ctl -> api connectivity" && ((PASS++))
sudo incus exec api -- ping -c 1 db >/dev/null 2>&1 && echo "OK: api -> db connectivity" && ((PASS++))
sudo incus exec db -- ping -c 1 mon >/dev/null 2>&1 && echo "OK: db -> mon connectivity" && ((PASS++))
# TODO: add extensive internal connection tests

echo ""
echo "Results: $PASS passed"

if [ "$PASS" != 22 ]; then
    echo "Lab deployed with errors, secure shutting down"
    sudo chmod +x shutdown.sh
    bash shutdown.sh 
else
    echo "Lab deployed everything OK"
    echo "Run incus webui as admin to visualy check that out"
fi

#[ $FAIL -eq 0 ] && echo "Infrastructure OK" && exit 0 || echo "Infrastructure has issues" && exit 1
#[ $PASS -eq 22] && echo "Infrastructure OK" && exit 0