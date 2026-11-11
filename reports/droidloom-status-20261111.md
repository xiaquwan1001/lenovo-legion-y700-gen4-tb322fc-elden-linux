# droidloom 现状与下一步（2026-11-11 盘点）

- 日期：2026-11-11
- 范围：`build/droidloom/`（上游工作树，只读）、`reports/droidloom-l2-phoc-syncobj-20261111.md`、
  `TASKS/sessions/2026-11-10-Waydroid网络定案与droidloom复评.md`、`TASKS/README.md` C12/Q3/R3 行。
- 纪律：只读代码/文档，未改版本账、未动设备、未 git 写操作。
- 状态：**进行中**（分节落盘，见下）。

## 1. droidloom 是什么 + L1/L2/L3 分级

### 1.1 是什么（引原文）

上游 `build/droidloom/droidloom/README.md:3-5`（原文）：

> "Droidloom runs Android apps in separate Linux Wayland windows. It uses a shared
> kernel Android userspace with real Android APIs, GPU acceleration and a native
> desktop application catalog."

即：**共享内核（shared-kernel / 非 VM、非容器隔离）** 的 Android 用户态，应用直接出成宿主桌面的
独立 Wayland 窗口。裸机形态介于「Wayland 容器（Waydroid）」与「VM」之间——不要 Android 宿主、
不要整机 Android 镜像启动，但需要一整套 Android 用户态分区。

仓库布局（`README.md:76-84`）：`runtime/`（supervisor、CLI、应用目录）、`graphics/`（Wayland presenter、
输入、Composer、私有宿主传输）、`android/`（Android 组件与补丁、钉住的上游输入）、`packaging/`（pacman 元数据、
service units）、`tools/`（包构建器、源码更新器）。

本仓里的 `build/droidloom/droidloom` 是**上游工作树快照，不含 Makefile**：
建法在 `README.md:46-52` —— 一条 Rust 命令 `cargo run --locked -j 1 -p droidloom-package -- build`
（构建过程不在本文范围，本轮未重编）。

### 1.2 L1/L2/L3 分级定义（出处：`reports/droidloom-feasibility-20261110.md:180-183` 表）

| 级 | 动作 | 判据（原文） |
|---|---|---|
| L1 | 内核加 nftables 片段 → 零写盘 `fastboot boot` | 「设备上 `nft list ruleset` 返回空而不报错；doctor `kernel.network_isolation` PASS」 |
| L2 | phoc 补一行 `wlr_linux_drm_syncobj_manager_v1_create()` 并换二进制 | 「`wayland-info` 出现 `wp_linux_drm_syncobj_manager_v1`；`droidloom-wayland` 不再 bind 失败」 |
| L3 | 下 `droidloom-image-0.1.0-30-aarch64`（0.90 GiB）+ 起 cell | 「`droidloomctl start` 后 `droidloomctl applications` 列出 Android 应用」 |
| L4 | 一个 App 真开 | 「独立 Wayland 窗口 + 触摸/键盘」 |

（`TASKS/README.md:90` C12 行的「判据」列与此一致，L4 即该行 L4 判据。）

### 1.3 当前做到哪一档

**L1 = 完成；L2 = 完成（上机全绿）；L3 = 结构性阻塞；L4 = 未开始。**

- **L1 完成**：`out/boot-elden-vk187b.img`，零写盘 `fastboot boot` 一发全绿 ——
  `nft list ruleset` rc=0、`nft add/del table` OK、`droidloom-doctor` **`ready=True blockers=0`**
  （`TASKS/README.md:90` C12 行「★2026-11-10 上机实做」段；同日会话记录
  `TASKS/sessions/2026-11-10-Waydroid网络定案与droidloom复评.md` 追加 2 §A）。
- **L2 完成（2026-11-11 上机）**：设备在版 phoc 是 **0.58.0**（不是报告 §3 推定的 0.55.1），按 0.58.0 重编
  → `out/phoc-syncobj-arm64-20261111/phoc-0.58.0-syncobj`，`install` + `systemctl restart greetd` 后：
  ① `wayland-info` = **57 个全局**含 `wp_linux_drm_syncobj_manager_v1` v1（name 45）；
  ② `droidloom-wayland` **0 次 bind failure**、进入 `session mode: desktop`
  （`reports/droidloom-l2-phoc-syncobj-20261111.md` §9）。
- **L3 阻塞**：`droidloomd` 起 cell 时被 rootfs 属主契约拒绝（见 §3.1）。

## 2. 已关闭门禁与仍开着的门禁

### 2.1 已关闭（有实测证据）

| 门禁 | 关闭方式 / 证据 |
|---|---|
| `kernel.network_isolation`（`CONFIG_NF_TABLES`） | vk187b 零写盘上机，`nft list ruleset` rc=0；doctor `ready=True blockers=0`（`TASKS/README.md:90`） |
| `identity.subordinate_ids`（subuid 100000 契约） | `usermod --add-subuids 300000-399999 --add-subgids 300000-399999 xuqianhui1001`（L0，`reports/droidloom-feasibility-20261110.md:180` 上方 L0 行标「已完成」） |
| 合成器 `wp_linux_drm_syncobj_manager_v1` 全局 | phoc 0.58.0 + 补丁上机，`wayland-info` 57 全局含该 v1（`reports/droidloom-l2-phoc-syncobj-20261111.md` §9 判据一 + `reports/artifacts/droidloom-l2-phoc-20261111/device-wayland-info-with-syncobj.txt`） |
| presenter 全局绑定 | `droidloom-wayland` 0 次 bind failure，`session mode: desktop`，clipboard=`ext-data-control`（`.../device-droidloom-wayland-bind.log`） |
| 图形前置「必须先编 phoc」这一假设 | 被 headless sway A/B 推翻：`apt install sway` 即可验证（`reports/droidloom-feasibility-20261110.md:265-283` §8.3） |
| 「需自构建 aarch64」这一假设 | 上游自修订 27 起有 aarch64 包（`reports/droidloom-feasibility-20261108.md`，`TASKS/README.md:1065` Q3 行「仍无发布包已不成立」） |

### 2.2 仍开着

| 门禁 | 现状 | 性质 |
|---|---|---|
| **L3 起 cell：`host_storage::check_parent()` 祖先属主** | `unsafe Android storage parent: /var/lib/droidloom/users/1001/data` | **结构性**（§3.1） |
| **`droidloom-package-helper prepare`（`/etc` 契约）** | 要求 `/etc` 为 `root:root` + `0755`，本机不符 ⇒ setup 只能手工铺 | 结构性（同族） |
| GApps | 无本地 `LiteGapps-arm64-17.0.zip`，`droidloom-gapps inspect/build` 未跑 | 未做 |
| msm_dpu 显式同步长时稳定性 | 熄屏唤醒 / 长时间 page-flip 未测 | **未取证，不得当结论** |
| 音频 / 相机 / 传感器 | 完全未测（上游自述 non-preview） | 未做 |
| L4 一个 App 真开窗口 | 未开始 | 未做 |
| PI / Widevine | 上游 `threat-model-v2.md` 明文免责 | **天花板，非门禁**（见 §5） |

## 3. 卡点根因

### 3.1 唯一的硬卡点：`host_storage::check_parent()` 的「祖先目录属主契约」（结构性）

源码（`build/droidloom/droidloom/runtime/droidloom-supervisor/src/host_storage.rs:15-27`）：

```rust
pub(crate) fn check_parent(parent: &Path) -> io::Result<()> {
    // Ancestors must prevent the desktop user from replacing any mount source.
    for path in parent.ancestors() {
        let m = fs::symlink_metadata(path)?;
        if !m.is_dir() || m.uid() != 0 || m.mode() & 0o022 != 0 {
            return Err(invalid(format!("unsafe Android storage parent: {}", path.display())));
        }
    }
```

- 要求：`data_dir` **全部祖先** `uid == 0` 且 `mode & 0o022 == 0`（不得 group/other 可写）。
- 本机不符：`/`、`/etc`、`/usr`、`/var` 是 **`1000:1000` + `0775`**（Mobian/Alpine 迁移遗留，非
  Debian 标准）⇒ 报 `unsafe Android storage parent: /var/lib/droidloom/users/1001/data`。
- **定性：这是安全设计而非 bug** —— 注释原文「Ancestors must prevent the desktop user from replacing
  any mount source.」即：桌面用户可写的祖先目录能被拿来替换 bind-mount 源，等价于对 Android 侧的提权。
  所以**不应**为了跑通而放宽契约；修 `/` `/etc` `/usr` `/var` 的属主会波及全系统（`PITFALLS #608`，
  `PITFALLS/README.md:302`）。
- 调用点：`host_storage.rs:48`、`:69`，以及 `storage_migration.rs:52/:54`（迁移路径同一契约）。

### 3.2 同族根因：`droidloom-package-helper prepare` 的 `/etc` 契约

同一族要求（`/etc` 必须 `root:root` + `0755`）⇒ 官方 setup 流程（走 `pkexec`）在本 rootfs 直接拒，
只能手工铺 `/etc/droidloom/{cell.json,runtime.env,package-state.json}` + polkit 规则 + user units
（`TASKS/sessions/2026-11-10-Waydroid网络定案与droidloom复评.md` 追加 2 §B）。

### 3.3 nftables —— **已不是卡点**（历史上是）

`DevelopmentNetwork::setup_rules()` 用 `nft -f -` 单事务同时建 filter/nat 两表
（`build/droidloom/droidloom/runtime/droidloom-supervisor/src/development_network.rs:150-180`），
全成或全败；现役内核缺 `CONFIG_NF_TABLES` 时直接 `Err` ⇒ 起不了 cell。vk187b 上机后已通，
doctor 判据在 `runtime/droidloom-doctor/src/lib.rs:600-620`（`CONFIG_VETH && CONFIG_NF_TABLES`）。

### 3.4 历史卡点（已解，仅存档）

- 合成器少一行 `wlr_linux_drm_syncobj_manager_v1_create()`：phoc 全树（含 0.59.rc1）0 命中 ⇒ 补一行即解
  （`PITFALLS #604`、`#609`）。
- `LOCALVERSION` 改后模块树失配 ⇒ 无 `/dev/dri` ⇒ 伪装成「GPU 坏了」（`PITFALLS #607`）。

## 4. 下一步可立即执行的动作

按「不破现有系统、不靠 rootfs 重做」原则排序。**注意：三条都不依赖改 `/` `/etc` `/usr` `/var` 属主。**

### A1（最高优先，零风险闭合 L2 的未取证项）：盯 msm_dpu 显式同步的长时稳定性

- **为什么**：L2 已上机全绿，但显式同步把 page-flip 推进 wlroots 的 timeline 分支，msm_dpu 上**零先例**
  （`reports/droidloom-l2-phoc-syncobj-20261111.md` §4 第 1 条原文：「本机零先例 ⇒ 上机后要盯卡顿/花屏/suspend-resume」）。
  这条不验，「L2 已收口」就是带尾巴的。
- **判据（三条同时成立才算过）**：① 连续 30 min 交互 + 2 次 `systemctl suspend`/唤醒后 `dmesg | grep -iE 'dpu|atomic|flip|timeout'` 无新报错；
  ② 无花屏（`grim` 前后截屏比对，不靠目视）；③ `wayland-info | grep syncobj` 仍为 v1。失败即回退到 `phoc.orig-0.58.0`。
- **命令/指针**：回退步骤在 `out/phoc-syncobj-arm64-20261111/MANIFEST.md`「回退」段；
  现有判据样例在 `reports/artifacts/droidloom-l2-phoc-20261111/device-wayland-info-with-syncobj.txt`。

### A2（决定 L3 是否可能：一次 5 分钟静态判定，不上机）

- **为什么**：L3 的卡点是 `check_parent()` 遍历 **`data_dir` 的全部祖先直到 `/`**
  （`host_storage.rs:15-17` `parent.ancestors()`）⇒ **在本 rootfs 上把 `data_dir` 改到任何路径都不可能绕过**。
  所以「换个 `data_dir` 就行」是伪出路，必须先把所有可行通路收敛完，再决定 C12 是 「就此收口」还是「立项 rootfs 重做」。
- **判据**：在一份根树清单上逐路径比对 `uid==0 && mode&0o022==0`，得出「存在整条链合规的祖先路径」的真假；
  若为假 ⇒ **L3 在本 rootfs 上确实不可达**，写入 C12 并停止尝试（否则会反复重启）。
- **命令/脚本指针**（只读，设备上跑）：
  ```sh
  # 对候选 data_dir 逐祖先判定（设备上 / 只在根树，不写任何东西）
  for p in / /var /var/lib /var/lib/droidloom; do stat -c '%n %u:%g %a' "$p"; done
  # 判据 = 所有行列 uid=0 且 mode 中 group/other 写位为 0（即 %a 第二位和第三位不为 2/3/6/7）
  ```
  与上游要改的位置：`build/droidloom/droidloom/runtime/droidloom-supervisor/src/host_storage.rs:15-27`。
  现状事实（来自会话记录，设备侧）：`/`、`/etc`、`/usr`、`/var` = `1000:1000` + `0775`。

### A3（与 L3 解耦、可独立产生价值的唯一增量）：在 headless sway 下跑通 presenter + 记录真实接口缺口

- **为什么**：L4 「一个 App 真开窗口」需要一个能跑 Android 用户态的 cell（= L3，阻塞），但
  **presenter 侧已全部可验**（无 cell 也能起，`TASKS/...复评.md` §8.2 实证）。这条路能把「除 rootfs 契约外
  是否还有其他缺口」一次性排除，且**零内核改动、零写槽、不影响 Phosh**。
- **判据**：headless sway 下 `droidloom-wayland` 起来后 `session mode: desktop`、clipboard=`ext-data-control`、
  **0 次** `bind failure`，并且 `droidloomctl applications` 的失败信息是**存储路径/缺 cell**（预期），
  而不是缺 Wayland 全局或缺 DRM 节点。
- **命令指针**：起点照 `reports/droidloom-feasibility-20261110.md:236-250` §8.1 的 headless sway 片段；
  客户端跑法照 `out/phoc-syncobj-arm64-20261111/MANIFEST.md` 第 3 条判据命令。

### 不建议做的（列明以免重复踩）

- ✗ 改 `/` `/etc` `/usr` `/var` 属主为 `root:root 0755` —— 全系统波及，风险选大于隔离试验收益（`PITFALLS #608`）。
- ✗ 装 `phoc-0.55.1` 产物上机 —— 跨两代降级（`PITFALLS #612`、`MANIFEST.md` 「附」段）。
- ✗ 用 `nft` 以外的方式绕 `development_network.rs` —— 上游单事务强制，改它就是 fork。

## 5. 与 C12 / phoc 同步对象那条线的关系

**一句话**：C12 就是 droidloom 隔离试验本身的项目编号（`TASKS/README.md:90`），而 phoc 同步对象那条线
（L2）是 C12 的**图形前置门禁**：它已从「待做」变为「已上机全绿」（`wayland-info` 57 全局含
`wp_linux_drm_syncobj_manager_v1` v1 + presenter 0 bind failure），因此 C12 现在的唯一剩余门禁是 **L3 的 rootfs
属主契约**，而 L2 的产出（`out/phoc-syncobj-arm64-20261111/phoc-0.58.0-syncobj`）**已经就位并部署在设备上**。
**C12 已计入 G2 分母（13 项）**，当前 G2 = **8/13**（`TASKS/README.md:16`、`:24`）。

## 结论

1. **droidloom 现状：L1 ✓ / L2 ✓ / L3 ✗（结构性）/ L4 未开始**。两档都有上机实测判据，不是推理。
2. **卡点只剩一个**：`host_storage::check_parent()` 要求 `data_dir` **全部祖先** `uid==0 && mode&0o022==0`，
   而本 rootfs 的 `/` `1000:1000 0775` ⇒ **改 `data_dir` 也无法绕过**，只能等 rootfs 重做或在独立 rootfs 里跑。
   这是上游的**安全设计**（防桌面用户替换 bind-mount 源），不应放宽。
3. **可立即做的三件**：A1 盯 msm_dpu 显式同步长时稳定性（闭合 L2 尾巴）；A2 一次静态判定把「L3 是否真不可达」
   写成事实；A3 headless sway 下把 presenter 剩余缺口一次性排除。
4. **不建议为了 L3 动系统目录属主** —— 代价远大于隔离试验的收益。
5. **对 G2 无净增益**：PI/Widevine 上游明文免责（`threat-model-v2.md`），所以维持「不替换 Waydroid」。
   这也是 C12 定位为「隔离试验」而非「迁移目标」的原因。

## 未完成项（本轮 30 min 切片）

- 未上设备实跑 A1/A2/A3（本轮只读主机侧文件，无设备动作）。
- 未重编 `build/droidloom` 工作树（无 Makefile，入口是 `cargo run --locked -j 1 -p droidloom-package -- build`，
  未跑）；§1.1 的仓库结构判定来自 `README.md:76-84` 与目录清单，未做逐 crate 拓扑。
- 未核算 `cell-spec-arm64.json` 与手工铺的 `/etc/droidloom/cell.json` 是否逐字段等价（spec 见
  `build/droidloom/droidloom/packaging/cell-spec-arm64.json`，「`data_dir`」在 `:211` 为
  `/var/lib/droidloom/users/1001/host-storage`，**与会话记录里报错路径 `.../1001/data` 不同路径名** —— 此为待核点，
  但不影响结论，因为两者的祖先链同为 `/var/lib/droidloom/...`）。
- 未验证 msm_dpu timeline 分支的代码依据（wlroots `backend/drm` 未在本仓内）。
