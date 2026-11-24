# #714 `apt-mark hold` 会把 `dpkg-query -W -f='${Status}'` 首词改成 `hold`，门禁只匹配 `install ok installed` 就常红

> 2026-11-24 实测：`deploy-desktop-shell.sh --check` 报 `MISS phosh-osk-stub`，而包明明装着（`dpkg -l` 首列 `hi`）。
> 同一轮还证实：这两条 MISS 里另一条（`ab-mark-successful` 脚本 sha 与仓内不一致）是**真漂移**，
> 只是升级后没重部署 —— 所以「门红」不能一律当假阳性，得逐条看。

## 判据

```sh
dpkg-query -W -f='${Status}' phosh-osk-stub      # 未 hold: install ok installed
                                                 # 已 hold: hold ok installed   ← 首词变了
```

自编件替发行版同名二进制时，我们**必须** `dpkg-divert` + `apt-mark hold`（PITFALLS #654），
于是「我们自己做的正确动作」会让任何写死 `install ok installed` 的门永久红 —— 常红门的下场是被忽略。

## 处置

- `scripts/deploy-desktop-shell.sh` §2 的判据改成 `*" ok installed"`（2026-11-24 已改，`--check` MISS=0）。
- 通则：**包状态判据只锁尾部 ` ok installed`**，不要锁首词（`install`/`hold`/未来其它 flag 都可能变）。
- 门红后的第一件事是分辨真假：本例另一条 MISS（`/usr/local/sbin/ab-mark-successful` 的 sha 与仓内不同）属真漂移，
  重跑一次 `bash scripts/deploy-desktop-shell.sh` 即同步（该脚本本轮改动只是注释，无行为变化）。
