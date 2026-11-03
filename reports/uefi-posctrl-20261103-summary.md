# UEFI 线阶段总结（2026-11-03 下午）：DDR 正控打通，载荷可执行性问题被重新定位

> 性质：主机侧构建 12 件 + 设备侧 **9 发零写盘 `fastboot boot`**（无一次写分区/槽位/GPT）。
> 前序：`reports/uefi-next-step-decision-20261103.md`（三线核查后的裁决）、`reports/uefi-posctrl-linux-entry-20261103.md`（正控细节）。
> 设备：HA2EXB0E（U2），在机 `boot_b` = `fb55997c…`（未改动）。

---

## §0 三条被今天推翻的旧口径（这是本轮最重要的产出）

| # | 旧口径（此前被当作结论） | 今天的证据 | 新口径 |
|---|---|---|---|
| 1 | 「`fastboot boot` 后 `Booting FAILED (usb_read failed)` = **交棒成功 = 载荷被执行**」（11-01 起用了 7 次） | 3 个自旋探针都出现同一信号（`0.056 s` / `10.106 s` 两种），但**四窗标记全 0**；而同一通道下的真内核标记 95%–98% | **该信号只说明 ABL 拆了 USB**（接受后挂死 / 早期拒绝都算）。**载荷是否执行必须看 DDR 标记**，不能看 USB |
| 2 | 「跳转后 1–2 s 掉电 = ABL 武装的硬件看门狗没人喂」 | 自旋探针在 logo 上**躺了数分钟**没被任何看门狗复位；ABL 日志只有 `PM: Reset by PSHOLD`（与正常重启同款） | **不存在 1–2 s 看门狗**。那 1–2 s 掉电是载荷/固件自己崩（更像 TZ/SCM 致命错），与 wdog 无关 |
| 3 | 「v0 repack 只能 `--base 0x10000000`，否则静默不交棒」（PITFALLS #418） | 判据本身就是上面第 1 条那个坏信号 ⇒ 该结论从未被测到变量 | **#418 降级为「未证实」**，不再当约束 |

## §1 DDR 黑匣子**正控已通过**（今天唯一干净的正面结果）

| 项 | 值 |
|---|---|
| 件 | `out/boot-elden-posctrl-20261103.img`（sha `9dfdb331…`）：在机 `boot_b` 原件**只换内核段**（`--verify` = `only-kernel-differs`），内核在 `arch/arm64/kernel/head.S::primary_entry` **第一条**写四窗各一页 0xFF |
| 上机 | `fastboot boot` → `Sending OKAY 1.87 s` / `Booting OKAY 10.106 s`；用户目视「过 logo 后只剩背光亮」= 内核已执行 |
| 读回（断电重启→Linux） | `0xE3F00000` **95.2%**、`0x84A00000` **97.3%**、`0x9C300000` **97.2%**、`0x89300000` **97.8%** 字节 = `0xFF`；page1 全 0 |
| 结论 | **通道成立**：boot.img 装载的代码在极早期写这些窗口 → 复位 → Linux 侧读得回。⇒ 11-02「四臂 stage1=0」**不是假阴性** |
| 附带 | 真内核载荷存活 ≥2 min（不是 2 s）⇒ 见 §0-2 |

## §2 载荷可执行性：9 发结果表

| # | 载荷 | 头 | 路径 | ABL 表现 | DDR 标记 |
|---|---|---|---|---|---|
| 1 | 真 Linux 内核（在机原件，gz 19 MB） | v2 base0 | fastboot boot | `Booting OKAY 10.106 s` | **有**（95%，正控） |
| 2 | UEFI `ddrmarks-clean`（shim+FD，gz 2.4 MB，`text_offset=UEFI_BASE`） | v0 base 0x10000000 | fastboot boot | `usb_read failed` **0.056 s** | **0**（clean prep 后） |
| 3 | `markspin` v1 92 B 裸（无 Image 头） | v2 | fastboot boot | `10.106 s` 后挂 logo | 污染（19–37%，见 §3）→ 作废 |
| 4 | `markspin2` 132 B 裸（魔数 0xA5A5A5A5 @page25） | v2 | fastboot boot | 挂 logo | **魔数 0** |
| 5 | `markspin3` 172 B 裸（**正确 Image 头**：`b`/`text_offset=0`/`image_size`/`ARM\x64`） | v2 | fastboot boot | 挂 logo | **魔数 0** |
| 6 | `markspin3.bin.gz` 137 B **gz** | v2 | fastboot boot r1 | 未发（`reboot bootloader` 卡死） | — |
| 7 | 同上 gz | v2 | fastboot boot r2 | `10.106 s` 后挂 logo | **未读**（设备卡 logo，需断电一次） |
| 8 | UEFI `text_offset=0`（gz 2.4 MB，其余同 #2） | v0 base 0x10000000 | fastboot boot | `usb_read failed` **0.056 s** | **0** |
| 9 | 同 #8 复跑（clean prep 后立刻） | 同上 | 同上 | 同上 | **0** |

**由此得到的判据分层**：

- ABL 对「真内核」：`Sending` 慢（1.4–1.9 s，按体积）+ `Booting OKAY ~10.1 s` + **跳进去执行**。
- ABL 对「我们的 UEFI 件」：`Sending` **0.056 s** + 立刻 `usb_read failed` + 2 s 内回落 Android ⇒ **早期就拒绝/崩了，从未跳到载荷**。
- ABL 对「小裸件/小 gz 件」：`~10.1 s` 后拆 USB 并**挂死在 logo**（既不回落 Android，也无任何输出）⇒ **接受后没跳或跳了没执行**。

⇒ **"10.106 s" 与 "0.056 s" 是 ABL 两条不同的结局**，而此前把两者都叫「交棒」。

## §3 一个必须记住的取证坑（污染）

16:48 那次读回：`0x84A00000` / `0x89300000` 整窗 208 页 **≈95% 全是 0xFF**、`0x9C300000` 只有 page0 82%。
但同一批件在 **clean prep 后立刻复跑**读回是**全 0**。⇒ 那是设备长时间「卡在白色 splash/logo」期间写进这些 carveout 的
**显示/固件数据**，不是我们的标记。
**纪律**：① 标记必须在 prep 之后、下一发之前；② 读回要在恢复后的第一个 Linux 会话里立刻做；
③ 整窗大范围 0xFF（>1 MiB）一律先当污染看待，不能当「执行过」。

## §4 现在的证据指向

1. **UEFI 件的失败点不在 UEFI 内部**（UFS/Timer/看门狗/显示都与它无关）：它在 ABL **0.056 s** 就被否掉。
   与真内核的差别集中在「**boot image 头 + 载荷头**」这一层，而不是代码内容。
2. **`text_offset=0` 单独不够**（#8/#9）。仍待对齐的字段（与真内核逐项比）：
   `code0` 必须是 **branch**（我们的 shim 现在写的是 `adr x1,_Payload`，不是 branch）、
   `image_size` = **解压后的真实长度**（我们填 `0x400000`=窗口大小）、`flags`（我们 0x0，真内核 0xa）、
   以及**打包头**：真内核走 **v2 base 0 / kernel_offset 0x8000**，我们走 **v0 base 0x10000000**。
3. 小载荷（<1 MB）无论裸或 gz 都**未观察到执行**，但也**没有自恢复**（每次都卡 logo 要人工断电）⇒ 探针本身要先做成"自己回来"的形态，否则每发都要用户按电源。

## §5 下一步候选（按性价比，供选择）

| 优先级 | 动作 | 为什么 | 成本 |
|---|---|---|---|
| **P1** | 把 UEFI 载荷的 Image 头**逐字段对齐真内核**（`code0` 改真 branch、`image_size`=真实解压长度、`flags=0xa`、`text_offset=0`）+ 改走 **v2 base0** 打包 | #2/#8 的 0.056 s 说明 ABL 在头校验阶段就否掉；真内核路径已知能执行 | 主机侧 ~1 h + 1 发 |
| **P2** | 探针改成「写标记 → 跳进真内核」的自恢复形态（标记读回不再需要人工断电） | 现在每发都要用户按电源，且长时间卡 logo 会污染窗口 | 主机侧 ~2 h |
| P3 | 读完 #7（gz 小载荷）的魔数 | 只差一次断电；回答「gz 是否让小载荷可执行」 | 1 次用户动作 |
| P4 | 用 logfs 的 `Start EBS [ms]` 做「ABL 花了多久」的对照（真内核 vs 我们件） | 0.056 s vs 10.1 s 的机制区分 | 已有数据，~20 min |

## §6 证据与产物

- 报告：本文件、`reports/uefi-posctrl-linux-entry-20261103.md`、`reports/uefi-next-step-decision-20261103.md`
- 补丁：`patches/uefi/20261103-posctrl/{0001-arm64-head-ddr-stage1-marks.patch, 0002-bootshim-text-offset-zero-plus-marks.patch, markspin.S, markspin2.S, markspin3.S}`
- 工具（本轮新增）：`scripts/bootimg-replace-kernel.py`（只换内核段 + 结构对账）、`scripts/bb-magic-scan.py`（整窗魔数扫描）
- 镜像：`out/boot-elden-posctrl-20261103.img`（`9dfdb331…`）、`…-markspin2-v2…`、`…-markspin3-v2…`、`…-markspin3gz-v2…`（`05d43285…`）、
  `reports/artifacts/uefi-posctrl-20261103/textoffset0/uefi-v0.img`（`8ed4ffc1…`）
- 现场：`reports/artifacts/uefi-boot-20261103-{142023,145434,151302,161*,1702*}/`；trial 记录 `reports/trials/20261103T*-uefi-*.json`
