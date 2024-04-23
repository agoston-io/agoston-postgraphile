#!/bin/sh
set -x
if [ -z ${TC_ENABLED} ]; then TC_ENABLED=0; fi
if [ -z ${TC_DEV} ]; then TC_DEV=eth0; fi
if [ -z ${TC_UPLOAD_ALL_KBPS} ]; then TC_UPLOAD_ALL_KBPS=16; fi
if [ -z ${TC_UPLOAD_PORT_KBPS} ]; then TC_UPLOAD_PORT_KBPS=1024; fi

if [ ${TC_ENABLED} -eq 1 ]; then

    echo "INFO | TC | Configuring traffic control with below variables:"
    echo "INFO | TC | TC_DEV=$TC_DEV"
    echo "INFO | TC | TC_UPLOAD_ALL_KBPS=${TC_UPLOAD_ALL_KBPS}"
    echo "INFO | TC | TC_UPLOAD_PORT_NUMBER=${TC_UPLOAD_PORT_NUMBER}"
    echo "INFO | TC | TC_UPLOAD_PORT_KBPS=${TC_UPLOAD_PORT_KBPS}"

    # Outgoing traffic control
    tc qdisc add dev ${TC_DEV} root handle 1: htb default 10
    #
    tc class add dev ${TC_DEV} parent 1: classid 1:1 htb rate 10mbit
    tc class add dev ${TC_DEV} parent 1:1 classid 1:10 htb rate ${TC_UPLOAD_ALL_KBPS}kbps
    tc class add dev ${TC_DEV} parent 1:1 classid 1:20 htb rate ${TC_UPLOAD_PORT_KBPS}kbps 
    #
    tc qdisc add dev ${TC_DEV} parent 1:10 handle 10: sfq perturb 10
    tc qdisc add dev ${TC_DEV} parent 1:20 handle 20: sfq perturb 10
    #
    if [ ! -z ${TC_UPLOAD_PORT_NUMBER} ]; then 
        tc filter add dev ${TC_DEV} protocol ip parent 1:0 prio 1 u32 match ip sport ${TC_UPLOAD_PORT_NUMBER} 0xffff flowid 1:20
    fi
    tc filter add dev ${TC_DEV} protocol ip parent 1:0 prio 2 u32 match ip src 0.0.0.0/0 flowid 1:10
    #
    tc qdisc show dev ${TC_DEV}
    tc class show dev ${TC_DEV}
    tc filter show dev ${TC_DEV}
fi 

exec "$@"
