# `fastboot boot` 之后的 USB 是 `1d6b:0104` 且要 60–90 s 才枚举；按 VID 白名单判活会误判「设备死了」（#391）

> 日期：2026-10-25 · 场景：`fastboot boot` 一个正常 Linux 镜像后，主机侧
> `lsusb | grep -E "18d1|05c6"` 连续 120 s 无命中 ⇒ 会话里被判成「SoC 硬挂、要人工断电」。
> 实际设备 90 s 内起好了、SSH 一直可用。

## 事实

- fastboot 阶段 USB = `18d1:d00d`（Google bootloader gadget）。
- **交棒成功那一刻 fastboot gadget 消失**（这正是 PITFALLS #387 的「真交棒」判据），
  随后 Linux 的 composite gadget 才枚举，VID:PID = **`1d6b:0104` "Multifunction Composite Gadget"**（不是 Google/Qualcomm 的 VID）。
- 该 gadget 枚举**慢**：本机实测从 `Booting OKAY` 到 `lsusb` 见到 `1d6b:0104` 约 60–90 s，
  期间 `ping 192.168.7.1` / SSH 全不可达是**正常过渡态**。
- 更早的一次（同日）判断错在：`lsusb | grep -E "18d1|05c6|2c7c"` 模式里没有 `1d6b`。

## 纪律（判活三件套，不用 VID 白名单）

```bash
lsusb                      # 全量看，出现 1d6b:0104 = 已在 Linux
timeout 5 ssh -o BatchMode=yes -o ConnectTimeout=4 root@192.168.7.1 'uptime'
timeout 5 fastboot devices # 有输出 = 仍在 bootloader（#387 的「接受但不跳」）
```
判定表：
| `1d6b:0104` | `ssh` | `fastboot devices` | 结论 |
|---|---|---|---|
| 有 | 通 | 空 | ✅ 已起 Linux |
| 空 | 不通 | 有 | 仍在 bootloader（可能没交棒，见 #387） |
| 空 | 不通 | 空 | 才是真挂/正在枚举（≥120 s 才可判死） |

## 连带坑：`scripts/flash-b.sh` 写死 `ssh -6` + 默认 `TABLET` 是 IPv4 字面量

```
ssh: Could not resolve hostname 192.168.7.1: Address family for hostname not supported
```
设备 `usb0` 的 link-local 是 `fe80::1e:5eff:feed:e101`（主机侧才是 `fe80::c245:…`，别抄错）。
当时的绕过办法：

```bash
TABLET="root@fe80::1e:5eff:feed:e101%enx021e5eede102" bash scripts/flash-b.sh <img>
```
脚本已改为 IPv4/IPv6 都可用（去掉了强制 `-6`，见同轮提交）。
