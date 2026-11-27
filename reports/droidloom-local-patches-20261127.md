# droidloom 本地 patch 备料 — 2026-11-27（D24 lane）

## 结论

4 条 patch 落成 `patches/local/droidloom-local-20261127/`，在 release 51 源码（`~/dl-droidloom-51/droidloom-source-0.1.0-51.tar.gz` 解至 `/tmp/droidloom-51-src/droidloom`）上实测 `git apply --check`：**按序 001→002→003→004 全部通过**。003 单独 apply 失败（依赖 002 的上下文），其余三条独立通过。

---

## 一、四条 patch 概览

| # | 文件 | 一句话 | 来源 | 作者 | 日期 |
|---|---|---|---|---|---|
| 001 | `001-wifi-provisioning-self-healing.patch` | WifiProvisioning 用 NETWORK_STATE_CHANGED 监听 + `enableNetwork(id,true)` 替掉一次性 `wifi_provisioned` 位，自愈永久禁用的 SSID | [gotakllc/droidloom@4e995f2](https://github.com/gotakllc/droidloom/commit/4e995f2ae33ec8689c862b9f5e79c91fecb02bad)（仅取 WifiProvisioning.java hunk） | Doctor Logix（= 维护者本人） | 2026-11-26T20:07Z |
| 002 | `002-remove-forward-signals.patch` | 去掉 `unshare --forward-signals`（需 util-linux ≥2.42），改为 pidfd 直发 SIGTERM 到 Android PID 1 | [EvilBorsch/droidloom@5380af3](https://github.com/EvilBorsch/droidloom/commit/5380af354f4a1d027d365f58c26a481bf2676064) | EvilBorsch | 2026-11-22T08:21Z |
| 003 | `003-host-resolvers-in-lease.patch` | DHCP lease 读宿主 `/run/systemd/resolve/resolv.conf` 填 nameserver（替掉硬编码 1.1.1.1/8.8.8.8）；stop 改 power-off 序列 | [EvilBorsch/droidloom@2712d37](https://github.com/EvilBorsch/droidloom/commit/2712d37c58d38ef4f1d4586ef07e5d1596ea7246) | EvilBorsch | 2026-11-22T10:23Z |
| 004 | `004-runuser-sbin-path.patch` | `runuser` 路径从硬编码 `/usr/bin` 改为 `/usr/bin` 或 `/usr/sbin` 双路径探测 | [EvilBorsch/droidloom@201000a](https://github.com/EvilBorsch/droidloom/commit/201000a7a50f3bc3f6f15d7b4e6449bd75d2136e) | EvilBorsch | 2026-11-21T22:35Z |

---

## 二、退役判据（写进每条 patch 头注释）

| # | 退役条件 |
|---|---|
| 001 | `grep -q "reconnect" WifiProvisioning.java` 且 `grep -q "getBoolean.*DONE.*false" WifiProvisioning.java` 失败（自愈版进上游 main） |
| 002 | `strings /usr/bin/droidloom-supervisor \| grep -c forward-signals` = 0 |
| 003 | `strings /usr/bin/droidloom-supervisor \| grep -c resolv.conf` > 0（或 cell 内 `dumpsys connectivity` 的 DNS ≠ 1.1.1.1/8.8.8.8 且未手工 nft 重定向） |
| 004 | `grep -c '/usr/sbin/runuser' runtime/droidloom-package-support/src/main.rs` > 0（上游合并双路径） |

---

## 三、`git apply --check` 实测（base = release 51 源码）

环境：`/tmp/droidloom-51-src/droidloom`（tar 解压后 `git init && git add -A && git commit`，单 commit 基线）。

### 单独 apply（每条独立 vs base）

| # | 结果 | 详情 |
|---|---|---|
| 001 | **PASS** | `git apply --check` RC=0，无 fuzz |
| 002 | **PASS** | RC=0，无 fuzz |
| 003 | **FAIL** | `error: patch failed: runtime/droidloom-supervisor/src/development.rs:380`。原因：003 的 development.rs hunk 以 002 的输出（`signal_namespace_init()` 调用 + 注释）作为上下文；base 51 第 383 行仍是裸 `signal_process(self.child.id(), libc::SIGTERM)?;`。dhcp_responder.rs 与 development_network.rs 部分不受影响（已验证单独提取可 PASS）。 |
| 004 | **PASS** | RC=0，无 fuzz |

### 按序 apply（001→002→003→004）

| 步 | 结果 |
|---|---|
| 001 | OK |
| 002 | OK |
| 003 | OK |
| 004 | OK |

**结论**：四条 patch 在 release 51 上**零冲突**（前提：003 排在 002 之后）。上设备时按序号 `git am` 或 `patch -p1` 即可。

---

## 四、上设备前回退方案

备份现役 runtime：`cp -a /usr/bin/droidloom-supervisor /usr/bin/droidloom-package-support /usr/local/bin/backup-runtime-49/`（或直接 `tar czf ~/runtime-49-backup.tar.gz /usr/bin/droidloom-*`）。回退 = 解回备份 + `systemctl restart droidloom`。若走 A/B 分区或 chroot，按 `.pi/AGENT-OPS.md` 的备份清单。

---

## 五、产物清单

```
patches/local/droidloom-local-20261127/
├── 001-wifi-provisioning-self-healing.patch   (7221 B, 163 行)
├── 002-remove-forward-signals.patch           (6972 B)
├── 003-host-resolvers-in-lease.patch          (20651 B)
└── 004-runuser-sbin-path.patch                (3484 B)
```

---

## 六、复现命令

```bash
# 解 source-51
mkdir -p /tmp/dl51 && tar xf ~/dl-droidloom-51/droidloom-source-0.1.0-51.tar.gz -C /tmp/dl51
cd /tmp/dl51/droidloom && git init && git add -A && git commit -m base -q

# 四条按序检查
cd /home/xuqianhui/y700-elden/patches/local/droidloom-local-20261127
for p in 001 002 003 004; do
  (cd /tmp/dl51/droidloom && git checkout -- .)
  [ "$p" = "003" ] && (cd /tmp/dl51/droidloom && git apply 002-*.patch)
  (cd /tmp/dl51/droidloom && git apply --check $p-*.patch && echo "$p PASS" || echo "$p FAIL")
done
```

---

## 七、残余风险

1. **001 是 Java、在 image 包里**：需重编 AOSP `droidloom-systemui` 模块或等上游发版；纯 runtime 重编不含它。当前只做了 `git apply --check`（文本级），未验证编译通过（缺 AOSP build 环境）。
2. **003 的 power-off stop 语义变更**：原来 stop = SIGTERM → 10s 超时 → kill；改后 = `setprop sys.powerctl shutdown` → 337ms 干净关闭。若 `nsenter` 在 cell 内不可用（权限/SELinux），stop 会退化到 `signal_process`（SIGTERM 兜底路径保留）。
3. **002+003 合在一起 = 完整的「非 Arch 发行版 stop 修法」**：若上游将来发版修了 `--forward-signals` 但没修 resolver，003 仍需保留但 002 可退役。
4. **未实际 `git am`（保留了 `Signed-off-by` trailer 缺失）**：若需 `git am` 签名链，需补 signoff。当前 `git apply` 路径可用。
