# T14 用户态驱动/服务独立固化 — 剩余缺口分析（2026-11-11）

- 范围：packaging/elden-userland 门禁已 FAIL=0；剩余 = Mobian 换根后的重建 recipe。
- 7 个自编 ELF 中 3 个无源码、其中 2 个动态链接 musl。
- 本轮环境：仅校园网直连，无外网；只读分析 + 本报告落盘；无设备（涉及设备步骤标「待上机」）。

## §0 首要发现：前提已过时，缺口已在 2026-11-04 关闭

任务前提「7 个 ELF 中 3 个无源、其中 2 个动态 musl」来自
`reports/userland-service-inventory-20261025.md`（当时 4 ok / 3 missing）。
该缺口已被 `build/artifacts.tsv` 头注记的 **0e60a55（2026-11-04 基线）补齐：ok=7 / missing=0**。
本轮实跑门禁复核：

- `bash packaging/elden-userland/tools/verify.sh` → **FAIL=0 WARN=1**（唯一 WARN = 设备不可达跳过 F 段，预期）。
- `bash packaging/elden-userland/tools/verify.sh --rebuildable` → **FAIL=0 WARN=0**，
  `ELF 共 7 个：ok=7 missing=0；配方 7 个可 --dry-run；产物 sha 与清单 identical=3 diff=4`。

因此 T14 剩余工作只剩「Mobian 换根重建 recipe 的可执行化与验收」，而非补源码。

## §1 缺口点名表（7 个自编 ELF，本机副本现查）

来源：`MANIFEST.tsv`（设备侧 sha/size）+ `sources.tsv` + `build/artifacts.tsv`。
file/ldd 为本机 `out/` 副本实测（ldd 在 x86 宿主无法执行 aarch64，动态/静态以 file 输出为准）。

| # | 设备路径 | size | file（本机副本） | 链接 | 源 | recipe | 产物 sha vs MANIFEST |
|---|---|---|---|---|---|---|---|
| 1 | /usr/local/bin/elden-hapticd | 729312 | static ARM aarch64 | 静态 | scripts/elden-hapticd.c | build/elden-hapticd.sh | identical |
| 2 | /usr/local/bin/eldroid-sensord | 778944 | static（本机副本 663536，设备件为静态） | 静态 | scripts/eldroid-sensord.c | build/eldroid-sensord.sh | diff |
| 3 | /usr/local/bin/ffrumble | 775544（设备）/ 597920（副本） | static | 静态 | scripts/ffrumble.c（2026-10-25 重写） | build/ffrumble.sh | diff |
| 4 | /usr/local/bin/waydroid-sensord | 266200 | pie, dyn, interpreter /lib/ld-linux-aarch64.so.1 | **动态 glibc** | patches-userland/waydroid-sensord-udp/ | build/waydroid-sensord.sh | identical |
| 5 | /usr/local/bin/waydroid-sensord-udp | 266200 | 同上（同源双文件名） | **动态 glibc** | 同上 | build/waydroid-sensord-udp.sh | identical |
| 6 | /usr/local/bin/elden-ime-focusd | 74392（设备）/ 72240（副本） | pie, dyn, /lib/ld-linux-aarch64.so.1，链 glib/gio | **动态 glibc** | patches-userland/zh-ime/elden-ime-focusd.c | build/elden-ime-focusd.sh | diff |
| 7 | /usr/local/sbin/reboot2 | 709368（设备）/ 597920（副本） | static，PSCI SYSTEM_RESET2 | 静态 | rootfs/reboot2.c | build/reboot2.sh | diff |

历史「3 个无源」点名（10-25 报告 §B：WARN 3）→ 现状：

1. **ffrumble**（无源 → 2026-10-25 已按用法重写 `scripts/ffrumble.c`，dealpine-audit §5.1；上机 A/B 同命中数）。
2. **waydroid-sensord**（无 recipe → 已补 `patches-userland/waydroid-sensord-udp/` + 双 target recipe，PITFALLS #431）。
3. **waydroid-sensord-udp**（缺宿主交叉 recipe → 同上，宿主 arm64 chroot 产物与设备件 sha 一致）。

历史「动态 musl」澄清：10-25 时 3 个动态件（waydroid-sensord、waydroid-sensord-udp、elden-ime-focusd）
均为 **musl 动态**（interpreter /lib/ld-musl-aarch64.so.1，Alpine 根现役）。现行 recipe 的默认产物已改为
**glibc 动态**（/opt/elden/arm64-sid chroot 编出，其中 sensord 双件 sha256 22028ffd… 与设备件逐字一致）——
即「2 个动态 musl」在 Alpine 侧的身份随换根一并消解，Mobian 目标根只认 glibc 动态件。
注意 dealpine-audit §D（musl 动态解释器路径检查）与 coupling 检查仍保留，作为防 musl 件误搬 glibc 根的守卫。

## §2 逐个处置建议

结论先行：**7 个全部走「配方重编 + provenance 记账」，不需要任何重写**，也不需要
「设备侧现成二进制 + provenance 打包」的兜底路线（该路线仅对 #2/#3/#6/#7 的 diff 件在
「设备件与新编件行为存疑」时作为 A/B 参照保留，见 §4）。

1. **elden-hapticd**：静态单文件，配方产物 sha 与设备件逐字一致 ⇒ 闭环成立。
   最小处置：`sudo bash packaging/elden-userland/build/elden-hapticd.sh`，记产物 sha256 → 追加 provenance 行。无需设备。
2. **eldroid-sensord**：静态，diff（重编选项/版本漂移，非功能漂移，sources.tsv 头部口径）。
   处置：重编后与设备件 A/B（上机；如行为一致即在 artifacts.tsv note 记「diff 已验收」）。需设备验收。
3. **ffrumble**：静态重写件，diff。已做过上机 A/B（aw86927_haptics_play 2/2 同命中数，见 sources.tsv note）。
   处置：视为已闭环；只需把 A/B 证据指针写进 provenance。可选：重新跑一次 A/B 确认（待上机）。
4. **waydroid-sensord**：动态 glibc，identical ⇒ 设备现役件即本 recipe 产物，闭环最强。
   换根判据：重编出的 glibc 件 sha256=22028ffd9a53…。无需设备即可验证产物；上机验 Waydroid sensorservice 起活。
5. **waydroid-sensord-udp**：同 #4（同源双文件名），identical ⇒ 同上。
6. **elden-ime-focusd**：动态 glibc（glib/gio），diff。设备现役件也是 glibc 动态（recipe 头注：同一 chroot 编出），
   diff 源于 chroot 内包版本演进。处置：重编 + 上机验证输入法焦点行为（待上机）。
7. **reboot2**：静态，diff。PSCI SYSTEM_RESET2 行为只有上机可验（Linux→fastboot）。
   处置：重编 + 待上机做一次 reboot2 落 fastboot 验证；diff 记 provenance。

provenance 记账统一格式（建议追加到 `build/artifacts.tsv` 的 note 或新列，不新增文件）：
`sha256=<64hex> | built=<date> | recipe=<name>.sh | src=<files> | ab=<identical/diff+证据指针>`。

## §3 重建 recipe 草案（Mobian 换根后）

前置（宿主，一次性；本机已具备，换机时重做）：

```bash
# P0. arm64 glibc chroot（sensord 双件 + ime-focusd 共用）
sudo debootstrap --arch=arm64 --variant=minbase --include=ca-certificates sid \
     /opt/elden/arm64-sid https://mirrors.ustc.edu.cn/debian
# 判据: test -x /opt/elden/arm64-sid/bin/sh && ls /proc/sys/fs/binfmt_misc | grep -q qemu-aarch64
```

重建（全部有 --dry-run；判据写在每步后）：

```bash
cd /home/xuqianhui/y700-elden
# R1. 全量干跑（离线可做）
bash packaging/elden-userland/build/all.sh                # 判据: 7 个配方逐条打印命令、rc=0

# R2. 真跑 7 个配方（root 配方自动要 sudo；静态件 4 个无需 chroot）
bash packaging/elden-userland/build/all.sh --apply
# 判据 A: out/{hapticd,sensord,ffrumble,sensord-host,ime-host,reboot2}/ 下 7 个产物存在且 file 显示 aarch64
# 判据 B: sha256sum 对表 —— identical 预期: elden-hapticd(aca55cb1…)、waydroid-sensord/-udp(22028ffd…)
#         diff 允许: eldroid-sensord、ffrumble、elden-ime-focusd、reboot2（记 provenance，非功能漂移）

# R3. 门禁复核
bash packaging/elden-userland/tools/verify.sh --rebuildable
# 判据: elf=7 ok=7 missing=0 recipe=7 dry-run-ok=7；FAIL=0

# R4. 渲染两套 init 单元（换 init 不重写）
python3 packaging/elden-userland/tools/render.py
# 判据: out/units/{openrc,systemd}/ 与 services.tsv 条数一致，git diff 无意外漂移
```

部署到 Mobian 根（**待上机**，步骤：设备 SSH 可达后）：

```bash
# D1. rsync 7 个 ELF 到 Mobian 根（覆盖 /usr/local/{bin,sbin}）
# D2. rsync out/units/systemd/ → /usr/lib/systemd/system/，逐条 systemctl enable（按 services.tsv INIT 列）
# D3. 特别语义核对: qbootctl 在 multi-user（防 ~7 次重启卡 fastboot, #181）；greetd respawn（#318）；
#     iio-sensor-proxy 等 QRTR svc 400（G1-34）；wifi-scan-refresh <180s（#354）；hapticd amplitude=255
# D4. 上机跑根上 verify.sh（F 段设备在线自动比对）
bash packaging/elden-userland/tools/verify.sh
# 判据: FAIL=0；F 段根画像 sha 全绿

# D5. 功能验收（待上机）: reboot2→fastboot、马达 ffrumble/vibrate 命中数、waydroid sensorservice 起活、
#     输入法焦点、greetd 登录会话
```

设备依赖标注：P0/R1–R4 均可在无设备宿主完成（本轮已验证 R1/R3/R4 等效门禁绿）；D1–D5 待上机。

## §4 需要人决策的取舍

1. **diff=4 的验收口径**：eldroid-sensord / ffrumble / elden-ime-focusd / reboot2 重编后 sha 与设备件不一致。
   现行口径是「功能等价即可」；是否要求对 ffrumble（无原件源码、纯重写件）再做一轮上机 A/B 命中数回归？建议：做，成本低。
2. **是否保留 musl 备选分支**：waydroid-sensord.sh 的 `--target=musl` 分支本机无 Alpine chroot，从未真跑（dry-run only）。
   若 Mobian 换根已定案，可考虑删分支或保留为回退保险（保留不占运行成本，建议保留但在 tsv 注明 unproven）。
3. **diff 件的 provenance 记账位置**：写进 artifacts.tsv 扩列，还是单独 provenance 文件？建议前者（避免第 5 处散落）。
4. **设备二进制兜底是否成文**：verify 门禁已强制「无源=FAIL」，设备件兜底路线不应成为常态；建议在 README
   明确「设备件仅作 A/B 参照，不进 MANIFEST 正式位」。
5. **T14 结项判据**：建议定为「R1–R4 宿主全绿 + D1–D4 上机 FAIL=0 + D5 五项功能验收通过」，
   与 TASKS/README §7 对应 M 系列编号对齐（待人确认编号）。

