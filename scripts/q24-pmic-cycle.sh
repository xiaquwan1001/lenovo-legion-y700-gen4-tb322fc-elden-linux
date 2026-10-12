#!/bin/bash
# q24-pmic-cycle.sh LABEL -- 记录当前 PMIC dump，做一次正常重启，回来后连续再 dump 两次（t+0 / t+60）
set -uo pipefail
cd /home/xuqianhui1001/y700-elden || exit 1
LABEL=$1; [ -z "$LABEL" ] && LABEL=cyc
bash scripts/q24-pmic-dump.sh $LABEL-pre > /tmp/q24pmic-pre.log 2>&1; cat /tmp/q24pmic-pre.log
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes root@192.168.7.1)
S(){ timeout "${2:-30}" "${SSH[@]}" "$1" 2>&1; }
echo "== 触发正常重启 =="
S "sync; (reboot -f || busybox reboot -f || reboot) ; echo REBOOT_CMD_RC=$?"
for i in $(seq 1 40); do sleep 5; v=$(S "echo up" 8); [ "$v" = "up" ] && { echo "ssh 回来 after $((i*5))s"; break; }; done
S "cut -d. -f1 /proc/uptime; cat /proc/sys/kernel/random/boot_id" > /tmp/q24pmic-post.env; cat /tmp/q24pmic-post.env
bash scripts/q24-pmic-dump.sh $LABEL-post1 > /tmp/q24pmic-post1.log 2>&1; tail -2 /tmp/q24pmic-post1.log
sleep 60
bash scripts/q24-pmic-dump.sh $LABEL-post2 > /tmp/q24pmic-post2.log 2>&1; tail -2 /tmp/q24pmic-post2.log
echo DONE