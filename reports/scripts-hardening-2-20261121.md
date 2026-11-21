# scripts-hardening-2-20261121.md — 脚本整改批 2（D5 小批：build-kernel 守卫假阳性 + 3 个 BROKEN 加 #701 门）

输入：`TASKS/README.md` §4.0 D5 开放项 ⑤（`build-kernel.sh` DSI 守卫对 pristine 上游树假阳性）与 ①（3 个 BROKEN 仍依赖 `ssh reboot2 bootloader`，PITFALLS #701）。
原则：**最小改动 + fail-closed**；不改脚本职责，不加新入口文件；全部主机侧静态/假命令验证，**零设备接触**（未跑 ssh/fastboot/adb/qdl）；**未 git commit**。
上一 lane 同任务 30 min 超时被砍、无产物 ⇒ 本轮只做这两件（最小可交付），B5 相关与 STALE 归档不动。

## §0 结论数字（先行）

| 项 | 数字 | 判据 |
|---|---|---|
| `build-kernel.sh` 守卫分支 | 1 → **3**（B5 / 上游等价 / DEAD） | `scripts/build-kernel.sh` 文件头 `guard_symbols()` |
| 守卫自测 | **4/4 PASS**（3 个必需场景 + 1 附加"平台在但 DRM_MSM 丢"） | `bash scripts/build-kernel.sh --selftest` → `== selftest 4/4 PASS ==` |
| **`build/g7a-tree` 再跑守卫** | 改前 **rc=1（假阳性）** → 改后 **rc=0** | `guard_symbols build/g7a-tree/System.map` → `上游等价 DSI 锚点（msm_dsi_host_init）… rc=0` |
| `build/g7-tree`（同样上游树） | rc=1 → **rc=0** | 同上 |
| 3 个 BROKEN 加门 | **3/3 文件**，门文案 3/3 命中 | `grep -c '需物理键进 BL，见 reports/linux-to-fastboot-20261121.md'` = 1/1/1 |
| #701 门用例（假 ssh/fastboot） | **8/8 PASS**（每文件 2 反 1 正；n5b = 1 反 1 正） | 用例表见 §1.2 |
| `reboot2`/`sysrq` 实代码残留 | **0 处**（3 文件均只剩注释，共 7 行注释） | `grep -n 'reboot2\|sysrq'` |
| `bash -n` | 4/4 OK | 见 §1.3 |
| `sh -n` | 3/3 报错，**但改前同样报错**（bash 专有语法：`<<<`、数组、进程替换） | 见 §1.3；这 3 个文件 shebang 都是 `#!/bin/bash` |
| 改动量 | 4 文件 / +157 −39 行 | `git diff --numstat` |

## §1 before → after

### 1.1 `scripts/build-kernel.sh`（51 → 145 行，+111 −17）

**Before（问题）**：打包后守卫只认 B5 重构名 ——

```
for sym in gcc_sm8750 'msm_dsi_host_bonded_cmd_trigger|msm_dsi_host_bonded_cmd_xfer|dsi_bonded_cmd_trigger' rpmh; do …done
```

pristine 上游树（7.4-rc3 = `build/g7a-tree`，G7 件）没有这三个名字 ⇒ 编成功却 `rc=1` 判死（11-21 晚实测两次阻断 G7）。
实测存档：`grep -c msm_dsi build/g7a-tree/System.map` = **65**，其中 `msm_dsi_host_init` / `msm_dsi_modeset_init` / `msm_dsi_host_xfer_commit` 都在，**没有一个 `bonded` 名**。

**After（三分支，抽成函数便于自测）**：

| 分支 | 条件 | 结果 |
|---|---|---|
| 1 = daily/B5 | `msm_dsi_host_bonded_cmd_{trigger,xfer}` 或 file-static `dsi_bonded_cmd_trigger` | rc=0，打印「DSI bonded（旧名或 B5 重构后名）」 |
| 2 = **上游等价**（新增） | 上游 DSI 锚点之一 + qcom 平台符号非零；锚点集 = `msm_dsi_host_init`、`msm_dsi_host_modeset_init`、`msm_dsi_modeset_init`、`msm_dsi_host_xfer_commit`、`dsi_dev_probe` | rc=0，打印命中的具体锚点名 |
| 3 = DEAD | 上面都不成立 | rc=1，ERROR 指向 `CONFIG_DRM_MSM` + `patches/config-before-fragment-*.bak` |

其他要点：

- 平台面仍是**子串**匹配（`gcc_sm8750` 实际符号是 `gcc_sm8750_probe`；`rpmh` 同理），语义与旧版一致；DSI 一律 ERE 且锁「空白 + 行尾」（System.map 第 3 列是符号名），避免 `…_init` 误命中更长名字。
- 平台面先判：既无 `gcc_sm8750` 又无 `rpmh` ⇒ 直接 DEAD（保 vk81/82/83 那条原有判据）。
- `SMP=${SMP:-$KDIR/System.map}`：可拿既有树的 System.map 复核，**不必重编**。
- `--selftest`：只跑守卫，不 source `env-build.sh`、不编译；合成 System.map 四枚，一键 `bash scripts/build-kernel.sh --selftest`。

**`build/g7a-tree` 那枚件再跑守卫能否 rc=0 —— 已用现有 System.map 实跑，不是推演**：

```
$ sed -n '1,/^# 合成 System.map/p' scripts/build-kernel.sh > /tmp/guard-only.sh
$ bash -c 'set -euo pipefail; . /tmp/guard-only.sh; guard_symbols "$1"' _ $PWD/build/g7a-tree/System.map
[build] symbol guard OK: 上游等价 DSI 锚点（msm_dsi_host_init）+ gcc_sm8750 / rpmh present in …/build/g7a-tree/System.map（pristine 上游树，无 B5 重构）
  rc=0
```

`build/g7-tree` 同判（rc=0）。**未重编**，只用 11-21 22:19 那枚既有 `System.map`（12.8 MB）。
边界：`arms/`「B5 分支优先」证不了真树 —— 宿主上**没有** daily 树的 System.map（`patches/current-tree` 指向 `build/daily`，该目录不在本机），故 B5 分支只由合成夹具 daily.map 覆盖（含上游名，验证优先序）。**未证实**：真 daily System.map 过 B5 分支（等下次日常线打包自然覆盖）。

### 1.2 三个 BROKEN 的 #701 门（`arm-window-hunt.sh` / `q26-recheck.sh` / `n5b-vk64-death-rate.sh`）

统一文案（三文件各一份，内联，无新增共享 lib ⇒ 可逐文件独立回退）：

> `需物理键进 BL，见 reports/linux-to-fastboot-20261121.md`

| 文件 | Before | After（门） | 反/正用例 |
|---|---|---|---|
| `arm-window-hunt.sh`（55→52 行） | `:17-18,27-28` `$SSH 'reboot2 bootloader'` ×2 + SysRq-b 逃生梯；软路径失效后脚本**继续采样** = 静默无效样本 | `to_fastboot()` 只做「已在 fastboot？→ 放行」+「SSH 探活（区分在 Linux / 完全不可达）」；两路都失败 ⇒ 打文案 + `return 1` ⇒ 调用点 `exit 2`。**不再软重启**（不是"重试次数减少"，是根本不试） | 反：ssh 死+fastboot 空 rc=2；反：ssh 活（在 Linux）rc=2；正：已在 fastboot rc=0（不被门误拦） |
| `q26-recheck.sh`（124→133 行） | `:50` 指引 `ssh $TAB 'sync; setsid /usr/local/sbin/reboot2 bootloader'`（agent 照做=普通重启） | 该指引**整条删除**，改为探活分支（SSH 可达/不可达）+ 统一文案，`exit 3` | 反 rc=3 ×2（两种探活结果）；正：已在 fastboot 走原流程（rc=1 只因假 ssh 起机超时，**不是门**） |
| `n5b-vk64-death-rate.sh`（366→384 行） | 批 1 已把 `reboot2` 换成 `systemctl reboot bootloader`，但**失败文案分散**、开跑前不探活（设备既不在 BL 又不可达时仍会进主循环，耗 `slot-retry-count`，#363） | ①新增 `bl_gate()` 统一文案，替换 `boot_vk64`(90 s)/`force_reboot_vk64`(30 s) 两处失败分支；②**开跑前门**：`! FB && ! ssh_alive_probe` ⇒ `exit 5`（放在 `--check` 之后，`--check` 仍是无副作用诊断，设备不可达也照打现场） | 反：rc=5 + 文案；正：已在 fastboot rc=0 |

**用例一键复现**（假 ssh/fastboot，零设备接触；`/tmp/fk/*` 是 4 个 dummy：`ssh_fail`(255)/`ssh_ok`(0)/`fb_none`/`fb_present`(打印 `HA2EXB0E fastboot` 与 `product: elden`)）：

```bash
mkdir -p /tmp/fk/p_fail /tmp/fk/p_linux /tmp/fk/p_fb
# ssh_fail/ssh_ok/fb_none/fb_present 见本节末；然后：
ln -sf /tmp/fk/ssh_fail /tmp/fk/p_fail/ssh;    ln -sf /tmp/fk/fb_none /tmp/fk/p_fail/fastboot
ln -sf /tmp/fk/ssh_ok   /tmp/fk/p_linux/ssh;   ln -sf /tmp/fk/fb_none /tmp/fk/p_linux/fastboot
ln -sf /tmp/fk/ssh_fail /tmp/fk/p_fb/ssh;      ln -sf /tmp/fk/fb_present /tmp/fk/p_fb/fastboot
printf 'FAKE-IMG\n' > /tmp/fake.img; : > /tmp/fake-vk62.img

PATH=/tmp/fk/p_fail:$PATH  bash scripts/arm-window-hunt.sh 5 l:/tmp/nope.img            # rc=2 + 文案
PATH=/tmp/fk/p_linux:$PATH bash scripts/arm-window-hunt.sh 5 l:/tmp/nope.img            # rc=2 + 「在 Linux」
PATH=/tmp/fk/p_fb:$PATH TTY=/dev/null bash scripts/arm-window-hunt.sh 0 l:/tmp/nope.img # rc=0（不被误拦）
PATH=/tmp/fk/p_fail:$PATH  IMG=/tmp/fake-vk62.img LOGDIR=/tmp/q26-a bash scripts/q26-recheck.sh   # rc=3 + 文案
PATH=/tmp/fk/p_linux:$PATH IMG=/tmp/fake-vk62.img LOGDIR=/tmp/q26-b bash scripts/q26-recheck.sh   # rc=3 + 「在 Linux」
PATH=/tmp/fk/p_fb:$PATH    IMG=/tmp/fake-vk62.img OBSERVE=0 LOGDIR=/tmp/q26-c bash scripts/q26-recheck.sh  # 越过门
PATH=/tmp/fk/p_fail:$PATH ALLOW_NOSERIAL=1 IMG=/tmp/fake.img LOG=/tmp/n5b-a.log bash scripts/n5b-vk64-death-rate.sh 0 /tmp/fake.img  # rc=5 + 文案
PATH=/tmp/fk/p_fb:$PATH   ALLOW_NOSERIAL=1 IMG=/tmp/fake.img LOG=/tmp/n5b-b.log bash scripts/n5b-vk64-death-rate.sh 0 /tmp/fake.img  # rc=0
```

实跑结果：

```
[case] armhunt-ssh死-fastboot空 rc=2 want=2 PASS
[case] armhunt-in-linux-ssh-ok  rc=2 want=2 PASS
[case] armhunt-已在fastboot     rc=0 want=!=2 PASS
[case] q26-ssh死-fastboot空     rc=3 want=3 PASS
[case] q26-in-linux-ssh-ok      rc=3 want=3 PASS
[case] q26-已在fastboot         rc=1 want=!=3 PASS      # 门已过；rc=1 来自「起机超时」（假 ssh 不启机）
[case] n5b-ssh死-fastboot空     rc=5 want=5 PASS
[case] n5b-已在fastboot         rc=0 want=!=5 PASS
== #701 gate 用例 8/8 PASS ==
```

四段真实输出摘录（含门文案）：

```
[hunt] 设备在 Linux（SSH 可达）但不在 fastboot —— #701：软重启路径已实测全灭，本节不尝试。
[hunt] 需物理键进 BL，见 reports/linux-to-fastboot-20261121.md（音量下 + 电源），进 BL 后重跑本脚本。
[q26]  需物理键进 BL，见 reports/linux-to-fastboot-20261121.md（音量下+电源）；进 BL 后重跑本脚本。   (rc=3)
  ❌ 开跑前探活失败：设备既不在 fastboot，SSH（root@192.168.7.1）也不可达
  ⇒ 需物理键进 BL，见 reports/linux-to-fastboot-20261121.md（音量下+电源），再用 fastboot boot 重进 vk64。   (rc=5)
```

要复跑正/反用例，dummy 只需 4 个小文件（`/tmp/fk/` 里自建即可）：`ssh_fail`=`cat>/dev/null; exit 255`；`ssh_ok`=`cat>/dev/null; exit 0`（对 `echo up` 回 `up`）；`fb_none`=`exit 0`；`fb_present`= 对 `devices` 回 `HA2EXB0E<TAB>fastboot`、对 `getvar … product` 回 `product: elden`。

### 1.3 静态验证原文

```
$ bash -n scripts/build-kernel.sh                 OK
$ bash -n scripts/arm-window-hunt.sh              OK
$ bash -n scripts/q26-recheck.sh                  OK
$ bash -n scripts/n5b-vk64-death-rate.sh          OK
$ bash scripts/build-kernel.sh --selftest         == selftest 4/4 PASS ==
$ sh -n scripts/arm-window-hunt.sh                44: Syntax error: redirection unexpected   ← 改前(原文件):47 同样报错
$ sh -n scripts/q26-recheck.sh                    29: Syntax error: "(" unexpected           ← 改前:29 同样报错（bash 数组 SSHH=(…)）
$ sh -n scripts/n5b-vk64-death-rate.sh            33: Syntax error: redirection unexpected   ← 改前:33 同样报错（exec > >(tee)）
```

即 `sh -n` 三处报错**全部是既有 bash 专有语法**（`<<<`、`SSHH=( … )`、`exec > >(tee …)`），三文件 shebang 均为 `#!/bin/bash`；本批未引入新的 POSIX 违规（报错行号变动仅因插行）。

自测三分支输出（`--selftest` 原文）：

```
[selftest] daily     guard rc=0 expect=0 PASS   → 分支 1（B5 名，且含上游名仍走 B5 ⇒ 优先序正确）
[selftest] upstream  guard rc=0 expect=0 PASS   → 分支 2（只认上游锚点 msm_dsi_host_init）
[selftest] dead      guard rc=1 expect=1 PASS   → 分支 3（无 gcc_sm8750/rpmh ⇒ 平台先判死）
[selftest] nodrm     guard rc=1 expect=1 PASS   → 附加：平台在但 DRM_MSM 丢仍判死（证明不是"有 gcc 就放行"）
== selftest 4/4 PASS ==
```

## §2 未做与理由

1. **未 `git commit`**（派工单明令）；工作树 4 个文件为 `M` 状态，可直接 `git diff` 复核/回退。
2. **未重编内核**：验收只要求「逻辑推演 + 现有 System.map 实跑」。`build/g7a-tree` 用的是 11-21 22:19 那枚既有 `System.map`（12.8 MB，65 个 `msm_dsi` 符号）。下一次 G7 打包会自动走新守卫。
3. **未动 daily 线实树**：宿主上没有 `build/daily`（`patches/current-tree` 指向它但目录不在本机）⇒ B5 分支只由合成夹具覆盖。这是本批唯一「**未证实**」项，风险低（B5 名与旧代码判据逐字相同，只是搬进函数）。
4. **未把门抽成 `scripts/lib-bl-gate.sh`**：会新增一个脚本入口（审计计数 369 会再变）且三个调用点都要改；内联 3 份 ~12 行更小、更好逐文件回退。若后续再有第 4 个 BROKEN 要加门，再抽 lib。
5. **未动 `arm-console-run.sh`**（审计 TSV 里第三个 BROKEN，`:14` `fastboot devices|grep -q` = #584 SIGPIPE 模式）：不在派工单范围；`arm-window-hunt.sh` 仍 `bash scripts/arm-console-run.sh` 调它，所以本批只保证"进不去 BL 就停手"，未修它自己的 SIGPIPE 缺陷（**残余风险**：设备真在 fastboot 时该脚本仍可能打断 bulk 通道）。
6. **未改 `scripts/README.md`**：跑了 `python3 scripts/gen-scripts-index.py`（348 入口），但它把 **57 行与本批无关的引用计数**一起刷新（索引在别的 lane 之后就陈旧了）⇒ 已 `git checkout --` 回退，避免把无关噪音混进本批。需要时由索引 owner 单独刷新。
7. **`reports/scripts-audit-20261122.md` / TSV 未改**（共享账目，非白名单）：本批后状态 = BROKEN 剩 `arm-console-run.sh` 1 个（另 2 个已加门、`n5b` 属 DANGEROUS 组但同源问题已收口），建议下一轮把该结论写进审计报告而不是现在改。
8. **零设备接触已核对**：所有 ssh/fastboot 调用都经 `PATH=/tmp/fk/p_*` 的 dummy 拦截（`which -a ssh` 仍有真 ssh，但 PATH 前置使 dummy 命中）。唯一"设备侧痕迹"是 `n5b` 的串口采集 lib 读宿主 relay 日志 `/var/log/elden-serial/ttyACM0.log`（只读文件，未开 tty），属既有行为。用例产生的 `logs/arm-l-*` 4 个目录已删除（`git status` 干净，只剩 4 个 `M`）。
