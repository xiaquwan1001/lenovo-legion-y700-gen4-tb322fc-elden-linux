oct8 (out/q28-layout/boot-q28-oct8.img, kernel payload 8efb2731 = Oct-8 vk64)
fastboot boot -> SSH GOOD at uptime 14.6s (card0-DSI-1 connected)
then GUI froze after a few seconds; reboot2 bootloader at ~30s no-op:
  loop runs 2/3/4 = NO-FASTBOOT; SSH timeout, ping loss, no fastboot, no USB device
device hung; needs physical power-cycle (user).
seq log: logs/q28-layout-ab.log
