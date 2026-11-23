# 原生（Linux 侧）输入法现状审计 + 上机前备料清单（2026-11-23）

> lane 类型：只读审计 + 写报告（零编译、零设备接触、零部署）。
> 读账：`reports/ime-rime-backend-20261123.md`（下称 Rb）、`reports/ime-osk-zh-matrix-20261122.md`（M）、
> `reports/ime-osk-zero-to-usable-20261121.md`（Z）、`reports/ime-osk-pop-20261111.md`（Pop）、
> `PITFALLS #615/#618/#709`、`TASKS §1 G1-37/G1-38` 与 §4.0 **D3** 行。
> 盘点基目录 = `patches-userland/zh-ime-rime-20261123/`（入库提交 `857047b3` + `c1ce6146`，经主会话 `git show --stat` 核实）。
> ⚠ 本 lane 无 shell：**sha256 清单由主会话代跑提供（前缀截断），本 lane 以 read 直读 4 个关键件复核了存在性与内容首部**；未独立重算 sha。

---

## 0. 一页结论

| # | 结论 | 依据 |
|---|---|---|
| 1 | **落盘件 14/14 全在盘，MISSING=0**（RIME A/B 源码 5 + 部署/验证 3 + haptic 3 + layout 2 + rime_api.h 1） | §1 |
| 2 | **现役可用面已不止"骨架"**：R1（pipe + pypinyin/CC-CEDICT helper）**11-21 已上机、用户实测可用**（热 15–21 ms）；A 案 librime 双件（守护+薄客户端）是**候选升级件，非现役件** | INDEX §0 11-21 两块、D3 行 |
| 3 | **A 案上机还差 4 步**（装运行库 → 拷 2 二进制+1 unit → gsettings → 起守护）；**B 案还差 3 大步**（接线补丁落文件 → 设备重编 osk-stub+divert → 验证）；**haptic/方向键**与 B 案同属"一次 osk-stub 重编批次" | §2 |
| 4 | **需设备窗口判据 = 10 条**（R1–R5 + H1–H3 + L1–L2，Rb §5），其中 R1–R5、H1–H3 共 8 条属"A 案+震动"批，L1–L2 必须与重编批同窗口 | §3 |
| 5 | **⚠ 1 处报告间矛盾未收口**：Rb §1.5 的部署配方写 `completion-mode "['always']"`，但 `PITFALLS #709` 实测 0.46 **无 `always`**（枚举 none/hint/manual），照抄会静默无效。**上机前必须把该行改为现役已验证组合**（11-21 实际落地 = OSK 菜单「Word completion」开关即 `manual`，配合 `Completers default=pipe` + Pipe.command） | §4 |
| 6 | **上游动向**：phosh-osk-stub 已改名 **stevia**（gitlab.gnome.org/World/Phosh/stevia），0.47→0.51.0（2025-11）→Debian 侧 0.53；pipe completer 仍是文档化特性（`Completers.Pipe.command`，默认 `cat`）；Debian 已开始"把 osk-stub 赶下系统"（phosh meta 包 Drop osk-stub）⇒ **0.46 基线的 A/B patch 是短命资产，升级窗口出现时须重验 pipe 语义** | §5 |

---

## 1. 落盘件盘点（patches-userland/zh-ime-rime-20261123/）

全部相对仓库根；sha256 为 64 位完整值（此处按来源排版取前 8 位前缀，完整值以 `sha256sum` 现算为准）。

| 文件 | sha256 前 8 | 在盘 | 角色 |
|---|---|---|---|
| `rime/rime-ipc.h` | `c53990b8` | ✅（read 直读复核） | A 案 IPC 协议（header-only） |
| `rime/librime-piped.c` | `1eb39ae9` | ✅ | A 案守护（poll + 增量喂键 + `--oneshot`/`--idle-exit`） |
| `rime/elden-rime-completer.c` | `6fb54bf3` | ✅ | A 案薄客户端（OSK 的 Pipe.command 指向它） |
| `rime/pos-completer-rime.c` | `8b910e5c` | ✅ | B 案 completer（语法级过） |
| `rime/pos-completer-rime.h` | `34e40678` | ✅ | B 案头 |
| `rime/elden-rime.service` | `c62f58c9` | ✅ | A 案 user unit（`WantedBy=default.target`，非 graphical-session） |
| `verify/include/rime_api.h` | `6eb56291` | ✅ | librime 1.16.1 原版头（编译用，免装 librime-dev） |
| `verify/aarch64/elden-rime-completer` | `cd8f7ffc` | ✅ | aarch64 静态薄客户端（已链接，可直接部署） |
| `verify/aarch64/librime-piped` | `b29e7dc0` | ✅ **（2026-11-23 补齐，A 案造件缺口已关）** | aarch64 动态守护：NEEDED = librime.so.1 + libc.so.6；对 Debian trixie `librime1t64 1.17.0` 链接（设备 `apt install librime1` 即得）；主机 qemu 用户态探针受本地环境怪癖限制未跑（静态件同法可跑），行为级验证归设备侧 R1 |
| `verify/ime-zh-rime-verify.sh` | `f59db81f` | ✅（read 直读复核） | 上机判据 R1–R6 自动化脚本（设备侧，`--apply`） |
| `haptic/0001-osk-stub-keypress-haptic-hook.patch` | `53b87057` | ✅（read 直读复核） | OSK 每键震动钩子（env 门，~12 行） |
| `haptic/README.md` | `e6d893c6` | ✅ | 部署/回退（divert+hold）+ drop-in 配方 |
| `haptic/haptic-verify-60s.sh` | `7caf18f1` | ✅ | H1–H3 三判据脚本 |
| `layout/0002-osk-stub-terminal-arrows.patch` | `4d642f7d` | ✅（read 直读复核） | terminal.json 方向键 + vk-driver Home/End 两行 |
| `layout/README.md` | `f553f046` | ✅ | 说明 |

**MISSING = 0。** 同族的**现役件**（不在上述目录、另账在盘）：
`packaging/elden-userland/files/usr/local/bin/elden-pinyin-completer`（✅ read 直读复核，H-a/v3，pipe helper）、
词库分片 `/usr/share/elden-pinyin/shards/`（由 `scripts/gen-pinyin-lexicon.py` 生成，0162dcfb）、
`scripts/deploy-zh-ime.sh`、`scripts/ime-candidates-check.sh`、`scripts/gen-pinyin-lexicon.py`（均在 `scripts/README.md` 346 入口索引内）。

**B 案缺口（唯一 MISSING 性质的项）**：`pos-completer-rime.c` 的**接线补丁本体**（`pos-completer-manager.c` / `src/meson.build` / gschema / gresource 四文件的 diff）**从未落成 patch 文件**，配方只写在其头注释里 —— 标 **MISSING（接线补丁未落盘）**。

---

## 2. A / B 双案「还差哪几步能上机」（精确到命令/文件）

### A 案（独立 rime 守护 + pipe completer）——差 4 步，全部 ssh 可做，~15 min 窗口

1. **改部署配方里的 gsettings 值**（见 §4 矛盾）：
   现役组合应为 `gsettings set sm.puri.phosh.osk completion-mode "['hint','manual']"`
   （或直接沿用 11-21 已上机路径：OSK 菜单开「Word completion」= `manual`），
   **不要照 Rb §1.5 写 `['always']`**。其余两键不变：
   `gsettings set sm.puri.phosh.osk.Completers default "pipe"`、
   `…Completers.Pipe command "/usr/local/bin/elden-rime-completer"`。
2. **设备装运行库 + 拷件**：
   `apt install librime1 librime-data`；
   `scp verify/aarch64/elden-rime-completer rime/librime-piped（需先链接出守护二进制，见第 3 步注） root@…:/usr/local/bin/`；
   `rime/elden-rime.service` → `/etc/systemd/user/`。
   ⚠ 注：~~`verify/aarch64/` 现只有**薄客户端**完整链接产物~~ **2026-11-23 已补齐**：`verify/aarch64/librime-piped`（sha256 `b29e7dc088418d33…`，trixie librime 1.17.0 arm64 链接 sysroot = `/tmp/rime-sysroot`，`-Wl,--allow-shlib-undefined`；A 案造件缺口关闭，§1 表新增行）
3. **起守护**：`systemctl --user daemon-reload && systemctl --user enable --now elden-rime`
   （首次启动有词库编译，数秒；`graphical-session.target` 在本栈 inactive，unit 故意挂 `default.target`，Z §0.3）。
4. **跑判据脚本**：`sh verify/ime-zh-rime-verify.sh`（设备侧，R1–R6 自动判）。

### B 案（patch 直连 librime）——差 3 大步，需设备重编窗口，与 haptic/方向键同批

1. **把接线补丁落成文件**（主机侧，1–2 h）：照 `pos-completer-rime.h` 头注释的配方，
   产出 `pos-completer-manager.c`、`src/meson.build`、`data/sm.puri.phosh.osk.gschema.xml`、gresource 四文件 diff，
   建议落 `patches-userland/zh-ime-rime-20261123/rime/0003-osk-stub-rime-completer-wiring.patch`。
2. **设备上重编 phosh-osk-stub 0.46**（需 `apt build-dep phosh-osk-stub` / `librime-dev`，15–25 min 编译）
   + **divert+hold**（`PITFALLS #654` 纪律，用 `scripts/phoc-install.sh` 同款流程）；
   **haptic `0001` 与 layout `0002` 与它同一重编批次**，一次 divert 打齐三件。
3. **回退预案**：divert 反做 + `apt-mark unhold`；A 案 gsettings 三键 `reset` 即回 hunspell。

---

## 3. 需设备窗口的判据条数（对照 Rb §5 的 10 条）

| 组 | 判据 | 窗口需求 |
|---|---|---|
| RIME A 案 | R1 主链（`echo nihao \| elden-rime-completer` 出「你好」）、R2 热启动 <100 ms、R3 端到端候选条、R4 点选上屏、R5 守护缺席静默退化 | 5 条，纯 ssh + 少量目视（R3/R4 要看屏），~15 min |
| 震动 | H1 ffrumble 基线、H2 每键 FF 事件、H3 幅度三档人手感标定 | 3 条（H1 应过，2026-11-20 已实测链路；H2/H3 需**重编批落地后**） |
| 方向键 | L1 terminal 布局 ← 光标左移、L2 ⇱/⇲ Home/End | 2 条，必须与重编批同窗口 |
| **合计** | **10 条**；其中不依赖重编批的只有 R1–R5（A 案）与 H1 = **6 条可先行**，H2/H3/L1/L2 = 4 条绑定 osk-stub 重编窗口 | |

---

## 4. 矛盾与风险（必须在上机前收口）

1. **`completion-mode` 值矛盾（高危，直接决定 A 案配置是否生效）**：
   Rb §1.5 / M §5.2 写 `['always']`（按新版本文档），`PITFALLS #709` 实测 0.46 枚举**只有 none/hint/manual**。
   上游 man 手册（0.38/0.46 代）确认合法值为 `off/manual/hint/manual+hint` 组合，无 `always`。
   **处置**：A 案部署配方改 `['hint','manual']`；若要"每键都喂"（`always` 语义）需 Rb 所述 1 行源码补丁加 ALWAYS，归入重编批。
2. **选中追加空格**：pipe 协议下点候选会提交 `你好 `（尾空格，`pos-input-surface.c:290`）——A 案无解、B 案可解；上机按 M R1-6 观察即可，不阻塞。
3. **A 案守护二进制未完整链接**（§2 第 2 步注）：`verify/aarch64/librime-piped.o` ≠ 可执行；上机前须先补一次链接，否则 R1 必败。
4. **守护单例与现役 helper 的关系**：`elden-pinyin-completer`（现役）与 `elden-rime-completer`（A 案）共用同一 GSettings 键 `Completers.Pipe.command` —— 切换即二选一，**切 A 案前先记下现役值以便回退**（回退 = 改回 `/usr/local/bin/elden-pinyin-completer`）。
5. **上游版本漂移**（§5）：0.46 基线的三个 patch 与 B 案接线在 Debian 换 stevia ≥0.51 时需重验/重打；**不要在升级窗口前投入 B 案重编**。

---

## 5. 上游动向（phosh-osk-stub / stevia，2026-11-23 现查）

- **项目已改名 stevia**：`gitlab.gnome.org/World/Phosh/phosh-osk-stub` → `World/Phosh/stevia`（"stevia (formerly phosh-osk-stub)"）；发版节奏 0.47.0 → 0.50.0/0.50.1（2025-10）→ 0.51~rc1/0.51.0（2025-11）→ Debian 侧 `phosh-osk-stevia 0.53.0-1`（Ubuntu 26.04 档案）。
- **pipe completer 仍是一等特性**：上游 README 明写 "use any program as completer via a `pipe` completer"；man 页（0.38–0.5x 代）文档化 `Completers.Pipe command`（默认 `cat`）、completers 家族 = hunspell/presage/pipe/fzf/varnam。A 案所依赖的协议面（stdin=preedit、stdout=逐行候选、空 stdout UB 语义见 `pos-completer-pipe.c`）没有收到不兼容改动的证据，但**0.46→0.5x 间 input-surface/completion-bar 有重构（Consolidate input surface creation MR !247 等）**，B 案补丁必须对新树重对行号。
- **Debian 侧在主动替换**：DebianOnMobile `phosh: Drop osk-stub`（MR !131）、`phrog: Use stevia instead of osk-stub`（MR !10）、stevia 包描述自述 "This allows us to force phosh-osk-stub off the system"。⇒ 现役 trixie 的 `phosh-osk-stub 0.46.0-1` 是**过渡态**，下一个大版本升级（Debian forky / Mobian 跟进）会换成 stevia 包名。
- **phoc 侧相邻改动**：phoc 0.51 加了 "Cancel preedit on submit"（MR !731，避免 chatty/flare 重提交）——若日后升 phoc，A 案的 preedit 行为判据（R3/R4）要重跑。
- 对我们的含义：**A 案（零上游改动 + 纯外部 helper）是对上游漂移最免疫的形态**，这也是维持"主推 A、B 缓行"的又一理由；若未来 stevia 的 pipe 语义变化，受影响的只是 helper 侧契约，改造点集中。

---

## 6. 推荐下一轮动作排序

1. **收口 §4.1 矛盾**（5 min，主机侧）：把 Rb §1.5 部署配方的 `['always']` 改为 `['hint','manual']`（或标注"0.46 无 always，走 manual 开关"），并在 `reports/ime-rime-backend-20261123.md` 加一行勘误指针 → 本文件。
2. **补 A 案守护链接产物**（主机侧，~30 min）：临时装 `librime-dev`（或容器内）把 `librime-piped` 链成 aarch64 可执行，连同 sha 记入 `verify/aarch64/`；不跑全量编译。
3. **设备窗口批 1（A 案升级，15 min）**：§2-A 四步 + `verify/ime-zh-rime-verify.sh`；记录 R1–R5 + 与现役 pypinyin helper 的候选质量/延迟对比（`nihao/shijian/womens` 三键对照）。
4. **B 案接线补丁落盘**（主机侧 1–2 h，可在等窗口时做）：产出 `0003-…wiring.patch`；**但重编执行推迟**到 Debian/Mobian 换 stevia 前的最后一个 0.46 窗口，与 haptic `0001`、layout `0002` 合并为一次 divert 批（H2/H3/L1/L2 四判据同窗口收）。
5. **持续跟踪**（并入 D10 lane）：watch `World/Phosh/stevia` 的 pipe completer 相关 issue/MR 与 DebianOnMobile 的 stevia 上传节奏；phoc "Cancel preedit on submit" 进 trixie 时重跑 R3/R4。

---

## 7. 残余不确定

- sha256 完整值未在本 lane 独立重算（无 shell），只复核了 4 个关键文件的存在与首部内容 + 主会话 `git show --stat` 的 14 文件清单；如需逐字节对账，跑一行 `cd patches-userland/zh-ime-rime-20261123 && find . -type f -exec sha256sum {} \;`。
- B 案接线补丁"配方在头注释"的说法依据 Rb §1.2，未逐行核对 `pos-completer-rime.h` 全文。
- 上游判断基于公开 release/Debian 档案与 maintainer 月报（2025-11 为最新读到的月报），未逐条翻 stevia 0.47–0.53 的 NEWS diff；"pipe 语义未变"是**无反证推断**，非逐行核对结论。
