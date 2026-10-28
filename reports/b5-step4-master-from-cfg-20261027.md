# B5 第 4 步上机：master 改由 per-SoC cfg 决定（同值臂中性 + 判别臂否证「角色可自由换」）

- 日期：2026-10-27（夜间）
- 设备：TB322FC / elden（SM8750P），根 = Debian `linux17` ext4，全部**零写盘**（`fastboot boot` RAM 载具）
- 依据：`reports/b5-per-soc-cfg-design-20261027.md` §5.3、`reports/b5-resoc-20261027.md` §5（第 1–3 步已备料）
- 内核树：`build/vk151`（日常线 `24223e44a` + 工作区改动）现场叠加 `patches/local/b5-resoc-20261027/000{1,2,3}`
  + 本轮新增 `0004-dsi-bonded-master-from-cfg.patch`

## §0 结论（数字）

| 臂 | 镜像 | master 来源/取值 | 判据 | 结果 |
|---|---|---|---|---|
| 基线（设备原态） | — | 现役 vk172 载荷 | 7 项计数 | 全 0（`dpms=Off` 屏灭） |
| **步骤 1–3** | `vk178-b5verify`（sha `ad8d975e…`） | 未改（bind 顺序） | 7 项计数 + 20 轮亮度/熄屏循环 | **全 0**、`boot_id` 不变、phoc/phosh 在 |
| **第 4 步 · 同值臂** | `vk179-b5step4a`（sha `05ce69e7…`） | `bonded_cfg->master_link_id` = **DSI0**（与现状同值） | 同上（10 轮） | **全 0**（连开机首次 modeset 的 2 条 vblank 都没有） |
| **第 4 步 · 判别臂** | `vk180-b5step4b`（sha `f5517296…`） | 强改 **DSI1**（与现状相反） | 同上 | **面板 init 失败**：`ff 20` 三连 `-22`；`panel is not prepared; refusing video enable` |
| 复原 | `vk181-daily`（sha `c8953ba0…`） | 从**已还原**的日常线树重打 | 设备回 Debian 根、`marker` 空 | ✅ |

**两条结论**

1. **第 4 步本身行为中性**：把 master 从「bind 顺序」改成「per-SoC 表项」后，同值臂与基线逐项一致（7 项错误计数全 0，
   10 轮熄屏/唤醒与 30 次 DCS 亮度写无一条报错）。
2. **bonded 主从角色不可自由交换（否证设计稿 §5.3 的开放性）**：把 `master_link_id` 强行改成 DSI1 后，
   **面板所在的 DSI0 首条 DCS（`ff 20`）直接 `-22`**、3 次重试全败，master 侧随后
   `panel is not prepared; refusing video enable`。⇒ `master_link_id` 只能是**事实登记**（本机 = DSI0 = 挂 panel 的那条），
   不是可调旋钮；上游提交里该字段应附「必须与 panel 所在 link 一致」的断言，而不是当成 DT 可配置项。

**为什么「显示看起来还是好的」是个陷阱**：判别臂下 `card0-DSI-1 = connected/enabled/dpms=On`、phoc/phosh 在跑、
`grim` 截图**正常出锁屏界面**（video 通路不依赖面板 init 的 DCS）。若只看「有没有画面」会误判成功；
唯一露馅的是 dmesg 的 `-22`。⇒ 后续任何 DSI 改动都必须以 **DCS 命令通路**为判据，不能以「有画面」为判据。

## §1 现场取证（判别臂关键行）

```
[    3.474736] panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -22
[    3.474739] panel-novatek-nt36536 ae94000.dsi.0: panel init attempt 1 failed: -22, resetting and retrying
[    3.503728] panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -22
[    3.503730] panel-novatek-nt36536 ae94000.dsi.0: panel init attempt 2 failed: -22, resetting and retrying
[    3.532752] panel-novatek-nt36536 ae94000.dsi.0: sending dcs data ff 20 failed: -22
[    3.532755] panel-novatek-nt36536 ae94000.dsi.0: Failed to initialize panel: -22
[    3.533017] msm_dsi ae96000.dsi: panel is not prepared; refusing video enable
```

对照：同值臂与步骤 1–3 臂均**无**上述行，且 `Failed to initialize panel = 0`。

## §2 代码改动（`0004-dsi-bonded-master-from-cfg.patch`，+36 −5，三文件）

- `dsi.h`：新增 `msm_dsi_host_get_bonded_cfg()` 原型（1 行；`dsi.h` 对外面 2 → 3）。
- `dsi_host.c`：实现该访问器（复用已有的 `dsi_bonded_cfg()`）。
- `dsi_manager.c`：新增 `dsi_mgr_bonded_master_link_id(id)`（有表读表、无表回落 DT/probe 顺序），
  `IS_MASTER_DSI_LINK()` 与 `dsi_mgr_bonded_cmd_xfer()` 的 master 解析改走它。
- 编译：`build/b5-resoc`（lane 树）`make -j8 drivers/gpu/drm/msm/` **rc=0、0 warning**。
  ⚠ 遇到一次 **gcc 15 并发 ICE**（`internal compiler error: 段错误`，与改动无关，串行重编即过；
  同一现象 `reports/b5-resoc-20261027.md` §4 已记过，本轮复现第二次）。

## §3 落地细节（可复跑）

```sh
# 1) 在日常线树上叠加 1–4 步（先备份工作区 diff！）
git -C build/vk151 diff > /tmp/vk151-dirty.patch
for p in patches/local/b5-resoc-20261027/000{1,2,3,4}-*.patch; do git -C build/vk151 apply "$p"; done
# 2) LOCALVERSION 钉住设备 UTS ⇒ 直接复用设备 /lib/modules（B5 改动全在 vmlinux，无 =m 变化）
. scripts/env-build.sh && LOCALVERSION=-debug-vk172 make -C build/vk151 -j26 ARCH=arm64 Image.gz dtbs
LOCALVERSION=-debug-vk172 VERSION=vkNN RAMDISK=$PWD/out/initramfs-full-elden.cpio.gz \
  ROOTARGS=elden_root=LABEL=linux17 CMDLINE_EXTRA="elden_early_gadget=1 elden_q28_nowd b5verify=<tag>" \
  bash scripts/build-boot.sh
# 3) 零写盘上机 + 判据
fastboot boot out/boot-elden-vkNN*.img      # 设备侧 /proc/cmdline 含 b5verify=<tag> 才算新内核
```

**为什么要 `b5verify=` 标记**：UTS 被刻意钉成与设备同一串（复用模块树的前提），
所以 `uname -r` **不能**区分新旧内核；`/proc/cmdline` 标记 + `uname -v` 的构建时间才是身份判据。

## §4 与上游化相关的两条口径

1. `master_link_id` 进表时**必须**写明「= 挂 panel 的 link」，并加运行期断言（或至少在 `bonded_cmd_xfer` 里校验
   `msg` 来自的 host 就是 master），否则一旦 DT/绑定顺序变化就是静默 `-22`。
2. 判别臂的结果说明：`msm_dsi_host_bonded_cmd_xfer()` 目前**不看调用者 id**（只按 master 决定广播），
   这正是 `-22` 的直接来源（panel 在 DSI0 上发命令，引擎却按 DSI1 组装）。上游收这个补丁前应把
   「调用者必须是 master」做成显式检查 + `dev_warn`，而不是让底层返回 `-22`。

## §5 产物

| 文件 | 说明 |
|---|---|
| `patches/local/b5-resoc-20261027/0004-dsi-bonded-master-from-cfg.patch` | 第 4 步（+36 −5，3 文件） |
| `out/boot-elden-vk178-b5verify.img` | 步骤 1–3 验证件（manifest 齐） |
| `out/boot-elden-vk179-b5step4a.img` | 第 4 步同值臂 |
| `out/boot-elden-vk180-b5step4b.img` | 第 4 步判别臂（master=DSI1） |
| `out/boot-elden-vk181-daily.img` | 复原件（还原后日常线树，设备复原用） |
| `/tmp` 级 | 判别臂截图（锁屏正常）→ 已随本报告口径记录，未入仓 |

## §6 未做

- 第 5 步隔离层（`err_clear_bits`/`err_cleanup_bits` 魔数、`dsi_sw_reset_v2_9()`）——仍是 RFC-SCOPE R1 阻断项。
- `needs_link_clk_bump` / `needs_sw_reset` 仍只是**登记数据**，`dsi_cmd_link_clk_set_rate()` / `dsi_sw_reset()` 两处兼容判断未改。
- U2（非原子→原子回调时序）仍是独立项，本次未触及（判据需要 `drm.debug=0x4` 时间线，留待合并 U2 时一起做）。
- 未投递：第 4 步属「会变行为的具体实现」，要等 M6 上游四问的回音或 P4-RFC 立起来后一起走。
