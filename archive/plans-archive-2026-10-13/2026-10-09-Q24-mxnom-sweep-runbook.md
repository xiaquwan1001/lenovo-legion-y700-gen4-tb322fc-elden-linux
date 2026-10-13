# Q24 熄屏×相机 ≥9 轮扫掠包（B，vk71-mxnom）——上机即执行 runbook

> 状态权威 `TASKS.md` Q24 / G1-22 / G1-33。本包 = `scripts/q24-mxnom-sweep.sh` + 本 runbook。
> 变体依据 `.pi/plans/2026-10-09-Q24-变体与G1-34资产.md` §1。**只读**（`fastboot boot` 零写盘）。

## 0. 一句话
每轮：跑 vk71-mxnom → 相机栈在位 → `ScreenSaver.SetActive true` 真实熄屏 → 长时窗 → 唤醒 → 相机探针计数 → 存活判定；
≥9 轮后按掉电次数对照基线判「mxnom 是否优于 H1/H2」。

## 1. 变体与单变量（`out/boot-elden-vk71-mxnom.manifest` 已核实）
| 项 | vk71-mxnom | 现役 H2（vk63，基线） |
|---|---|---|
| image_sha256 | `877eeba3…` | vk63 镜像 |
| kernel / ramdisk | `Image-vk47clean` / `initramfs-full-elden`（与 vk63 同） | 同 |
| DTB | `cambist-mxnom` `1da55c99…` = MX **corner=nom**(level256) | `cambist-h2` `386cc9bd…` = MX corner **low_svs** |
| cmdline | **无 `elden_nocamera=1`**（相机照常加载 + 真实熄屏） | vk63 亦无 |
⇒ **唯一变量 = cambist 的 MX corner：low_svs → nom**，检验「MX 轨在低 corner 塌陷」假设。

## 2. 每轮动作序列（脚本内已实现，等价手动手顺）
1. 保证当前跑 vk71-mxnom：`fastboot -s <探测> boot out/boot-elden-vk71-mxnom.img` → 等 SSH（`root@192.168.7.1`）可达。
2. 相机栈在位（幂等）：`sh /usr/local/sbin/camera-modules-load.sh`；探针 `lsmod|grep -c cambistmclkcc`、`ls /dev/media*|/dev/video*|wc -l`。
3. 真实熄屏：`gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true`。
4. 长时窗：默认 `BLANK_WAIT=90 s` 黑屏停留。
5. 唤醒：`SetActive false` + 2 s；`sentinel` 命令末 `echo ALIVE`。
6. 存活判定：`echo ALIVE` 的 ssh 命令**返回 ALIVE ⇒ 本轮存活**；不返回（超时）⇒ **掉电/硬复位**（pstore/kmsg 无痕，与 `sleep-sweep.sh` 同判据）。
7. 落 `logs/q24-sweep-<img>-<ts>/results.tsv`（round / verdict / cam_media / cam_video / cambist / uptime）。

## 3. 基线来源（对比基线 + 出处文件）
- **原厂证据（削弱「改 MXC」）**：`backup/stock-elden/dtb/10_…SunP_SoC.dtb` 反编译——cambistmclkcc **只有 `vdd_mx-supply`**（无 mm/mxc），故主线 H2 单挂 MX = 原厂写法（出处 `.pi/plans/2026-10-09-Q24-变体与G1-34资产.md` §1.1）。
- **行为基线（TASKS.md）**：H1（去 power-domains）**7/9 存活**；H2（vk63，单挂 MX low_svs）**3 轮 2 掉电 / 用户实机 2/2**（间歇 ~2/3，样本小）；D1 6/9、D2 7/9 无改善 ⇒ 驱动侧非主因。

## 4. ≥9 轮统计口径与回归判定（阈值）
> 因根因为**间歇**（H1 7/9、H2 ~2/3），单组 <9 样本无区分度 ⇒ 必须 **≥9 轮**（出处 Q24 plan §1.2）。
> 下列阈值含**研究者推断**（基于 9 次二项分布的可分性，非计划文档明写），需父进程/用户确认后再定稿。

- **未改善/回归复现**：`DEAD ≥ 3/9`（≥33% 掉电，与 H1 的 2/9≈22% 不区分、与 H2 同量级）⇒ mxnom 不优于 H2，回归未解。
- **改善信号（待加强样本）**：`DEAD ≤ 1/9`（≤11%）⇒ 优于 H1/H2，考虑把 MX corner=nom 合入续修方向，**并加到 ≥18 轮再确认**。
- **与 H1 同量级/不定**：`DEAD = 2/9` ⇒ 无法区分 H1，补样本。
- 统计口径：`survival = ALIVE/N`，NOBOOT（起不来，多为 Q28 面板失败）单独计数、**不计入掉电分子**、当轮重跑。

## 5. 纪律（同 A：冷启起步 / 失败态 `echo b > /proc/sysrq-trigger` 不用 `reboot -f` / `pkill -x` / 不写死序列号 / 走 SSH）
- Q28 面板失败会让某轮 NOBOOT：NOBOOT≠掉电，脚本自动重 `fastboot boot`，勿据此判掉电。
- 三组同口径交替跑（`IMG=out/boot-elden-vk71-mxc.img`、`IMG=out/boot-elden-vk63.img`、默认 mxnom），各 ≥9 轮，横比存活率。

## 6. 命令
```bash
scripts/q24-mxnom-sweep.sh 9                              # vk71-mxnom，9 轮，BLANK_WAIT=90
BLANK_WAIT=150 scripts/q24-mxnom-sweep.sh 12             # 更长时窗、更多样本
IMG=out/boot-elden-vk63.img      scripts/q24-mxnom-sweep.sh 9   # H2 对照
IMG=out/boot-elden-vk71-mxc.img  scripts/q24-mxnom-sweep.sh 9   # MXC 变体对照
```
产物：`scripts/q24-mxnom-sweep.sh`、`logs/q24-sweep-*`；依据 `.pi/plans/2026-10-09-Q24-变体与G1-34资产.md`、`TASKS.md` Q24/G1-33。
