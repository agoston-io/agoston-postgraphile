#!/bin/sh
if [ -z ${TC_ENABLED} ]; then TC_ENABLED=0; fi
if [ -z ${TC_DEV} ]; then TC_DEV=eth0; fi
if [ -z ${TC_UPLOAD_KBPS} ]; then TC_UPLOAD_KBPS=16; fi

if [ ${TC_ENABLED} -eq 1 ]; then

    echo "INFO | TC | Configuring traffic control with below variables:"
    echo "INFO | TC | TC_DEV=$TC_DEV"
    echo "INFO | TC | TC_UPLOAD_KBPS=${TC_UPLOAD_KBPS}"

    # Outgoing traffic control
    tc qdisc add dev ${TC_DEV} root handle 1: htb default 10
    #
    tc class add dev ${TC_DEV} parent 1: classid 1:1 htb rate 10mbit burst 15k
    tc class add dev ${TC_DEV} parent 1:1 classid 1:10 htb rate ${TC_UPLOAD_KBPS}kbps ceil ${TC_UPLOAD_KBPS}kbps burst 15k
    #
    tc qdisc add dev ${TC_DEV} parent 1:10 handle 10: sfq perturb 10
    #
    tc filter add dev ${TC_DEV} protocol ip parent 1:0 prio 1 u32 match ip src 0.0.0.0/0 flowid 1:10
    #
    tc qdisc show dev ${TC_DEV}
    tc class show dev ${TC_DEV}
    tc filter show dev ${TC_DEV}
fi 

exec "$@"
