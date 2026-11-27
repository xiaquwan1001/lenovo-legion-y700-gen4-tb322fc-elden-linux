# #750 · 传感器 unit 在 `/dev/fastrpc-adsp` 缺失时**不能用 `ExecStartPre` 等一会就 `exit 1` + `Restart=on-failure`**（实测每 65 s 重启，累积 47 次）

- 日期：2026-11-27（接续轮）
- 现场：内核换成 `build/daily` 直出（`7.3.1-debug-vk189-suspend-g4da9a8b69fc8-dirty`）后 `/dev/fastrpc-adsp` 不存在
  （该 DTB 缺 adsp fastrpc 的 `qcom,non-secure-domain`），原 unit 的 `ExecStartPre` 等 60 s → `exit 1` → `Restart=on-failure`
  ⇒ 每 ~65 s 重启一次，`NRestarts` 累到 **47**，日志/CPU 白烧，且 `--failed` 里看不出「只是缺内核节点」。
- 判据/做法：
  - unit 用 **`Type=oneshot` + `RemainAfterExit=yes`**，ExecStart 用一个小脚本**有界等待**（90 s）；
  - 等不到就打印一行原因并 **`exit 0`**（成功结束，不进失败态、不触发 Restart）；
  - 再叠加 `RestartPreventExitStatus=1` + `StartLimitBurst=3/300s` 兜底。
  - 判据命令：`systemctl show -p NRestarts -p Result elden-sensorspd`（修后 = 0 / success）、`--failed` = 0。
- 另一条同源事实：**「传感器不起」先看 `/dev/fastrpc-adsp` 是否存在**，再看内核 DTB 有没有 `qcom,non-secure-domain`
  （G1-34 / `PITFALLS #741`），别一上来查 hexagonrpcd 或 libssc。
- 关联：`reports/sensors-ssc-persistent-20261127.md` 修订节、仓库副本 `packaging/elden-userland/files/{etc/systemd/system/elden-sensorspd.service,usr/local/sbin/elden-sensorspd-start}`。
