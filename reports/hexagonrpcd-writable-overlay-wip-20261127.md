# 可写 overlay 后端（WIP）：代码就位、**未部署**——卡在「某个方法的参数个数与 def 不符」

> 2026-11-27 续轮。目标 = 让 DSP 对 `/persist/sensors/registry/**` 的写**真正落盘**（现在 write 是假成功，registry 每次 PD 重启重解析）。
> **本轮的成果没有部署**：设备已回「上一版可用二进制」（`hexagonrpcd-patched.bak` → 现在在机），三属性 true、`NRestarts=0`。

## 0. 现状（明确）

| 项 | 状态 |
|---|---|
| 代码 | `patches/userland/hexagonrpc-write-20261127/0002-writable-overlay-WIP.patch`（+805 行 diff，新增 `hexagonrpcd/overlay.{c,h}`） |
| 编译 | 三套构建（host / host-verbose / aarch64-asan-static）全绿；`meson test` 3/3 |
| 上机 | **失败**：`Method invoked with less arguments than expected` ⇒ `run_fastrpc_listener` 退出 ⇒ attach 不完整 ⇒ 三属性 false |
| 已定位到"某方法参数个数不符"，但**尚未知道是哪个** | 已把诊断改成打印方法号（在那份 WIP patch 里），下一轮一发就能看到 |

## 1. 设计（就位部分）

- `overlay_init(dir)`（`-O DIR` / 环境变量）：overlay 根 = 可写目录（设备上 `/var/lib/hexagonrpc`，`fastrpc:fastrpc`）。
- `apps_std` 的 **写模式打开**改走 overlay：`apps_std_copyup()` 先把 mapped 树里的原文件内容拷进来（不存在则建空文件），
  然后 `open(O_RDWR[|O_APPEND])`；返回的 fd 加 `OVERLAY_FD_BASE(1000)` 与虚拟 fd 区分。
- `fread/fwrite/fseek/fclose/fsync` 按 fd 区间分派到 overlay（真读写/真 fsync）或原 hexagonfs。
- `fremove/mkdir/rmdir/ftrunc/frename/ftell/flen/fileExists` 已写实现 + def（表改成**指定下标初始化**，避免 `#742` 那类索引漂移）。
- 本轮验证 overlay 至少被动起来过：设备上出现 `/var/lib/hexagonrpc/mnt/vendor/persist/sensors/registry/registry/DIR`。

## 2. 卡点（下一轮第一件事）

`count_sizes4()` 对我们某个新 def 的 `inbufs/outbufs` 计数与 DSP 实际不符 ⇒ 直接 `AEE_EBADPARM` 且**结束监听循环**。
最可能是 `fwrite`（DSP 可能把 `buf_size` 放在第二个 inbuf 而不是第一个 word）或 `mkdir/ftrunc`（两个 word 是否同 inbuf）。
**下一轮**：用带方法号的诊断（patch 里已改）+ `-Dhexagonrpcd_verbose=true` 的 aarch64 构建，一发定位；必要时按方法逐个开/关二分。

## 3. 为什么值得继续 / 不做的代价

- 不做：传感器能用（已交付），但 **registry 每次 PD 重启都重新解析**、标定/持久化数据丢失；
  实测那条 0 字节骨架一直在（`out/vendor-extract` 里的 registry 是空的，DSP 现在也没地方写）。
- 做：`/var/lib/hexagonrpc` 会积累真实 registry（可备份/可回滚），也为上游 #29 的「registry 写支持」提供一台真机的验证。

## 4. 设备安全态（本轮结束）

`boot_id 82c4fbc2…`→ 现在是最新一次重启；`elden-sensorspd` **active**、`iio-sensor-proxy` **active**、`NRestarts=0`、
三属性 **true**、`ssccli` 连续出值；`/usr/local/bin/hexagonrpcd-patched` = **可用的 0001 版**（`sha256 b015df6d…`），
`-O` 已从 unit 里撤掉（仓库 `packaging/…/elden-sensorspd.service` 与设备一致）。
