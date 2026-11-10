# T14 用户态服务独立固化 —— 重建性收尾（A4，2026-11-04）

> 范围：**纯主机**。未上机、未用 adb/fastboot/ssh、未动 vendor.img、未 commit（由编排者统一提交）。
> 证据写法：`file:line` 或命令 + 输出摘要。凡无命令支撑的一律标 **未证**。
> 落盘清单：`packaging/elden-userland/build/`（新目录，7 配方 + `artifacts.tsv` + `README.md`）、
> `packaging/elden-userland/tools/verify.sh`（新增 `--rebuildable` / `--rebuild` 两段，**A–G 判据一字未改**）、本文件。

## 0. 一句话结论

**任务书的现状前提已过时**：7 个 ELF 现在**全部可重建**（`ok=7 missing=0`），
「4 ok / 3 missing」是 `reports/userland-service-inventory-20261025.md:122` 的快照，
而两个缺口在**同一天**的提交 `0e60a55`（2026-10-25「补齐两个构建缺口」）里已补。

所以本轮真正缺的不是"补源/补 recipe"，而是**「可重建」的判据太弱**：
`verify.sh` 的 B 段只检查**源文件路径是否存在**（`tools/verify.sh:183-209`），
既没验证 recipe 能否被执行/演练，也没有一个可复现的数字。
本轮把它升级为：**配方零写盘可演练（`--dry-run`）+ 门禁出数字（`--rebuildable`）+ 真编比 sha（`--rebuild`）**。

现状数字（本轮生成，可复跑）：

```console
$ bash packaging/elden-userland/tools/verify.sh --rebuildable | tail -4
  ELF 共 7 个：ok=7 missing=0；配方 7 个可 --dry-run；产物 sha 与清单 identical=3 diff=3
==== rebuildable: elf=7 ok=7 missing=0 recipe=7 dry-run-ok=7 identical=3 ====
==== verify --rebuildable: FAIL=0 WARN=0 ====
```

## 1. 现状核对（7 个 ELF 逐一定性）

真源：`MANIFEST.tsv`（设备 sha/size）+ `sources.tsv:10-16`（build/source/status）+ 本轮实编。

| # | ELF（dst） | 定性 | 源（`sources.tsv` 行） | 本轮实测产物 vs 清单 |
|---|---|---|---|---|
| 1 | `/usr/local/bin/elden-hapticd` | **可重建（逐字一致）** | `sources.tsv:10` → `scripts/elden-hapticd.c` | `out/hapticd/elden-hapticd` sha256 `aca55cb1…` == 清单 `aca55cb1…`（729 312 B） |
| 2 | `/usr/local/bin/eldroid-sensord` | **可重建（功能等价，sha 不同）** | `sources.tsv:11` → `scripts/eldroid-sensord.c` | 重建 `8d338716…`/663 536 B vs 清单 `a1a457b2…`/778 944 B（设备件 musl 静态，宿主 glibc 静态） |
| 3 | `/usr/local/bin/ffrumble` | **可重建（源已重写，非原件）** | `sources.tsv:12` → `scripts/ffrumble.c`（117 行） | 重建 `28a20d11…`/597 920 B vs 清单 `cdff41ab…`/775 544 B |
| 4 | `/usr/local/bin/waydroid-sensord` | **可重建（逐字一致）** | `sources.tsv:13` → `patches-userland/waydroid-sensord-udp/`（chroot make） | `out/sensord-host/waydroid-sensord` `22028ffd…` == 清单 `22028ffd…`（266 200 B） |
| 5 | `/usr/local/bin/waydroid-sensord-udp` | **可重建（同一产物，逐字一致）** | `sources.tsv:14` → 同上（`Makefile`） | 与 #4 **同一文件两份名字**，清单也是一种 sha |
| 6 | `/usr/local/bin/elden-ime-focusd` | **可重建（sha 不同）** | `sources.tsv:15` → `patches-userland/zh-ime/elden-ime-focusd.c` | 现有产物 `7b8b0b46…`/72 240 B vs 清单 `d2304827…`/74 392 B |
| 7 | `/usr/local/sbin/reboot2` | **可重建（recipe 本轮才固化）** | `sources.tsv:16` → `rootfs/reboot2.c` | 重建 `ef12c5ba…`/597 920 B vs 清单 `0c68ee5f…`/709 368 B |

命令与判据（可逐条复跑）：

```console
$ bash packaging/elden-userland/tools/verify.sh --rebuildable     # 静态判据：源/入口/配方 dry-run
$ bash packaging/elden-userland/tools/verify.sh --rebuild         # 真编 4 个静态交叉件并比 sha
[H2] ok elden-hapticd: 重建产物与 MANIFEST 逐字一致（aca55cb143fd0506…）
[H2] WARN ffrumble / eldroid-sensord / reboot2: sha 与清单不同 ⇒ 功能等价口径
```

逐条"为什么 sha 会不同"（都是同一类原因，不是漂移）：

- **#2 #3 #7**：设备原件是 **musl 静态 / 另一版 strip-s 组合**，宿主编译器是 `aarch64-linux-gnu-gcc`
  （glibc 静态）⇒ 体积与字节必然不同。`sources.tsv:9` 已写明该口径（"sha 漂移 ≠ 功能漂移"）。
- **#6**：`sources.tsv:15` 的 note 自己就写着宿主产物 `7b8b0b46…`；清单记的是设备上那一版。
- **#3 额外一条**：原件源码**从未入库**（`packaging/elden-userland/sources/ffrumble/README.md:5-9`），
  仓内是 2026-10-25 按用法重写的最小实现 ⇒ 永远不可能与原件逐字相同，只能"接口/行为等价"。

**缺口期证据（说明任务书前提的确切时点）**：

```console
$ sed -n '53,58p' reports/userland-service-inventory-20261025.md   # 3 个 missing 的原始记录
| `ffrumble` | **静态** | ❌ **无源** |
| `waydroid-sensord` | 动态 **musl** | ❌ 无 recipe |
| `waydroid-sensord-udp` | 动态 **musl** | ⚠️ 有 Makefile，缺宿主交叉 recipe |
$ git log --format='%h %ad %s' --date=short -1 -- scripts/build-ffrumble.sh
0e60a55 2026-10-25 feat(migration): G0 达成（fstype 自动探测零写盘上机）+ 补齐两个构建缺口
```

⇒ 同一天的 `0e60a55` 就是补齐提交；两份 `reports/*2026102*` 早于它。`TASKS/README.md:123`
（"7 个 ELF 里 3 个无源"）同样需要随本轮更新 —— 那行是编排者的 SSOT，本任务**不改**，留给下一步。

## 2. ffrumble：不需要重写，需要"可演练 + 可验收"

任务书假设"无源 ⇒ 给重写方案"。实测**源已在**，而且是**已经重写并上机 A/B 过**的那一版：

| 事项 | 事实 | 证据 |
|---|---|---|
| 源码 | `scripts/ffrumble.c`，117 行，MIT | `wc -l scripts/ffrumble.c` |
| 接口面（它向外部暴露什么） | **不是服务**：`services.tsv`/`provides.tsv`/`deps.tsv` 均无 ffrumble 行（`grep -nE 'ffrumble' packaging/elden-userland/{services,provides,deps}.tsv` ⇒ 空）⇒ 它是**一次性 CLI 阳性对照**，无 unit、无 manifest 安装点 | 同上命令 |
| CLI 契约 | `ffrumble [dev] [ms] [magnitude]`；默认 `/dev/input/event2 600 0xffff`；`ms` 走十进制（`atoi` 行为），`magnitude` 支持 `0x`；输出行 `rumble ON id=%d dev=%s mag=0x%x %dms` | `scripts/ffrumble.c:1-24`（头注释）、`packaging/elden-userland/sources/ffrumble/README.md:10-24` |
| ioctl 面 | `EVIOCGBIT(EV_FF)` 探测 → `EVIOCSFF` 上传 `FF_RUMBLE` → 两次 `write(EV_FF)` 起/停 → `EVIOCRMFF` | 同上 README §"反汇编要点" |
| 上机验收（已做） | vk152：原件与重写版 `aw86927_haptics_play` 均 2/2 | `sources.tsv:12` note |

**本轮新增**：`packaging/elden-userland/build/ffrumble.sh`（配方，`--dry-run` 只打印），
验收判据复用现有 `packaging/elden-userland/sources/ffrumble/check-abi.sh`（只读）：

```console
$ bash packaging/elden-userland/build/ffrumble.sh --dry-run
+ bash /home/xuqianhui/y700-elden/scripts/build-ffrumble.sh
$ bash packaging/elden-userland/sources/ffrumble/check-abi.sh out/ffrumble/ffrumble
  ok arch=aarch64 / ok 静态链接 / SKIP 行为探针（离线无 /dev/input/event2）/ ok 三个用法字符串
```

**verify.sh 要比对的"字节/符号"到底该是什么**（明确写清，避免下一步又去追 sha）：

1. **不可比对**：整个 ELF 的 sha256（原件源码不存在，逐字相同不可能）⇒ 不要往 MANIFEST 里写"应该 identical"。
2. **可自动比对（已实现）**：`file` 判据 `ARM aarch64` + `statically linked`；`strings` 判据
   `rumble ON id=` / `bad duration` / `bad magnitude` 三个字面串 —— 全在 `check-abi.sh` 里。
3. **需要设备才能比对的（离线跳过，别在 CI 里假装通过）**：`strace` 观测 `0x40302a0c`(EVIOCSFF) 与
   `write(fd, "\x15...", …)` 的 payload。`check-abi.sh:21-27` 已按"无 strace/无 event 节点 ⇒ SKIP"处理。

## 3. 两个 `waydroid-sensord*`：宿主侧可复现配方（musl/glibc 取舍）

**源与实情**：`patches-userland/waydroid-sensord-udp/` 是完整的（`Makefile:1-27` + 7 个源文件，
上游 `service.cpp`/`Sensors.cpp` GPL-3.0 未改，`SensorFW.{h,cpp}` 自写 UDP 数据源）。
`MANIFEST.tsv` 里两个名字**同一份 sha `22028ffd…`** ⇒ 一个 ELF、两个安装名。

**为什么必须有"两套"（这是唯一需要判断的地方）**：

| 目标根 | interpreter | 谁产 | 状态 |
|---|---|---|---|
| glibc（Debian / Mobian 目标） | `/lib/ld-linux-aarch64.so.1` | arm64 **Debian sid** chroot `make` | ✅ 已产且**与 MANIFEST 逐字一致**（`22028ffd…`），`out/sensord-host/` |
| musl（Alpine 时代 / 回退根） | `/lib/ld-musl-aarch64.so.1` | arm64 **Alpine** chroot `make` | ⚠️ **未证**：本机无 Alpine chroot（`ls /opt/elden/arm64-alpine` 不存在），配方只给 dry-run 命令 |

**换根必须重编，没有替代方案**（`PITFALLS/README.md:146` #431、`scripts/deploy-sensord-routec-debian.sh:5-13`）：
Waydroid 的 `container_manager.py`/`images.py` 只按**文件存在**判定"宿主有 HAL"，musl 件搬到 glibc 根上
`which` 仍命中但 `exec` ENOENT（报错文案不提 loader）⇒ `ISensors` 无人注册 ⇒ **Android 卡 bootanimation**。

**配方**：`packaging/elden-userland/build/waydroid-sensord.sh`（`waydroid-sensord-udp.sh` 是同源入口）
= `scripts/host-arm64-chroot.sh --build-sensord` 的可演练版，五步全部显式（chroot 建/装依赖/拷源/make/取回）：

```console
$ bash packaging/elden-userland/build/waydroid-sensord.sh --dry-run          # 零写盘，只打印
$ sudo bash packaging/elden-userland/build/waydroid-sensord.sh               # 真跑（glibc，默认）
$ bash packaging/elden-userland/build/waydroid-sensord.sh --target=musl --dry-run   # 备选分支（未证）
```

**为什么不用静态链接 / musl-cross-make**：上游 `Makefile:14-16` 用 `pkg-config` 找
`glib-2.0 gio-2.0 gio-unix-2.0 libglibutil libgbinder` 的 `.pc`，静态交叉链没有这两套 `.pc`；
改 Makefile 超出 T14 范围（会牵动上游 GPL 文件）。

**本轮未证（诚实记录）**：
- `--target=glibc` 的**现场重跑**未证 —— `sudo -n true` 返回 `sudo: interactive authentication is required`
  （本机需交互密码；硬性规则 2：不反复试密码）。可用的替代证据链 = ①`/opt/elden/arm64-sid` 存在且
  `usr/include/gbinder/gbinder.h` 在位、`usr/bin/g++` 在位；②现有产物 sha **等于** MANIFEST 清单值，
  即"这条 recipe 的产物就是设备现役件"。
- `--target=musl` 全分支未证（无 Alpine chroot）。

## 4. 门禁：把"4 ok / 3 missing"变成可复现数字

**改动 = 只加不改**：`tools/verify.sh` 新增两段（H / H2）+ 两个开关；A–G 段一字未动，
默认路径行为完全不变（本轮实测 `--offline` 仍 `FAIL=0 WARN=0`，且 stdout 里不含 `[H.`）。

| 开关 | 行为 | 写盘 |
|---|---|---|
| `--rebuildable` | 只跑 H：遍历 `build/artifacts.tsv` 的 7 行，判 ①MANIFEST 有 elf 行 ②`sources.tsv` status=ok ③source 全部存在 ④build 入口存在（`bash X` 看 X，裸命令看 PATH）⑤recipe 存在且 `--dry-run` rc=0 且有 `+` 输出 ⑥产物 sha 与清单 identical/diff/absent（仅参考） | **零写盘** |
| `--rebuild` | H + H2：真编 `ffrumble/elden-hapticd/eldroid-sensord/reboot2`（不碰 chroot/root 配方）并比 sha，差异记 WARN | 只写仓库 `out/`（`.gitignore:29`） |

机器可读稳定行（供 CI/编排者 grep）：

```console
==== rebuildable: elf=7 ok=7 missing=0 recipe=7 dry-run-ok=7 identical=3 ====
```

负向自测（证明这条判据会红，不是永远绿）：把任一 recipe 改名/去掉 `--dry-run` 分支即应 FAIL：

```console
$ mv packaging/elden-userland/build/ffrumble.sh /tmp/ && bash packaging/elden-userland/tools/verify.sh --rebuildable | grep -E 'FAIL|rebuildable:'
  FAIL  /usr/local/bin/ffrumble: 配方缺失 build/ffrumble.sh
==== rebuildable: elf=7 ok=6 missing=1 recipe=6 dry-run-ok=6 identical=3 ====
  == verify --rebuildable: FAIL=1 WARN=0 ==
$ mv /tmp/ffrumble.sh packaging/elden-userland/build/      # 复原 ⇒ 立刻回到 ok=7（本轮实测）
```

## 5. 仍然存在的口径风险（本轮不解决，留给下一步判断）

1. **"可重建"不含"可复现字节"**：3 个 identical / 3 个 diff + 1 个 absent 的混合，随时有人误读成"漂移"。
   已写进 `build/README.md` 表格与 `sources.tsv:9` 口径，但 `TASKS/README.md:123` 与
   `reports/userland-service-inventory-20261025.md:122` 两处**旧数字**仍在（本任务不改 SSOT 文档）。
2. **构建环境未钉版本**：chroot 是 `sid` + USTC 镜像，`g++`/`libgbinder` 一升级就可能改 sha。
   要真正"任何一台主机可重出同一字节"，需要给 `apt` 做快照 pin（未证方案，本轮未做）。
3. **musl 变体缺失** ⇒ 现在**无法**在 Alpine 根上重建 HAL；Alpine 回退路线是断的（只有设备旧件）。
4. `out/stage-debian`（F 段 overlay 真值源）里有与 `files/` 同名同 sha 的副本（实测
   `ssc-udp-relay.py` 两侧同为 `01d20f24…`）⇒ 不是重复资产、也不是漂移，但容易被误读；非本轮范围。

## 6. 给下一步的最小动作清单（≤5 条）

```bash
# 1. 提交本轮（编排者统一做；只含 build/ + verify.sh + 本文件）
git add packaging/elden-userland/build packaging/elden-userland/tools/verify.sh .pi/plans/next/t14-rebuild.md
# 2. 把 SSOT 里的旧数字改掉（1 行）：TASKS/README.md:123 "7 个 ELF 里 3 个无源" → "7/7 可重建；3 个 identical"
sed -n '123p' TASKS/README.md
# 3. 门禁接进日常：任何改 sources.tsv/MANIFEST 的提交都跑这条（零写盘，秒级）
bash packaging/elden-userland/tools/verify.sh --rebuildable
# 4. 补 musl 分支（唯一真缺口）：建 Alpine aarch64 chroot 后删掉本文件 §3 的"未证"
sudo apk --root /opt/elden/arm64-alpine --arch aarch64 --initdb --no-cache add alpine-base   # 需 root，本轮未做
# 5. 可选：把 chroot 依赖做 apt 快照 pin，让 identical 项从"当前时点"升级为"任意时点"
grep -n 'deb ' /opt/elden/arm64-sid/etc/apt/sources.list   # 目前无 snapshot.debian.org 钉版本
```

DONE-T14
