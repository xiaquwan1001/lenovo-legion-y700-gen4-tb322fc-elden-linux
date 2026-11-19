# 零到桌面链路静态门（check-doctor §22）— 2026-11-19

**结论（数字在前）**：新增 1 个 doctor 子门 `scripts/doctor/22-desktop-chain.py`（17 条判据 + 反作弊 3/3），
`check-doctor --staged-fast` 由 0.4 s → **0.65 s**、**FAIL=0 WARN=0**；门本身抓出**两处真实回归风险**并同提交修掉
（`udev` 不在 `PKGS`；手册 S1/S2 缺判据段）。**本门是纯静态判据，不需要上机**；设备侧行为验证仍「需上机」。

## 1. 为什么要有这一节

2026-11-19 从 EDL 到可用桌面（提交 `57e915a6`、`d11afc16`）那五个坑（PITFALLS `#681`–`#685`）**全是静默失败**：
每一步的现象都指向下一层（像内核坏 / 像屏坏 / 像源坏），真因都在上一层。修复固化成两件产物：

- `scripts/deploy-desktop-shell.sh`（设备侧 9 步幂等 + `--check`）
- `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md`（S1–S12 每步命令/判据/失败形态/回退）

但**这两件与 PITFALLS 之间没有任何机器校验**：改掉一行 `PKGS`、删掉 `time-sync.sh` 里的一句
`systemctl stop chronyd`、重排手册的 S 步，都只会在下一次上机时以「设备又坏了」的形式暴露。

## 2. 判据（四类不变量）

| 类 | 判据 | 抓的失败形态 |
|---|---|---|
| A 链件 | `deploy-desktop-shell.sh` / `time-sync.sh` `bash -n` 通过；`--check` 只读档在；手册三步件在 | 语法坏 / 只读入口被删 |
| B 坑号锚点 | 每个坑必须在**可执行/可判读**位置有锚点：`#681`→`systemd-udevd`+`/dev/dri/card0`+`aggregate not bound`；`#682`→`phosh-osk-stub`；`#683`→`elden-soft-render`+`trixie-backports`；`#684`→`systemctl stop chronyd`+`flock`+`date -u -s`；`#685`→`usb0-host-route`+`resolved.conf.d` | 判据只写在注释里（`udev` 最初就是这样，脚本 `--check` 根本不查它） |
| C 手册/索引 | `PITFALLS/README.md` 覆盖 `#681`–`#685`（允许合条区间）；手册 `### SN` 连续且**每步有「判据」**；手册引用的 `scripts|rootfs|packaging|…` 路径都存在；速查指向驱动脚本 | 溯源表指向空步号 / 手册引死路径 / 报告成孤儿 |
| D 反作弊 | 合成副本删 `udev`、删 `phosh-osk-stub` ⇒ 本门**必须** FAIL；未改副本 ⇒ FAIL=0 | 门空转（口径同 §18/§19/§20） |

必需包表（删任一个 = 静默失败回来）：`udev`(#681) `phosh-osk-stub`(#682) `libglib2.0-bin`
`phoc` `phosh` `greetd` `seatd`。

## 2b. 配套：`scripts/zero-to-desktop-check.sh`（S5–S12 一条命令）

静态门只能证「判据还在」，证不了「人会不会漏跑」。新增只读自检入口把手册 S5–S12 收成一条命令：

```
S5 起机      ps -p1 -o comm=            = systemd        (#680)
S6 显示      udevd active + card0/fb0 + DPU 聚合 bound    (#681)
S7 网络      default route + http 200                      (#685)
S8 时钟      与主机时间差 < 86400 s                        (#684)
S9 扩容      df -BG / ≥ 100 GiB
S10 基线     → mobian-daily-baseline.sh --check（委托）
S11 桌面壳   → deploy-desktop-shell.sh --check（委托）
S12 GPU      /proc/$(pidof phoc)/fd 里 renderD128 计数 ≥1  (#683)
```

`--list` 供 §22 机器读、`--dry-run` 不连设备打印全部命令（本轮据此离线验证）；真跑只读、
不改设备（收敛动作仍在 daily-baseline / deploy-desktop-shell 里）。设备离线时退出码 3 并打印原因。

## 3. 门抓出的两个真实缺陷（本提交修）

1. **`udev` 不在 `PKGS` 里** —— `deploy-desktop-shell.sh` 的注释写着「① 缺 udev → 模块零加载」，
   但 `PKGS` 里没有它，`--check` 也就**不会**检查它。新增 `== 2b) udev / 模块自动加载（#681）==`：
   `systemd-udevd` active、`/dev/dri/card0`+`/dev/fb0`、DPU 聚合 `bound` 三条；`PKGS` 加 `udev`。
2. **手册 S1/S2 没有判据段**（只有命令与失败形态）⇒ 补「- 判据：…」两段（S1 = `getvar product` < 5 s、
   孤儿 fastboot 为空；S2 = 主备 GPT 逐字节一致 + 设备端 `qdl sha256` 回读）。

## 4. 负向验证（实测输出）

```
$ ROOT=$PWD python3 scripts/doctor/22-desktop-chain.py --selftest
  SELFTEST ok   删 udev ⇒ 抓到了：[FAIL] PKGS 缺必需包：udev（udev=#681 …）
  SELFTEST ok   删 phosh-osk-stub ⇒ 抓到了：[FAIL] PKGS 缺必需包：phosh-osk-stub（#682 …）
  SELFTEST ok   未改副本 FAIL=0（门不是死门）
  SELFTEST OK 3/3

$ scripts/check-doctor.sh --staged-fast | tail -2
== 汇总: FAIL=0  WARN=0 ==        # real 0m0.645s
```

`--selftest` 用 `tempfile` 合成副本（除链件外全部软链到真仓），不改仓库任何文件；递归副本以
`--no-selftest` 启动，不会套娃。

## 5. 未验证 / 需上机

- 新增的 `2b)` 三条判据与 `PKGS` 的 `udev` **只在主机侧静态验证过**（`bash -n` + 门）；
  真正的设备侧行为（`systemd-udevd` active、DPU 聚合 bound、`apt install udev` 生效）**需上机**：
  设备上电后跑 `bash scripts/deploy-desktop-shell.sh --check`，期望 `MISS=0`。
- 门只查「判据锚点在不在」，不查判据**阈值**是否仍合理（例如截图 >20 KB、DPU 聚合字符串）；
  阈值变化仍需人审。

## 6. 落点

| 件 | 变化 |
|---|---|
| `scripts/doctor/22-desktop-chain.py` | 新增（本门） |
| `scripts/zero-to-desktop-check.sh` | 新增（S5–S12 只读自检入口；`--list`/`--dry-run`） |
| `scripts/deploy-desktop-shell.sh` | `PKGS` 加 `udev`；新增 `2b)` 段；头注释判据表同步 |
| `scripts/check-doctor.sh` | ALL/FAST 子门清单加 `22-desktop-chain.py`，头注释子门表加一行 |
| `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md` | S1/S2 补判据段；S11 表加 `udev` 与 `1b` 行 |
| `RUNBOOK-BRINGUP/README.md` | 入口段加本门指针（§8 反孤儿） |
