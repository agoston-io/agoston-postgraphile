#!/bin/sh
set -x
if [ -z ${TC_ENABLED} ]; then TC_ENABLED=0; fi
if [ -z ${TC_DEV} ]; then TC_DEV=eth0; fi
if [ -z ${TC_UPLOAD_KBPS} ]; then TC_UPLOAD_KBPS=16; fi
if [ -z ${TC_UPLOAD_CBURST_KB} ]; then TC_UPLOAD_CBURST_KB=1024; fi

if [ ${TC_ENABLED} -eq 1 ]; then

    for device in $(echo "${TC_DEV}"| tr ',' '\n'|tr -d '[:blank:]'|egrep -v '^$'); do

        # Outgoing traffic control
        tc qdisc add dev ${device} root handle 1: htb default 10
        #
        tc class add dev ${device} parent 1: classid 1:1 htb rate 10mbit
        tc class add dev ${device} parent 1:1 classid 1:10 htb rate ${TC_UPLOAD_KBPS}kbps cburst ${TC_UPLOAD_CBURST_KB}k
        #
        tc qdisc add dev ${device} parent 1:10 handle 10: sfq perturb 10
        #
        tc filter add dev ${device} protocol ip parent 1:0 prio 3 u32 match ip src 0.0.0.0/0 flowid 1:10
        #
        tc qdisc show dev ${device}
        tc class show dev ${device}
        tc filter show dev ${device}

    done
fi

exec "$@"
