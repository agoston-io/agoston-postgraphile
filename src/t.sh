xx=$1

set -x 

tc qdisc show dev eth0
tc qdisc del root dev eth0

# HTB root 
tc qdisc add dev eth0 root handle 1: htb default 30
tc class add dev eth0 parent 1: classid 1:1 htb rate $xx burst 15k

# classes
tc class add dev eth0 parent 1:1 classid 1:10 htb rate $xx burst 15k
tc class add dev eth0 parent 1:1 classid 1:20 htb rate $xx burst 15k

# sfq on tree nodes
tc qdisc add dev eth0 parent 1:10 handle 10: sfq perturb 10
tc qdisc add dev eth0 parent 1:20 handle 20: sfq perturb 10


# filters
tc filter add dev eth0 protocol ip parent 1: prio 1 u32 match ip dst 0.0.0.0/0 flowid 1:10
tc filter add dev eth0 protocol ip parent 1: prio 1 u32 match ip src 0.0.0.0/0 flowid 1:20
