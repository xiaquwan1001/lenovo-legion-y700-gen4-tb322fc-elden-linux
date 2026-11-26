# `#692` 真根因落到用户态：hexagonrpcd 无 registry 写支持（上游 issue #29 同源），且**我们这代板子把它放大成整机复位**

> 2026-11-27 无人值守轮，主机侧调研 + 只读设备核对。**未上机运行补丁、未投递上游。**
> 关联：`reports/sensors-692-backport-test-20261126.md` §8（假说 A 否证）、`reports/sensors-adsp-pd-pdr-20261127.md`（PD 面排除）、`reports/pmic-pon-reset-reason-20261127.md`（复位源 PMIC 侧榨干）。

## 0. 结论（五行）

1. **上游已有人命中同一根因**：`linux-msm/hexagonrpc` **issue #29**（2026-11-14，open）——「*read-only registry makes the sensors PD abort and crashes the whole ADSP*」，
   X1P42100 机器上 `hexagonrpcd 0.4.0 -s` 同样因 `Tried to open /persist/sensors/registry/registry/DIR for writing` 被拒 ⇒ DSP 断言
   `PDM: service 'sensor_process' crash: 'EF:sensor_process:0x4:sns_registry_4:0x71:sns_registry'` ⇒ **整个 ADSP 掉**。
   他列出的 0.4.0 缺口与我们实测一一对应：`fremove`(24)、`>31` 方法（escape 31 / 真方法 33 = `frename`）、
   **>256 B 输入缓冲**、`/persist/sensors/registry` 只挂了 `registry/` 子目录。作者称一份 ~700 行本地补丁可让 PD 正常 attach 并让 SSC svc 400 应答 libssc。
2. **主线 0.5.0 仍然没有这些**（本机克隆 `da7a374` 逐文件核对）：`apps_std.c` **无 `fwrite`/`fremove`/`ftrunc`/`frename` 实现**、
   `fopen_with_env()` 对 `w`/`a` 直接 `AEE_EUNSUPPORTED`、`listener.c` 仍 `char inbufs[256]`（>256 B 直接报
   `Large (>256B) input buffers aren't implemented`）、`rpcd_builder.c` 只 `hfs_map("registry", …)`。
   仅 `method >= 31` 的扩展分发在 0.5.0 已具备（PR #21 那一半已进树）。
3. **我们这代板子的差异只是"后果更重"，不是"原因不同"**：同一处 DSP 断言，X1P42100 走 rproc SSR（整机活，音频掉），
   我们则**静默硬复位整机**（`PITFALLS #737`）。⇒ **独立佐证了 H2a/板级复位策略**，也说明它**不是**我们的内核/DTB/fastrpc 补丁的问题。
4. **修正一条旧记录**：设备上的包是 **`hexagonrpcd 0.3.2-2`**（Debian trixie），不是文档里写的 0.4.0；且 `/usr/bin/hexagonrpcd`
   是 **Debian 的 POSIX shell wrapper**，无参调用时**自动补 `-s`** 并 `-R /var/lib/droid-juicer/sensors/` 后 exec
   `/usr/libexec/hexagonrpc/hexagonrpcd` ⇒ 「谁在带 `-s`」有明确答案（也是 `PITFALLS #732` 那个开机硬崩循环的入口）。
5. **本轮交付**：最小补丁草稿 `patches/userland/hexagonrpc-write-20261127/`（**87 行**，基于 v0.5.0 `da7a374`）：
   ① 放开 `w`/`a` 打开 ② 新增 `apps_std_fwrite`（恒假成功） ③ listener 输入缓冲 **256 B → 512 KiB** ④ 补挂 registry 两个兄弟文件。
   本机 `meson && ninja` 全绿、`meson test` **3/3 OK**；**未交叉编译、未上机**。

## 1. 上游三件（现查，2026-11-27）

| 件 | 状态 | 关键内容 |
|---|---|---|
| issue **#29** | open（2026-11-14；1 条评论；最后更新 11-16） | 见 §0-1；**问维护者两问**：registry 写支持是否可接受（可加开关）、`>31` 分发是否用 v0.5.0 的写法。评论 1 条（作者补充？）未形成结论 |
| issue **#19** | open（2026-01-30；5 条评论；最后 11-06） | 同一根因的更早报告（SM7635 / Fairphone Gen6）：`Tried to open …/registry/DIR for writing` ⇒ 传感器不出数 |
| PR **#21**（draft） | open（2026-03-20；10 条评论；最后 08-18） | 「Stub support for fwrite, fremove, fclose_fd, fopen_with_env_fd」：fwrite 假成功、放开写打开、method 31 escape 处理、更详细的 buffer-count 诊断。**我们 0.5.0 里已有 method 31 那半，缺写那半** |
| 仓库 | `linux-msm/hexagonrpc`，GPL-3.0，12★/25 fork，默认分支 `main`，最新 push 2026-10-01（`da7a374 rpcd: Map -h to help`），tags 到 **v0.5.0** | 无外部依赖（`json-c` 仅 tools 可选）⇒ 交叉编译成本低 |

## 2. 我们侧事实（逐条）

| 项 | 值 | 判据 |
|---|---|---|
| 设备包 | `hexagonrpcd 0.3.2-2`（Debian trixie），真二进制 `/usr/libexec/hexagonrpc/hexagonrpcd` | 设备 `dpkg -s` / `dpkg -L` |
| 包装脚本 | `/usr/bin/hexagonrpcd` 是 **POSIX sh**；无参时 `hexagonrpcd_extra=${hexagonrpcd_extra-"-s"}` ⇒ **默认带 `-s`** | 设备 `cat /usr/bin/hexagonrpcd` |
| 我们之前那条日志 | `Unexpected buffer count: 1f050100` / `1f050100` 与 #29 的 `1f030000` 同族（buffer-count 校验失败） | `reports/sensors-692-backport-test-20261126.md` §8.2 T1 |
| 0.5.0 缺口 | 无写实现 / `w` 拒绝 / 256 B 上限 / registry 兄弟文件未挂 | `/tmp/hexagonrpc`（`git clone --depth 1`，`da7a374`）逐文件 `grep` |

## 3. 因果链（现在可以写完整）

```
sensors PD attach（hexagonrpcd -s 触发 INIT_ATTACH_SNS）
  → DSP 重解析自己的 registry，需要 fopen(w)/fwrite/… 到 /persist/sensors/registry/**
  → 0.3.2/0.5.0 一律 AEE_EUNSUPPORTED（或 >256B 输入被拒）
  → DSP 侧 sns_registry 断言（PDM: service … crash: sns_registry）
  → ADSP 子系统故障
  → 【板级差异】X1P42100 → rproc SSR，整机活；TB322FC → 静默硬复位整机
```
⇒ `#692` 的「内核侧假说 A」被否证是**对的**：问题从来不在 fastrpc 的消息缓冲落哪个 bank，而在 **DSP 要写文件、用户态不给写**。

## 4. 最小补丁（已落仓）+ 与上游的关系

见 `patches/userland/hexagonrpc-write-20261127/README.md`（含应用方式与**已知局限**）：
- 做法是 **#29 思路的最小可测子集**（不实现真正的持久化，先让 attach 不炸）。
- 之所以先做"假成功"：若 DSP 只在 attach 时把 registry 重写一遍而随后读的是自己内存里的副本，假成功足够；
  若它写完再读回校验，则必须做真正的可写后端（#29 的 ~700 行方案 / PR #21 讨论里的「copy-on-write 到 `/var/lib/hexagonrpc/`」）。
  两种情况**用一次上机就能判**（见 §5）。
- 上游投入判断：**先不投**。理由：① #29 作者已表示可提 PR，重复劳动无益；② 我们先要做的是**给自己拿到可用传感器**，
  上游要不要收「可写 registry」是维护者的策略问题（#29 的两问正等他回答）。等我们上机结论出来后，再决定是**回帖给 #29 补一台板子的数据**
  （需用户放行外部发帖）还是并到 PR #21。

## 5. 上机试验协议（**下一轮做，需先接受"预期复位一次"**）

1. **交叉编译**：`meson setup --cross-file aarch64.txt`（`aarch64-linux-gnu-gcc`，本机已有），产物 `hexagonrpcd` 静态/动态均可；
   部署到 **`/usr/local/bin/hexagonrpcd-patched`**（不碰 Debian 的 `/usr/bin` 包装器，避免 `PITFALLS #654` 的 apt 冲刷）。
2. **零写盘前提**：当前在机核 vk192 正常；试验**不改内核、不刷分区**，只多一个用户态二进制 ⇒ 失败最坏结果 = 整机复位后自动回 `boot_b`
   （已多次实测，见 `#737`）。
3. **执行**：`nohup setsid /usr/local/bin/hexagonrpcd-patched -f /dev/fastrpc-adsp -d adsp -s -R /var/lib/droid-juicer/sensors/ &`
   （`-s` 只在**打了写支持**的二进制上用；**禁止**再对 Debian 0.3.2 用 `-s`）。
4. **判据（三态）**：
   - ✅ 成功 = 60 s 内无复位 + `qrtr-lookup | grep -c 400` ≥1 + `busctl … HasAccelerometer` = true（或 `ssccli --sensor accelerometer` 出真值）；
   - ⚠️ 部分 = 不复位但 `hexagonrpcd` 打印新的 `Tried to open`/`Unsupported method` ⇒ 按缺的方法号补实现（`fremove`=24 / `frename`=33 最可能）；
   - ❌ 失败 = 整机复位 ⇒ 说明 DSP 需要**真正的**写后端（持久化），转 §4 的完整方案。
5. 成功后按 `PITFALLS #451`（udev `ssc-accel` 规则）+ `#453`（unit target 环）复核 `iio-sensor-proxy` 三属性。

## 6. 与台账的关系

- `#692` 的收口形态改成：**用户态补丁 → 上机三态判据**；内核侧「假说 A」「PD 依赖」两条都已是明确的否证结论（不重开）。
- 上游缺口行（按项目原则「能力缺口默认上游化」）：**hexagonrpc 的 registry 写支持**——已有 #19/#29/PR#21 在飞，
  我们的动作 = **备料 + 等我们板子数据**，投递（回帖/PR）另按「逐次批准」。
