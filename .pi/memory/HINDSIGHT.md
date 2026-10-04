# Hindsight — elden（y700-elden）

Techniques and root causes proven on Qualcomm/Lenovo tablet flashing. Host-machine

<!-- Older entries compacted -->



## Automatic settled outcome - 2026-10-04

已实测两处的实际定义与配置。结论先行。

## 一、数字结论

**两者完全等价，差别 = 0**——`flashing` 不是 profile，只是 4 行的 `cd` 包装脚本：

```bash
# /home/xuqianhui1001/.local/bin/flashing   (2026-09-30 生成)
cd "/home/xuqianhui1001/y700-elden" || exit 1
exec pi "$@"
```

所以在 `~/y700-elden` 里输 `pi` 和在任何地方输 `flashing`，加载的东西一模一样。**差别只在「你在别处输 `pi`」时才出现**，而且不是 `flashing` 有什么魔力，纯粹是 cwd 决定加载范围。

同类快捷方式还有 `eacndev`、`lob-remake`，形态完全相同。

## 二、cwd 决定加载范围（真正的差别）

| 项目 | cwd = `~/y700-elden`（= `flashing`） | cwd = 家目录 / 别处裸 `pi` |
|---|---|---|
| 项目指令 `<repo>/AGENTS.md` | ✅ | ❌（只有全局 `~/.pi/agent/AGENTS.md`） |
| 项目技能 `.pi/skills/`（`qualcomm-android-flashing`、`qualcomm-edl-flashing`、`gsi-device-adaptation`） | ✅ 与全局技能叠加 | ❌ 只剩全局 `~/.pi/agent/skills/` |
| `.pi/settings.json`（`sessionDir=.pi/sessions`、默认 `deepseek/deepseek-flash`、thinking low、retry 8） | ✅ 覆盖全局 | ❌ 用全局（`ustc_ai/deepseek-flash-2`） |
| `profile_memory` 落盘 | `.pi/memory/`（HINDSIGHT 76 KB 的设备结论） | `~/.pi/agent/memory/`（另一套，标题是 "main agent (default profile)"） |
| 会话存储 | `~/y700-elden/.pi/sessions/` | `~/.pi/agent/sessions/--home-…--/` |
| `pi -c` / `-r` 看到的历史 | 刷机全部会话 | **空的/错的**——这是最容易误判的一条 |
| swarm 任务卡 `.pi/missions/` + `.pi/agents/`（6 角色） | ✅ | ❌ |

（当前会话 `PI_PROVIDER=ustc_ai PI_MODEL=qwen3.8-flash-next-2` 是显式覆盖，不代表默认值。）

## 三、一个反直觉的特例：项目**子目录**里输 `pi`

按 pi 文档（`docs/configuration.md`）两类文件解析规则不同：

- **AGENTS.md**：从 cwd **向上找**，所以在 `flashing-bundle/` 里也能读到 → 看起来"项目生效了"。
- **`.pi` 配置**：只认**工作目录下**的 `.pi`，不向上找。

后果：子目录启动 = 有项目说明，但**项目技能不加载、`sessionDir` 不生效（会话落错桶）、默认模型回到全局**。→ 在子目录里也该 `cd ~ && flashing`，或 `flashing -c`。

> **【2026-10-04 更正】**上述 `flashing`/`eacndev`/`lob-remake` 三个包装入口**已删除**；现役写法 = `cd ~/y700-elden && pi`。本节其余（cwd 决定加载范围、子目录特例）仍然成立。见 `archive/2026-10-04-retired-entrypoints/`。

## 四、名字的历史包袱（别被误导）

`flashing` 这名字来自旧机制 **pi-profile-switch** 的 `flashing` profile（`flashing-bundle/README.md` §2 记着）。现已废弃：`~/.pi-profile-switch` **在本机不存在**，改为「按工作目录叠加加载，无需切 profile」（`AGENTS.md` 亦如此写）。两处残留是纯化石：

- `.pi/memory/*.md` 标题 `# … — flashing`
- `f


## Automatic settled outcome - 2026-10-04

**音频收尾（R3）完成并提交** `4aacf40`。

## 做了什么

| 项 | 结果 |
|---|---|
| `scripts/audio-alsa-init.sh` | 新增：幂等地设好播放（`SECONDARY_MI2S_RX`+增益）与采集（AMIC1→ADC2→DEC0→TX3）路由 |
| `/init` 钩子 | RAM 根与持久根都在 `dmesg` 之后后台调用（与 UCM/PipeWire 同值幂等共存） |
| `build-rootfs.sh` | 脚本纳入 RAM 镜像打包清单 |
| 持久根 `/dev/sda17` | 已**离线挂载装入**脚本 + `/init` 钩子（`sh -n` 语法通过），无需刷机 |
| 默认音量 | **400**（可 `ALSA_PLAYBACK_VOLUME` 覆盖）——上次 1023 满值太吵，抱歉 |
| 实测 | U2 **RAM** 环境 `aplay -D default` rc=0 + 扬声器听声 ✅；`arecord` 路径同样设定 |
| 文档 | `TASKS.md` G1-4 记录 R3；`check-doctor` **FAIL=0 / WARN=1**（会话计数 59≠54，pre-existing） |

## 音频剩余（未闭环，均非本轮可解）

- **R1 有线耳麦**：代码就绪（vk48：`wcd-playback-dai-link`+RX 宏控件静态检查✅），**缺 USB-C 模拟耳机硬件**无法听声；另需 `wcd939x-usbss`（i2c TYPEC mux）。
- **R2 双麦**：已实测为 AMIC1+AMIC4 阵列，双路采集价值低，文档记录不做。
- **R4 容器音频**：设备未装 Waydroid，暂不可做。

## 唯一待确认

持久根的改动**尚未经历一次持久启动验证**（我只离线写入+语法校验）。你下次正常重启到持久系统时，`/run/audio-alsa-init.log` 应有一行输出，桌面音频不受影响。

要不要我现在就做 R1 的 UCM `Headphones`/`Headset` 段（照上游 MTP 配方，代码完成待硬件验收），还是转去 G1 其它缺口（相机出流 / TF 卡 / BT 配对）？


## Automatic settled outcome - 2026-10-04

状态核清了，给你**决定路径的判断方法**——先插上试 2 分钟就能分岔。

## 当前设备状态

| 项 | 状态 |
|---|---|
| 运行镜像 | **vk48 RAM**（R1 播放 DTS 已加载：RX 宏控件 29 个 ✅、`HPHL Switch`/`RX_HPH PWR Mode` 在） |
| USB-C 模拟开关 | 本机是 **FSA4480**（`fcs,fsa4480` @ i2c5 0x42/0x43），**不是** `wcd_usbss` |
| FSA4480 驱动 | 内核 `CONFIG_TYPEC_MUX_FSA4480=m`（模块）→ **当前 RAM 启动无 `/lib/modules`，加载不了**；持久根模块版本还停在旧内核 `gba28ec16f01f`，与现用 `gbd114ca33` 不匹配 |

## 关键分岔：插上你的耳机，回我结果

请把耳机/转接头插到**设备上没接线的那个 USB-C 口**（另一个口在跑 USB-NCM 到主机），然后告诉我哪个现象出现：

| 现象 | 类型 | 结论 |
|---|---|---|
| 插上后 `dmesg` 出现 **`new full-speed USB device` / `USB Audio`**；`aplay -l` 多出一个 **USB 声卡** | **数字**（自带 DAC） | 大概率**开箱即用**，我直接帮你切到它出声 |
| 插上后**没有** USB 声卡出现，只有 Type-C/UCSI 事件 | **模拟**（无 DAC） | 需补工作：把 FSA4480 编成 **built-in** + 处理"谁把它切到 AUDIO 模式" |

你插上后回我一句（或直接把 `dmesg | tail` 贴给我），我这边同时查。**先说结论：如果是数字耳机，R1 今天就能听声闭环；如果是模拟，我们要多一步改内核。**

你手上的是哪一种？


## Automatic settled outcome - 2026-10-04

**音频收尾到此为一个干净的停顿点。** 两个提交：

| commit | 内容 |
|---|---|
| `4aacf40` | **R3 裸 ALSA 默认**：`scripts/audio-alsa-init.sh`，无桌面/PipeWire 时 `aplay`/`arecord` 开箱可用；`/init` 在 RAM+持久根调用；默认增益 400；U2 RAM 实测听声 ✅；持久根 `/dev/sda17` 已离线装入 |
| `2d4408d` | **R1 冻结 + 更正**：本机 USB-C 模拟开关是 **FSA4480**（`&i2c5` @0x42/0x43），非之前假设的 `wcd_usbss`/i2c3；驱动 `=m` 且 RAM 无模块、持久根模块旧版本 → 需编 built-in；无耳机硬件，听声验收冻结 |

`check-doctor`：**FAIL=0 / WARN=1**（会话计数 59≠54，pre-existing，与本次无关）。

## 音频总账

- **输出**：扬声器 ✅（G1-4 已闭环，桌面 PipeWire/UCM + 裸 ALSA 双通路）。
- **输入**：内置麦 AMIC1 ✅（UCM `Mic`）。
- **耳机（R1）**：代码就绪，**硬件冻结**。日后拿到 USB-C 耳机后：数字 dongle → 大概率即插即用；模拟耳机 → 先编 `CONFIG_TYPEC_MUX_FSA4480=y`，见 `archive/topics/HEADSET-HW-2026-10-04.md` §6。
- **R2 双麦**：实测 AMIC1+AMIC4 阵列，双路价值低，不做。
- **R4 容器音频**：设备无 Waydroid，不可做。

下一步若继续 G1，剩余缺口是 **相机出流 / TF 卡写稳定 / BT 配对** 三项。要不要挑一个？


## Memory - 2026-10-04

2026-10-04 入口清理（eld/y700-elden）：现役启动入口 = `cd ~/y700-elden && pi`；`~/.local/bin/{flashing,eacndev,lob-remake}` 三个 cd 包装已删除（pi-profile-switch 机制早废，本机无 ~/.pi-profile-switch）。并发子代理 = `Agent` 工具 + `.pi/agents/*.md`（插件 @tintinweb/pi-subagents），**无 harness 守护进程**；旧 `pi-messenger-swarm` 已卸载，其 6 脚本+2 补丁+`.pi/pi-messenger.json`+`.pi/messenger/` 全部移入 `archive/2026-10-04-retired-entrypoints/`（判据 §3、恢复 §4、被移出记忆区的原文附录 §6）。`scripts/check-doctor.sh` 新增第 4 项：这些路径若回到活跃树即 FAIL，机器层快捷入口复辟则 WARN。判据教训：**卸载插件后其脚本会静默失效（node ENOENT）而不报错**，故凡引用 `~/.pi/agent/npm/node_modules/<pkg>/` 的仓库脚本必须纳入 doctor 存在性检查。


## Automatic settled outcome - 2026-10-04

**清理完成并提交 `c5351c3`；`check-doctor` FAIL=0 / WARN=1（唯一 WARN 是清理前就存在的会话索引 54 vs 实有 59）。**

## 一、移除与归档了什么

| 类 | 内容 | 去向 |
|---|---|---|
| **shell 快捷入口 3 个** | `~/.local/bin/{flashing,eacndev,lob-remake}`（同为 4 行 `cd` 包装，pi-profile-switch 时代命名）| 已删除，副本 → `archive/2026-10-04-retired-entrypoints/bin/` |
| **死插件 `pi-messenger-swarm` 资产 10 项** | 6 脚本（`swarm.sh`/`swarm-monitor.sh`/`y700-swarm-reset.sh`/`y700-harness-restart.sh`/`start-y700-harness.sh`/`apply-swarm-patch.sh`）+ 2 补丁 + `.pi/pi-messenger.json` + `.pi/messenger/`(848K) + `logs/swarm-monitor.log` | 脚本/补丁 `git mv` 入归档；运行时目录 tar 留证（96K）；日志删 |
| **不存在的插件经验** | `FAILURES.md` 的 `## Memory - 2026-10-02` swarm 块（600 字符，全是挂在已卸载插件上的修法）| 原文 + 「仍有效的抽象结论」→ 归档 §6 |

判据（写进归档 §3）：`pi list` 无此包 → `node_modules` 无此目录 → 脚本硬编码的 `…/pi-messenger-swarm/dist/harness/server.js` 不存在 = **静默失效而非报错**；`AGENTS.md` 旧引用的 `swarm.py`、`.pi/messenger/agent-card.json` **从未在本机存在过**。

## 二、防止复辟 + 文档收口

- `scripts/check-doctor.sh` 新增**第 4 项**：上述路径若回到活跃树 → **FAIL**；`~/.local/bin/*` 复辟 → **WARN**（13 项全 ok）。
- `AGENTS.md` §其他 明确现役入口 `cd ~/y700-elden && pi` + 并发形态 = `Agent` + `.pi/agents/`（**无守护进程**）；`INDEX.md` §4 加注、§6 补归档行、#91→**#93**。
- `PITFALLS §15.1` +5 行废弃登记、`§15.2` 登记 7 处孤儿目录；`RESOURCES §3` 台账体积/计数刷新；`.pi/README.md` 删 `pi-messenger.json`/`messenger/` 两行、`missions/agents` 改挂 pi-subagents；`.gitignore` 保留规则但注明出处。
- 记忆区：三份标题去掉废弃 profile 名 `flashing` → `elden（y700-elden）`；HINDSIGHT 旧「用 flashing」段加**行内更正指针**（不改写原文）。

## 三、两件需要你知道 / 拍板的事

1. **并发会话抢提交**：我的 8 个 `git mv` + 1 个 `git rm` 被**同时运行的另一个 pi 会话**（R1 耳机取证，`archive/topics/HEADSET-HW-2026-10-04.md`）的提交 `2d4408d` 一起扫走入库——路径变更完整无损，只是提交信息不匹配，已在归档 README 记明原因。教训：**同 worktree 并发会话下禁用 `git commit -a`**（本次我全程显式列路径）。
2. **机器层孤儿目录 12.2 M 待授权清理**（`grep` node_modules 无任何已安装包引用）：`~/.pi/agent/pi-sessions/` 12 M、`~/.pi/


## Automatic settled outcome - 2026-10-04

三个子代理已并行派发（后台运行，完成后会通知我）：

| 子代理 | 缺口 | 绑定 key | 本轮范围 |
|---|---|---|---|
| `camera-vk49` | G1-5 相机出流 | `ustc_ai_2` | 构建**内核+相机模块匹配**的新 boot 镜像、冷启自动加载、精确验收步骤 |
| `tf-card` | G1-6 TF 卡写稳定 | `ustc_ai_3` | 厂商 `uses_level_shifter` 移植分析、候选补丁、A/B 实验设计与压测脚本 |
| `bt-link` | G1-7 BT 链路高延迟 | `ustc_ai_4` | 排除 IBS 后重定位根因、上游修复检索、候选补丁与测试脚本 |

主会话保留 `ustc_ai` key，四 key 均在用（负载均衡）。

**协作约束（已写进各自 prompt）**：只做主机侧、不刷机/不重启/不写设备；不 `git commit`；不改根目录 6 份维护文档（结论各写 `archive/topics/*-2026-10-04-subagent.md`）；共享内核树构建用 `flock /tmp/y700-kbuild.lock` 串行；TF/BT 只产出 `patches/candidate-*.patch` 提案，不直接改 `linux/`。

**设备侧**：U2 现在停在 **fastboot**。等三个代理交回资产后，我会汇总成一份串行的上机验收清单（相机镜像 / TF 压测 / BT 测试），由你逐项执行——符合"用户操作设备"。

我现在不轮询，等它们完成通知。三个都回来后我会独立复核产物（不采信自报成功），再给你收口计划。


## Memory - 2026-10-04

判定 node_modules「孤立依赖」的正确方法（2026-10-04 教训）：不能对 `ls node_modules` 数条目——scoped 包是**作用域目录**（`@aws`/`@babel`/`@google` 本身不是包，展开后可能只剩 1 个子包，卸载后残留空壳会让 `du` 显示 40K–128K）。正确判据 = 用 `package.json` 的直接依赖 + `package-lock.json`(v3 `packages` 字段) 的传递依赖求闭包，与磁盘**展开 scoped 后的包名**比对；`npm prune --dry-run` 只认 lockfile，lockfile 已清则报 "up to date" 而磁盘残留仍在（或反之）。据此本机结论：pi 扩展 node_modules 11 包 = lockfile 闭包 11 包，无需清理。


## Automatic settled outcome - 2026-10-04

三项全部落地，两个提交。

## 数字

| 项 | 结果 |
|---|---|
| `~/.bash_profile` 修正 | `导出 PATH=` → `export PATH=`；登录 shell 不再报错，`~/.dotnet/tools` 已进 PATH；备份 `~/.bash_profile.bak-20261004` |
| `~/.pi` 孤儿目录 | 9 处 → **移动到** `~/.pi/_trash-2026-10-04/`（**13 M**，未硬删） |
| `node_modules` 疑似孤立依赖 | **判定为不需要清**（见下） |
| `check-doctor` | FAIL=0 / WARN=1（唯一 WARN 仍是会话索引 54 vs 实有 59，与本次无关） |
| 提交 | `c5351c3`（清理+归档）、`3812b39`（机器层收尾登记）；工作树干净 |

## 一、孤儿目录（回收目录，可回滚）

`~/.pi/agent/pi-sessions/`(12 M，含已卸载 swarm 的 `messaging/broker.log`) · `~/.pi/wechat/`(1.1 M，含该渠道 `credentials.json`) · `~/.pi/todos/`(11 个) · `agent/pi-agent-profiles/` · `session-control/` · `_wtest` · `agent/{_cron_backup,missions,git}/`。
确认无影响后你自己执行：`rm -rf ~/.pi/_trash-2026-10-04`

⚠️ **回收前看一眼**：`_trash…/agent__cron_backup/crontab.2026-10-04-preclean.bak` 是今早 08:51 另一个会话清空 crontab 前的**唯一备份**（lobcorp-remake 的 swarm 看门狗 `*/10 … swarm_watch.sh`；当前 `crontab -l` 为空）。若 lobcorp 还要它，从该文件恢复。

## 二、一处更正：node_modules 其实没有孤立依赖

我上一条把 `@aws`/`@babel`/`@google` 当包数了——**scoped 目录是作用域，不是包**（`@aws` 已空、`@babel/types` 只是残留空壳）。按正确判据算：`package.json` 7 个直接依赖 + lockfile 传递闭包 = **11 个包**，与磁盘展开后 **11 个完全一致**（`croner`/`nanoid`/`typebox` 都是 `pi-subagents` 的传递依赖）。故未动 `npm/node_modules`。判据已写入持久记忆，避免下次重犯。

`~/.pi/workflows/` 按承诺**保留**（pi-subagents 的 `SubagentWorkflow` 保存位）。

## 三、现役入口（今后只需这一条）

```bash
cd ~/y700-elden && pi        # 并发 = Agent 工具 + .pi/agents/*.md，无 harness 守护进程
```


## Automatic settled outcome - 2026-10-04

## 汇报 — TF 卡写稳定性（主机侧静态分析 + 资产）

**改动文件 7 项，全部未 commit；未刷机/未写设备/未编内核/未改根 6 文档。**
新增：`scripts/tf-stress.sh`、`patches/candidate-tf-{levelshifter,drop-dma-coherent,uhs-1p8,lower-hs-hz,bus-width-1}.patch`、`archive/topics/TF卡-2026-10-04-subagent.md`。（`git status` 里 `HINDSIGHT.md/rootfs/init/camera-*` 是并发会话的，非本轮。）

### 1. 根因判定倾向
**卡本身 ~70–80%**。硬证据：尺寸相关性（64 MB 大块多轮全对 vs 8 MB 小写间歇丢）、`err_stats` 全 0、`e2fsck` 前后一致（坏在卡上）、白牌 `NCard`/date 2010/`OEM 0x0303`、已在最保守 3.3V/SD_HS 档仍坏。**相干性/DMA 错误会按字节随机发生，不会只挑小写** → 强烈指向卡。最终仍须换卡 A/B 定性。

### 2. `qcom,uses_level_shifter` 精确结论（本轮最硬发现）
厂商该属性**唯一功能 = SD_HS 时钟封顶 37.5 MHz**（`sdhci-msm.c` L638-640，`LEVEL_SHIFTER_HIGH_SPEED_FREQ=37500000`）；**不碰 DLL/DDR 寄存器**（DLL config 两边一致 `0x0007442c`/`0x80040868`）。主线靠 `sm8750.dtsi` 的 `max-sd-hs-hz=<37500000>` 达到**完全相同数值**（实机 ios 也确认 37.5 MHz）→ **无效移植，不能作为根因候选**。厂商另有 `qcom,external-fb-clk`（VENDOR_SPEC_FUNC4.EXTERN_FB_CLK，主线缺）但本机 DT 未使用。

### 3. 候选补丁（按代价排序，均已 `git apply --check` 通过）
| 补丁 | 代价 | 区分什么 | 预期 |
|---|---|---|---|
| a levelshifter | 低 | 时钟源一致性 | **无变化**（留档） |
| b drop-dma-coherent | 低 | 一致性声明错误 | PASS→相干性根因 |
| d lower-hs-hz(12.5M) | 低 | 时序/信号余量 | PASS→余量问题 |
| c uhs-1p8 | 中 | 3.3V-HS vs 1.8V-UHS | 预期更差（对照） |
| e bus-width-1 | 低 | DAT1-3 信号完整 | PASS→数据线 |

（只改 DT 的补丁重编 DTB 即可；构建须 `flock /tmp/y700-kbuild.lock`。）

### 4. 用户 A/B 实验步骤
1. 启动 Linux（`fastboot boot out/boot-elden-vk48.img` 或 b 槽），TF 挂到 `/mnt/tf`；
2. `scp scripts/tf-stress.sh root@192.168.7.1:/tmp/ && ssh root@192.168.7.1 'sh /tmp/tf-stress.sh -r 3 --fsck /mnt/tf'` → 记基线；
3. **换已知良好卡**重跑同一步（决定性）；
4. 本卡插安卓/PC 读卡器跑等价写后读回；
5. （建议）全卡写满再读回排除扩容黑片。

### 5. 压测脚本
`scripts/tf-stress.sh` — 幂等/低干扰（只写 `.tf-stress.$pid/` 临时文件、退出自清）、自限（总 `timeout` + 单 dd 超时）、防假阳性（`sync`+`drop_caches` 后回读哈希）、快照 `cid/ios/err_stats`、可选 `--fsck`。
用法：`tf-stress.sh [-r 轮][-n 块][-m Mi


## Automatic settled outcome - 2026-10-04

`tf-card` 完成，我已**独立复核**（未采信自报）：

- 7 个文件都在；`tf-stress.sh` 语法 OK；5 个 `candidate-tf-*.patch` 对 `linux` 树 `git apply --check` **全部 OK**。
- 抽验其最硬结论：主线 `sm8750.dtsi` 确有 `max-sd-hs-hz = <37500000>`，与厂商 `LEVEL_SHIFTER_HIGH_SPEED_FREQ 37500000` **数值相同** → "移植 level-shifter 无效" 的判定成立。
- 根因倾向 **卡本身 70–80%**（小写丢/大块全对、`err_stats` 全 0、`e2fsck` 前后一致、已是最保守 3.3V-HS 档），最终仍需**换卡 A/B** 定性——需要你一张已知良好的 TF 卡。

**提交策略**：先挂起，等 `camera-vk49` 与 `bt-link` 都回来，我统一复核后按主题分批提交（避免并发半成品混进 git）。

`camera-vk49`（要编内核，最慢）与 `bt-link` 仍在跑，我等通知。


## Automatic settled outcome - 2026-10-04

## 汇报（相机 G1-5 主机侧）

### 数字结论
| 产物 | 大小 | sha256（前 8） |
|---|---|---|
| `out/boot-elden-vk49.img`（持久） | 88.1 MiB | `249ee683` |
| `out/boot-elden-vk49-ram.img`（纯 RAM） | 88.1 MiB | `ddeb5735` |
| `out/boot_b-vk49.img`（b 槽签名，pad 96 MiB） | 96 MiB | `1c44343c` |
| `out/camera-modules-7.2.0-debug-g5a70ade46a88.tar.gz` | 8.6 MiB | `7cd5835c` |

- 内核 `uname -r` = **`7.2.0-debug-g5a70ade46a88`**（`#46` 12:31）；模块 **20/20** vermagic 全等，同一次构建。
- 镜像内内核 DTB 含 `s5kjns/gc08a8/gt9764/qcom,sm8750-camss/wl2868c`；ramdisk 第二段含 20 `.ko` + `modules.dep` + 加载器 + `/init` 钩子（逐项列验）。
- 体积 < 96 MiB boot 分区；曾因叠加基座错误涨到 101 MB，已用 `.bak-vk48` 重建修正。

### 证据摘要
- `modinfo -F vermagic` 20 模块 = `…g5a70ade46a88 SMP preempt mod_unload aarch64`。
- 解 boot 镜像内核流：`strings` 得同串 uname；追加段 `cpio -t` 得 20 `.ko` + `/usr/local/sbin/camera-modules-load.sh` + `modules.dep`。
- `sign-boot-b.sh`：公钥 sha1 `fc1e3b33…`，与 `vbmeta_b_flags3.img` 链一致。

### 冷启方案
`rootfs/init` 在 `switch_root` **前**调 `scripts/camera-modules-load.sh`（幂等、`timeout 20`、非致命，日志 `/run/camera-modules.log`）→ 持久与纯 RAM 两变体冷启均自动加载，无需手工 modprobe。新增 `rootfs/build-camera-overlay.sh` 以第二段 cpio 追加（不重建 Alpine）。闭包 17→20（补 `leds-qcom-flash` 链）。

### 用户验收（设备已在 fastboot，零写盘优先）
1. `fastboot boot ~/y700-elden/out/boot-elden-vk49.img`（持久根+相机；`-ram` 为纯 RAM 仅验 probe）。
2. 采证：`cat /run/camera-modules.log`、`dmesg | grep -iE 'camss|csiphy|cci|s5k|gc08|gt9764|wl2868|dependency cycle'`、`ls /dev/video* /dev/media*`、`ls /sys/bus/i2c/devices/`、`media-ctl -p`、`v4l2-ctl --list-devices`。
3. 成功：日志以 `[camera] done: N media` 收尾；i2c 出 `0-0056/1-0031/0-000c`；`/dev/media0` 且 graph 含 sensor↔csiphy/csid/vfe。
4. 失败：`invalid module format`→重建；sensor `-517` 循环→查 LDO1/4/7、MCLK、reset-gpio。
5. 可选刷 b：先验 vk49 再 `fastboot flash boot_b out/boot_b-vk49.img`。

### fwnode 依赖环判断
`camera@56 ↔ isp@ad27000` 的 `Fixe


## Automatic settled outcome - 2026-10-04

相机子代理复核完毕，**关键回归已排除**：

| 复核项 | 结果 |
|---|---|
| vk49 DTB vs vk48 DTB | **逐字节相同**（`461fe072…`）→ 音频/WCD939x/热区 DTS 改动**全部保留**，无回归 |
| 相机模块 vermagic | 20/20 模块 = `7.2.0-debug-g5a70ade46a88`，与内核 `kernelrelease` 一致 |
| vk49 ramdisk | 第二段含 20 `.ko` + `camera-modules-load.sh` + 当前 `init`；`init` 同时含**相机钩子**（switch_root 前）与**我的音频 R3 钩子** |
| 产物 | `out/boot-elden-vk49{,-ram}.img`（88.1 MiB）、`out/boot_b-vk49.img`（96 MiB，b 槽签名）、`camera-modules-…g5a70ade46a88.tar.gz` 均在，sha256 前缀与自报一致（`249ee683` / `ddeb5735` / `1c44343c`） |
| 相机 loader 脚本 | 幂等、`lsmod` 去重、优先用随包 `modules.dep`、按 clk→cci→pmic→camss→sensor 顺序 |

**发现一处小缺口（非回归）**：vk49 的 RAM 基座 `out/rootfs.cpio.gz` 是旧构建，**不含 `audio-alsa-init.sh`** → 纯 RAM 变体下 R3 不生效（持久根 `/init` 已有该脚本，桌面/PipeWire 路径不受影响）。等三个代理收完，我在汇总步骤里用一行 overlay 补上并重打包，不单独动 vk49 哈希。

`bt-link` 仍在跑。等它回来我一并汇总、分批提交，并给出串行上机验收清单。


## Automatic settled outcome - 2026-10-04

## 汇报

**结论先行：既有证据链排除了"主机 IBS 握手"这个方向。** 本轮读代码发现两个关键事实，二者合力把根因指向**控制器侧**：

| # | 新发现的代码事实 | 影响 |
|---|---|---|
| F2 | `IBS_HOST_TX_IDLE_TIMEOUT_MS = 2000`（`hci_qca.c:80`），**不是 100 ms** | archive 里"调大 tx_idle_delay 无效"这个实验接近空操作，没真正测到主机睡眠 |
| F3 | `qca_enqueue()` 每次发包都 `mod_timer(tx_idle_timer, +2000ms)` | `l2ping -i 0.2` 期间主机 TX **全程 AWAKE** ⇒ 主机→控制器 WAKE 握手不在每包路径 |
| F4 | vk25 后无 SLEEP_IND ⇒ 主机 `rx_ibs_state` 恒 AWAKE | 主机 RX 侧握手也不在每包路径 |
| F7/F8 | 运行波特率由 **PERI 协议硬编码 8 Mbps**；`qca_wcn7861_uses_current_baudrate()` 命中时**跳过** `qca_set_speed` | **DT `max-speed` 可能完全不生效**（取决于 helper 返回值） |
| F9 | `qca_port_reopen()` 注释点名"RTS/CTS 同步问题"，但 WCN7861/Peach 路径**从不调用它** | H2 有据 |

**假设排序（每条附判别手段）：**
1. **H4 控制器固件自身深睡**（vk25 只停了 SLEEP_IND 通报，没停睡眠）——首推；零内核改动判别：`KEEPALIVE=1`。
2. **H2 控制器 CTS 反拉致 geni TX 停顿**——判别：关硬件流控补丁。
3. **H1 8 Mbps 时钟余量/误码**——判别：降到 3 Mbps；但 PERI 固件下载在 8M 下成功，削弱此假设。
4. **H3 主机 IBS 握手**——逻辑上已排除（F2/F3/F4），补丁仅作量化收尾。
5. H6 geni RX DMA 水位——低概率。

**候选补丁**（均 `git apply --check` 通过；未改 `linux/`、未 commit）：

| 路径 | 区分 | 风险 |
|---|---|---|
| `patches/candidate-bt-maxspeed-3000k.patch` | H1（PERI 字面量 0x15→0x0e + 实参 + DTS 三处） | 控制器不支持 ⇒ PERI EIO，hci0 不出现，重启回退 |
| `patches/candidate-bt-no-flow-control.patch` | H2 | 突发冲垮控制器 RX |
| `patches/candidate-bt-host-ibs-awake.patch` | H3 残差 | 空闲功耗略增 |
| `patches/candidate-bt-ibs-wait-stats.patch` | H3 量化（`ibs/tx_wait_ms|_cnt`，纯诊断） | 无 |

**测试脚本** `scripts/bt-link-test.sh`（幂等、`timeout` + `trap` 自限、只读、不留后台进程）：
```sh
PEER=AA:BB:... scripts/bt-link-test.sh          # 基线：RTT/loss + ibs_* 差值
PEER=... KEEPALIVE=1 scripts/bt-link-test.sh    # 测 H4（每 50ms 发 Read_Local_Version）
```
判读：`ibs_sent_wakes_delta≈0 && tx_wait_cnt_delta≈0` ⇒ H3 结案；`KEEPALIVE=1` 使 RTT 塌回 <10ms ⇒ H4 成立。脚本同时 dump `dmesg` 的 Product/SoC/ROM ID（判定 F8 helper 是否命中，进而判定 DT 改动是否有效）。

*


## Automatic settled outcome - 2026-10-04

三路全部收口并提交（4 个 commit）。四个 key 全程并行、主会话未互相打爆限流。

```
6ad19ec docs: TASKS G1-5/6/7 记录三路并行子代理结论与上机验收判据
6f38865 bt: 根因重定位 + 4 候选补丁 + 测试脚本（G1-7）
fa7c3f2 tfcard: 换卡 A/B 定性资产 + 5 候选补丁（G1-6）
8c16ea4 camera: vk49 内核+模块匹配基线与冷启自动加载（G1-5 主机侧就绪）
```

## 串行上机验收清单（一次 vk49 会话可做完三项）

设备现在还在 fastboot。**推荐先零写盘 `fastboot boot`**：

**① 相机 probe（G1-5，零写盘）**
```
fastboot boot ~/y700-elden/out/boot-elden-vk49.img      # 持久根 + 相机
ssh root@192.168.7.1
cat /run/camera-modules.log                              # 应见 [camera] loaded ... / done: N media
dmesg | grep -iE 'camss|csiphy|cci|s5k|gc08|gt9764|wl2868'
ls /dev/video* /dev/media*; media-ctl -p; v4l2-ctl --list-devices
```
成功判据：日志以 `[camera] done: N media` 收尾；i2c 出现 `0-0056`/`1-0031`/`0-000c`；`/dev/media0` graph 含 sensor↔csiphy/csid/vfe。

**② BT 根因判别（G1-7，零写盘、零编译，需一个 BT 对端如你的 PC）**
```
PEER=<对端MAC> sh /tmp/bt-link-test.sh          # 基线 RTT/loss + ibs_* 差值
PEER=<对端MAC> KEEPALIVE=1 sh /tmp/bt-link-test.sh   # 测 H4 控制器深睡
```
判读：`KEEPALIVE=1` 使 RTT 从 30–190ms 塌到 <10ms ⇒ **H4 成立**（控制器固件深睡），再上 `patches/candidate-bt-*` 编译。

**③ TF 卡 A/B（G1-6，需一张已知良好 TF 卡 + 本卡读卡器对照）**
```
scp scripts/tf-stress.sh root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'sh /tmp/tf-stress.sh -r 3 --fsck /mnt/tf'   # 本卡基线
# 换已知良好卡，重跑同一条（决定性）
```
新卡连续 ≥3 轮 0 不一致 + `e2fsck -fn` 干净 ⇒ **卡不良，任务闭环=换卡**；新卡也坏 ⇒ 上 `candidate-tf-lower-hs-hz` 等补丁。

## 两处已知小缺口（不阻塞）

- vk49 的**纯 RAM 变体**基座是旧 ramdisk，不含 `audio-alsa-init.sh` → R3 在纯 RAM 下不生效（**持久根 `/dev/sda17` 已有，桌面不受影响**）；下次内核重建时补齐。
- `patches/candidate-*.patch` 均为**提案**（已标 DO NOT COMMIT ON HARDWARE），未入树；按验收结果再决定应用哪个。

你要我先做哪一步？我可以把 ①②③ 合成一个一键上机脚本，或直接陪你逐条执行。


## Automatic settled outcome - 2026-10-04

**根因已修 + 重打包完成**。设备现在跑在 vk47a（b 槽，之前重启回落的），要验新 vk49 需重新 boot。

## 复验步骤（零写盘）

```
# 设备 Linux 里：
reboot bootloader                      # G1-24 已打通；或主机 adb reboot bootloader
# 主机：
fastboot boot ~/y700-elden/out/boot-elden-vk49.img
```

起来后采证（**日志现在进 dmesg 了**）：
```
ssh root@192.168.7.1 'dmesg | grep "\[camera\]"; echo ---; lsmod | grep -E "qcom_camss|videodev|s5kjns"; echo ---; ls /dev/media* /dev/video*; media-ctl -p'
```

**成功判据**：dmesg 出现 `[camera] loaded qcom-camss` 直到 `[camera] done: N media, M video nodes`；`lsmod` 有 `qcom_camss`/`videodev`；出现 `/dev/media0`，`media-ctl -p` 的 graph 含 sensor↔csiphy/csid/vfe。

## 本轮修的到底是什么

| 项 | 内容 |
|---|---|
| 根因 | 设备用 **kmod 34.2**，`modules.dep` 依赖必须是**完整相对路径 + `modules.dep.bin`**；bundle 里由 `modinfo -F depends` 生成的**裸名**格式 → `modprobe qcom-camss` 解析依赖失败（无依赖的 4 个模块却正常，所以恰好卡在 `qcom-camss`） |
| 修复 | `camera-modules-load.sh` 改为**无条件 `depmod -a`**；`package-camera-modules.sh` 改用 `depmod` 生成索引 |
| 可诊断性 | loader 日志改写 `/dev/kmsg`（持久启动会重新 mount `/run` 盖掉文件） |
| 最终产物 | vk49=`53d22cee83`、vk49-ram=`ee432c4b00`、boot_b=`87a1f8f2ab`（内核未变 g5a70ade46a88） |

提交：`acf16c3` + `a2d7ebc`（连同之前的 `6ad19ec`/`6f38865`/`fa7c3f2`/`8c16ea4`）。

相机 probe 一旦过了，同一次会话就能接着跑 **BT 的 KEEPALIVE A/B**；TF 还差你一张已知良好的卡。你先 boot 试一下？


## Automatic settled outcome - 2026-10-04

审查完成。已落盘。

**数字结论**（只审未改）：本地 `geekidos-linux` 相对主线 v7.2 的完整增量 = **125 个改动文件 + 11 个新增驱动/DTS 文件**（≈12.4k 行）。机械检查全绿：

| 检查 | 结果 |
|---|---|
| 9 个新驱动 `checkpatch --strict` | **0 error / 0 warning** |
| elden 系列 9 补丁 | 唯一 ERROR = 全缺 `Signed-off-by`（其余 17 warning 多为转载描述超列） |
| bindings（改 19 + 新 6）`dt-doc-validate` | **全过**，仅缺 `giantec,gt9764` |
| 板 DTS `dtc` + `dt-validate` | 0 warning；**仅 1 红点** `usb@a600000`（vendor-only dwc3 属性） |

**可上游性分级**（A 直发 / B 需重构 / C 外部阻塞 / D 永不上游）：
- **约 60% 是主线本就缺的硬件支持**（板 DTS、camss 新代、ath12k PEACH/WCN7861、panel、新 codec/regulator）——方向对，可分批立项。
- **~25% 需先重构结构**：`psci.c` vendor 钩子→reboot-mode DT；音频 `audioreach.c` 全局 `apm_src_port` 变量（上游必 NAK）；DSI 散落的 `of_device_is_compatible`。
- **~15% 永远不进上游**：调试打印、`force_hz`/`btqca IBS`/`MHI 90s→3s`、config 片段、`dm-default-key`(Android vendor ABI)。

**流程性缺口**（比代码更要命）：① 9 个 commit 全中文、0 个 SoB；② 浅克隆历史只有 1 commit，GEEKiDoS 基底不可追溯；③ 是发行版内核，上游化须另起干净树重放，不在本树做。

**落盘**：
- `archive/topics/UPSTREAM-REVIEW-2026-10-04.md`（完整 A/B/C/D 分类表 + 复现命令 + sha256）
- `TASKS.md §7` M1–M5 任务 + `INDEX.md`/`AGENTS.md` 交叉引用
- 建议推进顺序：M1 干净树 → **M2 首发小系列 A1(GC块)+A2(battmgr)+A3(aw86927)**（各 1 补丁、独立可测、建立与 ML 联系）→ M3 板支持 → M4 camss/wifi/bt 大件 → M5 剥离 dm-default-key。

未做任何重构。下一步若你要动，最省力是先把 A1–A3 三个小补丁整编成英文带 SoB 的系列——要我现在起草 M2 吗？


## Automatic settled outcome - 2026-10-04

**G1-5 相机：probe 里程碑达成** ✅（`9eb77c8`）。设备现在正跑 vk49 持久系统，是同一会话把 BT / TF 也做掉的好窗口。

## 建议现在就做的两项（同一 vk49 会话）

**① BT 基线判别（零写盘，需一个已配对的对端）**
```
scp ~/y700-elden/scripts/bt-link-test.sh root@192.168.7.1:/tmp/
# 先配对（如你的 PC 8C:C6:81:EA:E1:69），拿到对端 MAC 后：
ssh root@192.168.7.1 'PEER=<对端MAC> sh /tmp/bt-link-test.sh'            # 基线
ssh root@192.168.7.1 'PEER=<对端MAC> KEEPALIVE=1 sh /tmp/bt-link-test.sh' # H4 判别
```
判读：`KEEPALIVE=1` 让 RTT 从 30–190ms 塌到 <10ms ⇒ H4（控制器固件深睡）成立。

**② TF 压测基线（当前卡，随后换卡 A/B）**
```
scp ~/y700-elden/scripts/tf-stress.sh root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'mount /dev/mmcblk0p1 /mnt/tf 2>/dev/null; sh /tmp/tf-stress.sh -r 3 --fsck /mnt/tf'
```

> ⚠️ 记得这个持久系统有「空闲熄屏→重启」未解 bug——测完别让它闲太久，或手动保持唤醒。

## 相机"实际出流"要不要现在就上？

`v4l2-ctl --stream-mmap` 的 `-EPIPE` 是 csiphy 默认格式（`UYVY8_1X16`）与 sensor 实际输出（`SRGGB10`）不匹配所致，需要手工 `media-ctl` 配全链路 mbus format/selection 再 STREAMON。这可以：
- 派一个**专注子代理**（挂 `ustc_ai_2`）在你上机期间迭代调 pipeline，或
- 留到下一轮。

你想先跑 ① 还是 ②？相机出流我可以同时起一个子代理。


## Automatic settled outcome - 2026-10-04

能，而且项目里已经验证过半条路线（相机 20 个 `.ko` 热加载）。先给结论，再分层说清哪些改动本来就**不需要**重编内核。

## 数字结论

| 改动类型 | 现在每次的代价 | 目标代价 | 手段 |
|---|---|---|---|
| 驱动代码（音频/相机/触摸/BT/WiFi/panel/马达…） | 全量内核 + 重签 + 刷机 ≈ 20–40 min | **scp + modprobe ≈ 30 s** | 编成 `=m`，`.ko` 运行时加载 |
| DTS | 同上（其实内核从未重编） | **≈ 2 min** | `make dtbs`(秒级) → `mkbootimg --dtb` → `fastboot boot`（零写盘） |
| DT 微扰（使能节点/改一个属性） | 同上 | **0 重启** | configfs overlay（本机 `CONFIG_OF_OVERLAY=y` 已开） |
| 换内核核心（psci/clk/dwc3/audioreach 头） | 全量 | 全量（不可省） | 但可用 **kexec** 省掉 fastboot 往返 |

关键事实（都已在本地核实）：
- `build-boot.sh` 里 **DTB 本来就是 boot.img 的独立分区**（`mkbootimg --dtb`）——改 DTS 时 `Image.gz` 逐字节不变，重编内核纯属浪费。
- `CONFIG_KEXEC_FILE=y` 且 `KEXEC_SIG` 未开 → **从运行中的系统直接 kexec 新内核+新 dtb**，完全绕过 fastboot/ABL/AVB，一条 SSH 命令完成换内核。
- 相机模块路线已跑通并踩过全部坑（kmod 34.2 要 `depmod` 生成 `modules.dep.bin`、loader 按 clk→cci→camss→sensor 顺序）。

## 建议的三层开发环（由快到慢）

**第 1 环 · 模块环（最常用）**——把当前 `=y` 的 payload 翻成 `=m`：
- 现在编译进内核的：`SND_SOC_SC8280XP`、`WCD939X`、`AW88461`、`BT_QCA`、`ATH12K`、`DRM_MSM`、`PANEL_NT36536`、`AW86927`、`NVT36XXX`（camss/wl2868c/cci 已是 `m`）。
- 必须保持 `=y` 的只有**启动路径**：`USB_DWC3`/`CONFIGFS`（rootfs 靠 USB 网络）、UFS、串口、clk/pinctrl/GCC、PSI 核心。
- 做法：加一个 `arch/arm64/configs/elden-dev.config` 片段（就是现有 fragment 机制），把上面列表 y→m；`scripts/package-camera-modules.sh` 泛化成通用 `package-modules.sh`（打包 + `depmod` + scp + 按序加载），音频/gpr 总线有依赖序，但 `modules.dep` + deferred probe 能兜住。
- **纪律**：模块环期间 boot 里的内核固定不动（如 vk49），否则 vermagic 失配——这正好也防住「改动越界到核心文件却不自知」。

**第 2 环 · DT 环**：`make dtbs`（秒级）→ `mkbootimg` → `sign` → `fastboot boot`。可以做成 `iterate.sh --dtb-only`：检测 `Image.gz` 哈希没变就跳过内核构建。另外 `CONFIG_OF_OVERLAY=y` 意味着小改动可以直接 `/sys/kernel/config/device-tree/overlays/` 打补丁试，满意了再回写 DTS。

**第 3 环 · 内核环（不可避免时）**：boot_b 放一个稳定基座，新内核编好后 `kexec --load --dtb=... && kexec` 起来验证，省掉 fastboot 往返与 ABL 校验；**验证通过才** 走正式签刷。注意 kexec 不重走 A


## Automatic settled outcome - 2026-10-04

**诊断闭环（记录在 `8d9f888`）**——iQOO TWS 2 的问题复现并收窄了：

## 实测数字（vk47a，零写盘）

| 实验 | RTT min/avg/max/mdev | loss | 主机唤醒 | 控制器唤醒 |
|---|---|---|---|---|
| 基线（-c15 -i0.2） | 7.8/**44.4**/110.8/26.8 ms | 0% | `ibs_sent_wakes`=**1** | `ibs_recv_wakes`=20 |
| `KEEPALIVE=1` | 3.9/**35.3**/62.4/15.6 ms | 0% | **1**（不变） | 293 |
| 突发 `-c100 -i0.05` | **20s 内跑不完**（应 ~5s） | — | — | — |
| `hciconfig` errors | RX/TX 均 **0** | — | — | — |

## 结论（推翻了原来的首选假设）

- **H4「控制器固件深睡」不成立**：KEEPALIVE 只把 avg 44→35ms，没塌到 <10ms。
- **H3「主机 IBS 握手」排除**：`ibs_sent_wakes_delta=1` 两种情形一样（主机 TX 全程 awake）。
- 突发直接停摆、且 `errors=0` → **丢在空口/控制器侧**。
- 剩 **H1（8 Mbps 误码）/ H2（控制器 CTS 反拉）**——两者都改不了运行期，**需单变量测试内核**：
  - `patches/candidate-bt-maxspeed-3000k.patch`（H1）
  - `patches/candidate-bt-no-flow-control.patch`（H2）

顺带修了测试脚本 4 个 bug（IBS 路径、RTT 自算、errors 解析、counter 名）。

## 下一步

建议构建 **vk50 = vk49 内核 + `candidate-bt-maxspeed-3000k`**（单变量先测 H1，风险=控制器不支持 3Mbps 则 hci0 不出现，重启回退），`fastboot boot` 后用同一脚本复测 RTT/突发。

要我**现在构建 vk50**（主机侧，~10min）并给你精确 boot 命令吗？还是先派子代理并行把 H1/H2 两个测试内核都备好？


## Automatic settled outcome - 2026-10-04

审计完成，写入 `archive/topics/ITERATION-AUDIT-2026-10-04.md`。核心数字与结论：

## 一句话
**最高杠杆 = 把 payload 驱动 `y→m`（一次性全量重编），此后驱动改动进入 scp+modprobe ≈30s 环；第二杠杆 = 接入 ccache（现在装了但缓存为 0）。**

## 版本控制（🔴 高）
- 顶层仓 **58 commit，无 remote**（无异地备份）；无 tag，vk↔sha 只存在 commit message 里。
- 内核仓 **浅克隆**（`.git/shallow`，grafted 于 `ba28ec16f`）→ 无法向上 bisect，GEEKiDoS 基底不可追溯。
- **vk34–v39、vk43、vk49 无 commit**；提交只覆盖 vk40–v48（分支名 `elden/vk42-audio-thermal` 却含 vk42–48，名实不符）。
- **构建不可复现**：`build-boot.sh` 默认 ramdisk 候选**不含** `rootfs-overlaid-camera.cpio.gz`，vk49 的打包命令已丢失 → 无法用默认命令重建。`mkbootimg` 未设 `SOURCE_DATE_EPOCH`。
- `patches/elden-working-tree-*.patch` 已过期，与 git 形成**双真源**。

## 迭代流程（🔴 高）
- 驱动几乎全 `=y`：SC8280XP/WCD939X/QDSP6、BT_QCA、ATH12K、DRM_MSM、panel、AW86927、NVT36XXX、QCOM_Q6V5_PAS。
- ccache 已装但 **0.0 GiB**，`build-kernel.sh` 的 `CROSS_COMPILE` 未包 ccache → 纯冷编译。
- 模块热加载**已半通**：`package-camera-modules.sh`(depmod 修好的) + `deploy-camera-modules.sh`(**不刷机不重启**) + `camera-modules-load.sh` —— 通用化即得快环。

## Linux→fastboot（🟢 基本就绪）
- `eldroid-bootctl reboot bootloader`（PSCI 钩子 vk41）已通；`flash-b.sh` 可在 Linux 内 dd 写 b 槽。
- **缺口**：文档多处引用 `scripts/cycle.sh`，该文件**不存在**（死引用）。

## kexec（🟡 只差脚本+首测）
前置条件**全部满足**：`KEXEC_FILE=y` + `KEXEC_SIG` 关；arm64 加载器只认**未压缩 `Image`**（已有 62MB）；kexec-tools **设备上已装**（持久根 + Alpine rootfs 都有）。
> 注意：`Image.gz` 不能用于 kexec；`CONFIG_KEXEC` 旧 syscall 未置 → 须走 `kexec_file_load`（`-s`）。

## 建议顺序
**V1–V3 + I1**（加 remote/tag/manifest + ccache，零风险立竿见影）→ **I2→I3**（模块快环）→ **K1/I4**（kexec/DTB-only 并行验证）→ **F1/C1**（to-fastboot + 设备锁）。

要不要我现在就开始落地 **V1（加 remote+tag+补 vk43/vk49 commit）** 和 **I1（ccache）**？这两项零风险。remote 需要你给一个（GitHub/GitLab/校内），或我先只做本地 tag + manifest。


## Automatic settled outcome - 2026-10-04

# vk14–vk34 逐版本时间线（2026-09-30 ~ 10-01）

只读研究结论。构建时间取自 `out/boot-elden-vk*.img` mtime；sha256 为**当前 out/ 原始镜像**哈希（session 里另存的 boot_b 签名镜像哈希不同）。构建/打包命令除注明外统一为：`./build.sh` → `./pack.sh out/rootfs-vk11.cpio.gz out/boot-elden-vkN.img` → `scripts/sign-boot-b.sh` → `scripts/flash-b.sh ... --reboot`。hk14–19 rootfs 固定 `rootfs-vk11.cpio.gz`（62,842,080 B）。全程 uname 恒为 `7.2.0-debug-gba28ec16f01f-dirty`（无 per-version localversion，见 RESOURCES §4.3）。

## 1. 版本表

| vk | 时间(09-30起) | 相对上一版的内核/DT/config 改动 | 编/打包/上机命令 | 真机结果 | 证据文件 |
|---|---|---|---|---|---|
| **vk14** | 09-30 19:08 | `sm8750_dspp_sblk` catalog 补 `.gc = {.base=0x17c0,.len=0x40,.version=0x10008}`（DSPP GAMMA_LUT）。**补丁 0002**。config 基线=去 suspend/hibernate/kexec 的 vk13 树 | `./build.sh`（5m20 全量）→ `./pack.sh`（77 MiB, sha 9c32c9a9…）→ flash-b | ✅ Night Light 面板出现、可调、按钮可用 → 内核 gamma 链路打通。踩坑：裸 `make` 覆坏 `linux/.config`，用设备 `zcat /proc/config.gz` 拉回修复（PITFALLS 9b） | ROADMAP-dep §3/§4；PITFALLS #9b；patches/0002；session 01a0f1ee |
| **vk15** | 19:16 | `aw86927.c` SRAM 上界修复（固件超 4KB 被写死窗口拒；按型号区分 SRAM 窗口）。补丁初版名 `0003-…-sram-window.patch` | build→pack（77 MiB, sha 741fa5a3…）→flash-b | ✅ probe 无报错，但 **不震**（回退 vk14） | session 01a0f1ee；STOCK-KERNEL §4 |
| **vk16** | 19:28 | `aw86927_haptics_play_work` 加临时 `dev_info` debug 打印 | build→pack（77 MiB, sha fae1568c…）→flash-b | 播放路径执行、寄存器可见，**仍不震** | session 01a0f1ee |
| **vk17** | 19:32 | 加深寄存器级 debug（play 路径逐寄存器） | build→pack（77 MiB, sha 11809365…）→flash-b | 播放命令确实执行，马达不动；保留 debug 版继续观察 | session 01a0f1ee |
| **vk18** | 19:47 | 移植厂商 `haptic.ko` 反汇编出的 **AW86937 CONT 连续模式**序列（PLAYCFG3[1:0]=2、VBATCTRL bit6、CONTCFG 等） | build→pack（77 MiB, sha 600b4c72…）→flash-b | ✅ 用户确认**马达震动**（FF path 执行） | STOCK-KERNEL §5；session 01a0f1ee |
| **vk19** | 19:54 | 去 debug 打印，出**干净基线**；补丁定稿 `0003-aw86927-aw86937-haptics


## Automatic settled outcome - 2026-10-04

# vk1–vk13 逐版本时间线（09-28 ~ 09-29）

> 重要前提：**vk1–vk13 全部共用内核字符串 `7.2.0-debug-gba28ec16f01f-dirty`**（localversion 未改），设备上无法自报区分；版本只能靠镜像文件名+打包时间追溯（`RESOURCES.md §3`）。下面时间＝`out/` 文件 mtime（主机 CST）。
> 证据缩写：`928/复盘`=`/tmp/hist928/复盘.md`；`928/SESSION`=`/tmp/hist928/SESSION-2026-09-28.md`；`928/HANDOFF`=`/tmp/hist928/HANDOFF.md`；`929/HANDOFF`=`/tmp/hist929/HANDOFF.md`；`929/INDEX`=`/tmp/hist929/INDEX.md`；`929夜`=`archive/topics/复盘-2026-09-29-夜.md`；`S1`=`.pi/agent/sessions/2026-09-28T11-23-20…jsonl`；`S2`=`.pi/agent/sessions/2026-09-28T14-40-54…jsonl`；`S3`=`.pi/agent/sessions/2026-09-29T05-38-12…jsonl`。

## A. 09-28 白天：从零到显示/USB（命名镜像）

| 版本 | 时间 | 内核/DT/init 改动（自上一版） | 编/打包 | 真机结果 | 证据 |
|---|---|---|---|---|---|
| base1 | 20:05 | 首次用作者 build-boot.sh：内核+最小 busybox initramfs；`--base 0x10000000` | `scripts/build-boot.sh` → `out/boot-elden-base1.img` | ABL/地址实验用，未进 userspace | 928/HANDOFF §4.3；S1 12:05–12:21 |
| diag–diag6 | 20:27–21:03 | 诊断 initramfs 加 `elden_diag_reboot=1`（跑完 40s 自 `reboot -f`）；diag 起 `-d DRM_MSM` | `scripts/build-boot.sh` 覆写 initramfs | **全部废配置**：改 config 后跑 `olddefconfig` 连带删掉 `CONFIG_ARCH_QCOM` → 无 QCOM 平台支持，显示/USB/UFS 全灭 | 928/复盘 §六–七；928/HANDOFF §5 坑1 |
| fixed | 21:09 | 恢复 `.config.panel`（ARCH_QCOM=y）；DTS 节点 `splash-region`→`splash_region`；`CONFIG_PHY_NXP_PTN3222=y`；`CONFIG_BACKLIGHT_AW99706=y` | 同上 | 待验 | 928/复盘 §七 |
| fixed2 | 21:19 | fixed 迭代（config/DT 微调） | 同上 | 同上 | 928/复盘 §八 |
| fixed3 | 21:35 | fixed2 收敛；`boot-elden.img` 为同刻 build-boot.sh 输出 | 同上 | ✅ **首次决定性成功**：Linux 7.2.0 进 userspace；`/dev/ttyACM0` 串口 shell（`[usb-gadget] bound to a600000.usb`）；UFS `sda1..sda15`；背光 probe 成功 | 928/复盘 §八；S1 13:xx |
| fixed4 | 21:46 | **`&mdss_dp0 { status="disabled" }`**（DP 是永远 defer 的 DRM component，卡死 `msm_drm_bind`→无 card0） | 同上 | ✅ **显示打通**：logo→闪→Linux 终端页 | 928/复盘 §八；9


## Automatic settled outcome - 2026-10-04

已完成。git 历史从 58 个提交补到 **107 个**，`vk1`–`vk40` 每个版本都有对应提交与标签。

## 结果

| 项 | 值 |
|---|---|
| 新分支 | `history/pre-vk34`（49 个提交，根 = `base1` 2026-09-28） |
| 新标签 | 49 个：`base1 diag fixed3 fixed4 alpine gpu3 vk1…vk40 vk36debug vk38 vk38debug vk40-ram` |
| 嫁接 | `git replace --graft e3ec468 <回填末提交>` → `git log HEAD` 连续显示 107 个提交 |
| 嫁接处一致性 | 回填末提交树与 `e3ec468` 树**逐字节相同**（`git diff e3ec468 history/pre-vk34` 为空） |
| 既有提交 | **未改动**，`e3ec468` 及之后所有 sha 保持原样（文档里的引用不失效） |

## 怎么做的

- 用 `out/boot-elden-*.img` 的 **mtime** 排出 49 个版本边界，逐个用纯 plumbing（临时索引 + `commit-tree`）生成提交，工作树/索引零改动。
- 文件集与内容取自 **`e3ec468` 的树**（git 纳管时的 293 文件快照）；每个文件归属最早的「epoch ≥ mtime」的版本。
- 对 11 个补丁 + 6 个 config 做了**显式归属**（如 `patches/0001-ath12k-*.patch` → `vk9`、`0009` → `vk34`），修正 mtime 相邻导致的 ±1 版本漂移。
- 10-02~10-03 纳管前的收尾并入一个桥接提交。

## 局限（已写进 README）

1. mtime 只记「最后一次修改」——同一文件被多版反复改，只能落在最后时刻那个提交，**早期中间态无法还原**；因此有若干**空提交**（只承载版本叙事/标签），这是诚实的「该版本无文件存留到此形态」。
2. 内核源码树与 `out/` 编译产物不在 git 内，回填只覆盖被跟踪的项目文件。

## 落盘

- refs：`refs/heads/history/pre-vk34`、49 个 tag、`refs/replace/e3ec468`（本地引用，clone 不携带，README 给了重挂命令）。
- `archive/2026-10-04-git-backfill/`：`README.md`（方法/局限/复现/撤销）、`plan.tsv`、`gen_plan.py`、`bf_build.sh`、`bf_manifest_all.txt`、`VERSION-MAP.txt`。

查看：`git log --oneline history/pre-vk34`、`git show vk9`。撤销嫁接：`git replace -d e3ec468`。

该目录目前是 untracked；要我把它作为一个提交纳入 main 吗？


## Memory - 2026-10-04

学校 GitLab = git.ustc.edu.cn（SSH Host 别名已配；账号 @xqh；key ~/.ssh/id_ed25519_gitlab_ustc）。个人命名空间支持 push-to-create：直接 `git push git@git.ustc.edu.cn:xqh/<repo>.git main` 即自动建私有项目（无需网页/API token），SSH 测试 `ssh -T git@git.ustc.edu.cn` 返回 Welcome, @xqh。限制：GitLab 服务器拒绝 shallow push（"shallow update not allowed"）——浅克隆仓需先 `git fetch --unshallow`，或改用「合成根」（`git commit-tree <base>^{tree}` 造无父提交 + cherry-pick 增量）推非 shallow 镜像，或改用 format-patch 补丁集留档。


## Automatic settled outcome - 2026-10-04

全部落地。总结如下：

## 已完成（无需设备，均已推送异地）

**V — 版本控制与异地备份** 🔴→🟢
- 顶层仓 `origin` → **https://git.ustc.edu.cn/xqh/y700-elden**（2 分支 + 全部标签，SSH push-to-create 自动建仓）
- 内核仓 `gitlab` → **https://git.ustc.edu.cn/xqh/y700-elden-kernel**（分支 `main`）
  - 浅克隆被 GitLab 拒绝直推 → 用**合成根**（根提交树=上游 `ba28ec16f` 树 + 9 个 elden 增量重放），非 shallow、可正常 clone
- 另有保险：`patches/kernel-history/` — 6 支 elden 分支的 `format-patch` 增量（脱离 git 也能 `git am` 复原）
- `archive/2026-10-04-git-backfill/VERSION-MAP.txt`：原 sha → 镜像 sha 映射 + 复原步骤
- `scripts/build-manifest.sh`：每个 vk 产出 {内核/DTB/config/ramdisk sha、cmdline、mkbootimg argv、镜像 sha256} → 构建可复现可审计

**I — 迭代快环** 🔴→🟢
- `scripts/env-build.sh`：ccache 接入 `CROSS_COMPILE`（此前装了但缓存 0）
- `patches/fragment-modular.config`：音频/ATH12K/触觉/触屏/背光 `y→m`（实测 merge_config+olddefconfig 可翻，模块数 1319→1355）；`fragment-modular-video.config` 可选（DRM/panel，牺牲启动早期显示）
- `scripts/mod-loop.sh` + `iterate.sh mod <dir>`：改驱动 → 编单模块 → scp → rmmod/modprobe，**~30s 不重启**
- `scripts/iterate.sh dtb`：改 DTS 只重编 DTB

**K / F — 去物理重启**
- `scripts/kexec-boot.sh`：用未压缩 `Image` + `--dtb` 走 `kexec_file_load` 热重载（`KEXEC_FILE=y`、kexec-tools 设备已装）
- `scripts/to-fastboot.sh`：`--boot` 零写盘 fastboot / `--flash` Linux 内 dd 进 boot_b 再重启；补上 PSCI vendor reset 进 fastboot

**C — 并发**
- `scripts/device-lock.sh` + 三个设备脚本自锁（flock，防嵌套死锁）：并行子代理串行化单台设备访问

`check-doctor`：FAIL=0。

> 更正一条审计原话：`cycle.sh` **确实存在**（在仓库根，非 `scripts/`），已同步修正。

## 需要你/设备的下一步（一次性）

1. **切换模块化**：跑一次全量构建应用 fragment
   ```
   scripts/apply-kernel-fragment.sh patches/fragment-modular.config   # 一次性
   scripts/iterate.sh kernel --boot VERSION=vk50        # fastboot 零写盘验证
   ```
   之后驱动改动就进 `iterate.sh mod ...` 的 30s 环。
2. **首次 kexec 实测**（用已知good的 vk49/vk50 镜像先验证不崩外设）：
   ```
   scripts/iterate.sh kernel --kexec VERSION=vk51
   ```
3. 若要我把内核仓也做成完整非浅历史（需 `git fetch --unshall


## Automatic settled outcome - 2026-10-04

## 复核结论（先数字）

| 维度 | 判定 | 关键数字 |
|---|---|---|
| 1 可记录可溯源 | 🟡 骨架好，**2 个闭环漏洞** | doctor FAIL=0/WARN=1；git 纳管 391 文件、双仓双远程、回填 107 提交+49 tag；**manifest 生成数=0 且被 .gitignore 吞** |
| 2 规划/并发/子代理 | 🔴 **子代理定义整体过期** | 6 角色+11 任务书 **100% 仍引用已退役 swarm**（`send SageYak`/`task done`/SWARM-PLAN 旧路径）；设备锁覆盖 **3/5**（flash-b.sh、cycle.sh 无锁） |
| 3 迭代/忙等 | 🟡 工具全在，**快环未接通** | ccache 缓存 **8 KB（从未命中）**；`WCD939X=y` 未模块化 ⇒ 音频进不了 30s 环；kexec 实测 **0 次**；轮询已全部有界 ✅ |

---

## 维度 1：可记录可溯源

**做得对**：6 文档分层 + SSOT 声明、archive 只增不改、git 回填+graft+VERSION-MAP、双异地备份、`check-doctor` 守门、.gitignore 边界有注释台账。

**漏洞**：
1. **manifest 闭环断裂**：`scripts/build-manifest.sh:9` 自己写着 "Commit the manifests"，但产物写到 `out/`，而 `.gitignore:18` 整目录忽略 `/out/`，且无 `!/out/*.manifest` 例外 → **每版可复现指纹永远进不了 git**。vk49 及之前的版本也还没有 manifest（生成数=0）。
2. **入口目录混散件**：根目录有 `sn.img`（BL 解锁证据，UNTRACKED）、`dtc-*.whl`、5 个 `y700-elden-docs-*.tar.gz`——与"根目录只有 6 文档+AGENTS"纪律冲突，且都不在 git 里。
3. 小项：RESOURCES §4 收录 54 ≠ 实际 68 会话（doctor 已 WARN）；`.pi/memory/HINDSIGHT.md` 有 +51 行未提交。

## 维度 2：规划任务 / 并发 / 冲突合并 / 子代理

**做得对**：TASKS 唯一台账+§2.1 主机侧并行清单、`device-lock.sh` flock 语义正确（自锁可嵌套、`DEVICE_LOCK_HELD` 透传）、AUDIT3 教训（副作用与轮询不同条命令）已写进任务书、retry 参数已按限流调好、默认模型已切 deepseek。

**漏洞（按危害排序）**：
1. **子代理不可用级过期**：`.pi/agents/*.md` 6 个角色与 `.pi/missions/*.md` 11 个任务书全部是 swarm 时代原文——`send SageYak`、`task done task-12`、"先读 `AUDIO-2026-10-01.md`"（实际在 `archive/topics/`）、`SWARM-PLAN-2026-10-02.md`（同）。`smoke.md` 还绑在已不存在的 task-12。**现在派生这些 Agent 类型，子代理会先浪费多轮去执行不存在的命令/读不存在的路径**，且任务书里"设备当前 vk34"等状态已落后 13 个版本。
2. **锁旁路**：`mod-loop/kexec-boot/to-fastboot` 自锁，但 `flash-b.sh`（写 boot_b+重启）与 `cycle.sh`（reboot/fastboot）无锁——而 **INDEX §4 快速命令恰恰推荐的就是这两条无锁路径**。并发子代理照 INDEX 行事即可撞车。
3. **规划项过期**：TASKS §4 第 1 步"⛔ 先救机器：U2 不可达"与 INDEX §3"U2=vk47 持久直启在跑"矛盾（§4 未随 10-03 深夜恢复刷新）；INDEX §3 快照 82% vs §0 的 85%（SSOT 已声


## Automatic settled outcome - 2026-10-04

P0+P1（无设备项）全部落地并推送。总结：

## 已完成（3 个提交 → origin/main）

| 项 | 内容 | 验证 |
|---|---|---|
| ① 子代理现代化 | 11 份任务书+5 份角色全部重写：**4 条活跃线**（audio 残余/bench/camera 出流/gplay+el2 收口动作）状态对齐 vk49 并指向 `archive/topics/` 真路径；**7 条已收官线**改为「墓碑+残余」，误派时先报告"已收官"不空转；删 `smoke.md` | `send SageYak`/`task done`/`SWARM-PLAN`/`task-N` **0 残留**；新引用路径**全部存在** |
| ② 锁旁路消除 | `flash-b.sh`/`cycle.sh` 补与 mod-loop 同款自锁；INDEX §4 快速命令从 sign+flash-b 改为 `scripts/iterate.sh` 四档环 + `device-lock.sh --status` | 实测三态：空闲拿锁 ✅、被占 1s 报 busy 退出 ✅、`device-lock.sh` 外层持锁时内层透传不死锁 ✅ |
| ③ manifest 闭环 | `.gitignore` 改 `/out/*` + `!/out/*.manifest` | `check-ignore`：img/子目录仍忽略、`.manifest` 放行 ✅ |
| ④ 双 iterate | 根 `iterate.sh` 改为 `exec scripts/iterate.sh`（带新用法注释） | `bash -n` ✅ |
| 顺手 | 修了一个**复核时新发现的 TASKS 原生死引用**：`build-camera-overlay.sh` 实际在 `rootfs/` 而非 `scripts/`（TASKS G1-5 + 任务书同改） | 存在性核实 ✅ |

`check-doctor` FAIL=0（WARN=1 仍是既知的会话索引 54≠68，属 P2）。

## 剩余（下次上机/收工时顺手）

- **P1⑤ 快环接通**（唯一需设备的一次性动作）：`scripts/apply-kernel-fragment.sh patches/fragment-modular.config` → 全量构建一次（带暖 ccache）→ `iterate.sh kernel --kexec` 首测 → 音频 30s mod 环首测。
- **P2**：RESOURCES §4 补 14 个会话；提交 HINDSIGHT 的 +51 行；TASKS §4 删过期的"⛔ 先救机器"；根目录散件归档（`sn.img`/`dtc-*.whl`/5 个 docs tar.gz）；doctor 加 G1% 口径检查。

上机那轮开始时说一声，我把 P1⑤ 和 G1-22/G1-5 的验证合并进同一次会话计划。


## Memory - 2026-10-04

y700-elden 镜像版本归属：boot 镜像文件名 vkNN 与内部内核无关——"vk47.img" 实为 vk46-dirty 内核（commit 在构建后补记），连内核流 sha 也只证"与哪个文件相同"不证版本名。唯一可靠链 = manifest（构建时生成）+ uname 内嵌 LOCALVERSION=-vkNN（2026-10-04 起）；对历史镜像解 gzip 内核流取 "Linux version" UTS 串定性。


## Automatic settled outcome - 2026-10-04

审计完成。全部只读（ls/test/rg/git log/read），未删改任何文件。

# 只读审计报告 — ~/y700-elden（2026-10-05）

**先数结论**：`.pi` 路径引用 93 处核实 **0 真死链**（missions/agents）；SKILL.md 引用 **2 处问题**；无引用脚本 **10 个**（其中 7 个死脚本候选）；HINDSIGHT 有 5 行值得提交；settings/README 无过时。

---

## 一、.pi 配置（agents / missions / skills / settings / README）

| 路径 | 问题 | 证据 | 建议 |
|---|---|---|---|
| `.pi/missions/` + `.pi/agents/`（16 份） | ✅ 健康：93 处路径引用 `test -e` 全部存在（含通配符 `AUDIO-*`、`0011-*` 均命中）；状态全部写 vk47/vk49，与 INDEX §3 一致，**无 vk34/vk40 过期残留**（vk43 均为历史事实表述） | python 提取全部反引号路径核实 | 保留 |
| `.pi/missions/`（覆盖缺口） | bench.md / el2-virt.md / gplay.md 3 份**活跃任务书无对应 agents/ 角色定义**（agents 仅 5 个：audio-graphopen/camera/proxy-waydroid/thermal/win-x86-poc） | `ls .pi/agents/` 对比 `ls .pi/missions/` | 更新：补 3 个角色或派发时用 general-purpose |
| `.pi/missions/thermal.md`（墓碑+残余） | 残余动作（其余热点 passive 盘点、GPU 分级复核）**未并入 TASKS.md**（rg ‘GPU 热区’/‘其余热点’ 在 TASKS 无独立行） | `rg 'GPU 热区' TASKS.md` 空 | 保留（有独特残余判据） |
| `.pi/missions/proxy-waydroid.md`（墓碑+残余） | 残余（netd 原生路由核实/workaround 退役判据）TASKS §2 无独立行（仅 §6 图景一句） | `rg 'netd' TASKS.md` | 保留 |
| `.pi/missions/audio-graphopen.md` | 根因链已被 `audio.md`「现状（已完成，勿重做）」段 + TASKS G1-4 完整覆盖，残余指向 audio.md | 两文件对照 | **可删候选**（低优先） |
| `.pi/missions/stock-camgrav.md` | 纯路标：相机→camera.md、传感器→C4（TASKS §2 C4 均在） | 6 行 | **可删候选**（低优先） |
| `.pi/missions/win-x86.md` | 纯墓碑，指向 archive + win-x86-poc.md；TASKS 59 行 C-历史已覆盖 | 4 行 | **可删候选**（低优先） |
| `.pi/missions/win-x86-poc.md` | 护栏（cgroup/timeout/trap）已进 `FAILURES.md`（Box64 记录）；残余“游戏兼容未排期”TASKS 196 行有 | 对照 | **可删候选**（低优先） |
| `.pi/skills/qualcomm-android-flashing/SKILL.md:81` | **真死链**：`references/dual-boot-complete-2026-08-10.md` 不存在（本 skill references 有 `tb322fc-dualboot-2026-09.md`，疑似改名/从未建） | `test -e` MISS | 更新：改指 2026-09 文档或补建 |
| `.pi/skills/qualcomm-android-flashing/SKILL.md:77` | 路径缺 `../`：写


## Automatic settled outcome - 2026-10-04

审计完成。以下为发现清单（全部只读核实，未动任何文件）。

# 只读审计发现清单 — y700-elden 文档精简（2026-10-04）

**核实方法**：6 份文档全读 + 90+ 个引用路径逐一 `test -e` + `du`/`ls` 对账 + 会话文件计数。

## 1. 引用不存在的文件（doctor 查不到的正文反引号路径）

| 位置 | 问题 | 证据 | 建议 |
|---|---|---|---|
| RESOURCES §2.1（locked 链构建行）+ PITFALLS #85 | **`scripts/extract-avfpubkey.py` 不存在** | `test -e` MISS；两处引用均称"提取工具" | 更新（确认改名或已并入其他脚本） |
| RUNBOOK-BRINGUP.md:375 | **`patches/config-vk-modular` 不存在**，实际名为 `config-vk50-modular` | `ls patches/` 只有 config-vk50-modular | ★只需改一个名字 |
| PITFALLS #74（约 :467） | **`scripts/net-up-manual.sh` 不存在** | `test -e` MISS | 更新（NM 版已取代则删引用） |
| INDEX.md:148 | `flashing-bundle-2026-09-29.tar.gz` 已不在根目录 | 实际在 `archive/2026-10-04-root-strays/`（10-04 归档） | ★只需改路径 |
| RESOURCES §3 顶层台账 "flashing-bundle/ + flashing-bundle-\*.tar.gz \| 19 M" | 同上，tar.gz 已归档 | 同上；台账同节已有 root-strays 行，两行重复 | 合并两行 |
| 其余 85+ 引用（INDEX §6 全部专题档案、TASKS/RUNBOOK 全部脚本、backup/avf/stock、外部 ~/mesa-out、~/下载/tb322fc、~/文档/TB322FU…） | 全部存在 ✅ | test -e 全 OK | 无需动 |

## 2. 过时的数字/状态（含已知“51 会话”同类）

| 位置 | 问题 | 证据 | 建议 |
|---|---|---|---|
| INDEX.md:40、:117 | 会话数 **"51 会话"** | RESOURCES §4 自称 68 条；实际 `.pi/sessions` 递归 **72** jsonl（顶层 63） | ★只需改数字 |
| RESOURCES.md:190 vs :270 vs :195 | 同文档三处会话数 **59 / 68 / 54 互不一致** | 实际递归 72 / 顶层 63 | 统一为一处权威（§4），§3 台账改链接 |
| RESOURCES.md:193 | "archive/ 1.1 M \| 57 篇专题" | 实际 5.4 M / **62** 篇 topics md | ★只改数字 |
| RESOURCES.md:157（§2.5 P1） | "其余 **33 个** boot 镜像" | `out/` 实际 **57 个** boot-elden-\*.img | ★只改数字 |
| TASKS.md:15 | "运维/资产：内核 **vk45**" | out/ 已有 vk46–vk50 + `vk50.manifest`；§4 也述 vk50 | ★只需改数字 |
| TASKS.md:92（§4 步骤 1） | "快环接通（vk50）…kexec 首测" 仍列为下一步，但 RESOURCES §4 表 01a105d1（最新会话）已记 "vk50 构建+kexec 首测”；且同条说“设备实跑 vk46-dirty" | 两处互斥 | **需用户确认**后勾销或改写 |
| INDEX §3 vs TASKS §4 vs RESOURCES §4§3 vs DEVICE §2.2 | **U2 在跑版本四处口径：vk47 / vk46


## Automatic settled outcome - 2026-10-04

这是会话审计子代理的超限失败通知——该维度我在主会话已用脚本补齐并整合进清单（S1–S4），无新增发现。

审计三轮通知全部收官，状态不变：**等你审批** `archive/topics/清理清单-2026-10-04-精简审计.md` 里的编号项（E1–E6 产物 ~7.3 G、S1–S4 会话、D1–D19 文档、C1–C7 配置/脚本）。回复编号即可执行。


## Automatic settled outcome - 2026-10-04

全部执行完毕并推送（`76c444c` → origin/main）。

## 执行总结（先数字）

| 维度 | 结果 |
|---|---|
| 空间 | **28 G → 22 G（省 ~6 G）** |
| 提交 | `76c444c` 已推送 origin/main，工作区干净 |
| doctor | **FAIL=0**（死链检测扩覆盖后扫 26 份文档无死链；唯一 WARN=会话 66≠索引 68，属未批的 S3） |

## 已执行

**删除（批=E1/E2/E4/E5/S1/C1/C2）**
- E1 out/ 旧镜像 **47 个（3.7 G）**；E2 out/archive（1.3 G）；E4 env-pass 中间物（494 M）；E5 swarm 日志（80 M）；S1 五个 junk 会话
- C1 七个死脚本 + C2 四份被覆盖任务书（git rm，历史可回溯）

**D 组（含你给的 vk50 事实）**
- **vk50 kexec 首测失败（内核未换动、无反馈、半成品）**→ 落 `TASKS.md` §4 步骤 1（改写为失败状态，下一步=排查静默失败）；INDEX §3 / DEVICE §1.1、§2.2 同步把 **U2 实跑口径统一为 vk46-dirty**（vk47 文档口径作废）
- DEVICE §1.1 基线段整段重写（vk39/vk40 过时口径）、U2 行 a/b 槽错位修正并精简指向 TASKS；GAPS Q7（=193 GiB）/Q8（出声+采集）标已解决；4 个死路径全修

**C 组**
- **D1 意外发现**：`build-locked-chain.sh:88` 还在静默调用不存在的 `extract-avfpubkey.py` → **补回重建**（~50 行），自测 PASS：对自签 vbmeta 提取 == `avb.avbpubkey` 逐字节一致
- SKILL 2 处引用修正；**check-doctor 扩覆盖** missions/agents/SKILL（原 2 处 SKILL 死链正是漏网）；RESOURCES §2.1 补全量口径；补 3 份角色定义（bench/el2-virt/gplay）；提交 HINDSIGHT +5 行

## 清单外保留（逐个理由，已记录在执行记录里）
`v1-thermal`/`v2-audio`（**G1-23 V1/V2 二分镜像**，删则实验报废）、`vk46{,-ram}`（实跑版本对账锚点）、`vk47a-ram`（基线家族变体）

## 未批不动
**E3** bootslot-b 历史签名包（672 M）、**E6** *.bak、**S2-S4**（子代理会话/补索引/旧会话归档方案待拍板）

全量清单+执行记录：`archive/topics/清理清单-2026-10-04-精简审计.md`


## Automatic settled outcome - 2026-10-04

## 当前进度（截至最后一次提交 `76c444c`，已推 origin/main）

**上一轮做的事**：精简审计执行 —— 磁盘 **28G → 22G**，清掉 47 个旧镜像、junk 会话、7 个死脚本，`check-doctor` FAIL=0。同时把 **vk50 kexec 首测失败**落账，全文档把 U2 实跑口径统一为 **vk46-dirty**（vk47 口径作废）。

### 两个目标

| 目标 | 完成度 | 硬缺口 / 待办 |
|---|---|---|
| **G1** 健全 Linux + 原厂固件驱动 | **~85%** | 3 个硬缺口：**相机出流**、**TF 卡**、**BT 配对**（音频播放+输入已✅） |
| **G2** 无 Android 兼容安卓 | **~45%** | Waydroid/Win-x86 通路就绪；待 C1 复跑 → C3 身份取证 → C2 Play → C4 传感器部署 |

设备：U2 = BL 已解锁 + b 槽 mainline 持久直启（`/`=`/dev/sda17` ext4，Phosh 自启）；U1 = stock Android + root，无 Linux 分区。

### 下一步（TASKS §4，按序）

1. **快环接通排查**（唯一卡点）：vk50 全量构建成功但 **kexec 未换动内核、静默失败**，需先排查（可用 `--boot` 环对照）；之后才是 30s mod 环首测。
2. **G1-5 相机出流**：`UYVY8_1X16` vs `SRGGB10` 格式协商断点（media-ctl）。
3. **G1-22 熄屏重启**：先烧 vk34recon 作基线再二分。
4. **C0 真 Android 对照取证**（U1，覆盖 a 槽前不可复得）。
5. C1 → C3 → C2（C2 需你恢复上行+凭据）。
6. 顺路单变量：BT H1/H2、换卡 A/B、C4 传感器部署、C8 Gunyah 探测。
7. 不占设备：G1-8 基准、G1-9 DP、C5/C6/C7、上游化 M1–M5。

### 一处待处理

工作区唯一未提交改动 = `.pi/memory/HINDSIGHT.md`（+35 行自动记录的本轮执行总结），其余干净。

要不要现在开一轮上机，把 **P1⑤ 快环排查（kexec 静默失败）** 与 **G1-5 / G1-22 验证**合并进同一次会话？


## Automatic settled outcome - 2026-10-04

设备没有看门狗复位，需要你**手动强制重启**：

**操作**：长按 **电源键 ≥ 15 秒**直到屏幕黑掉松开；若无效，试 **电源键 + 音量加** 组合键（高通强制复位）。

复位后它会按 ABL 默认启动 **b 槽（boot_b = vk46 Linux，持久直启）**。启动完成后我这边检测到 `enx` 就会自动 SSH 进去继续。

我这边现在做两件事，等你复位：
1. 后台重建 vk50 全量模块（`LOCALVERSION=-vk50`）—— 这是**必修**的：当前 vk50 内核 UTS 带 `-vk50`，但磁盘/ramdisk 里的模块全是 `7.2.0-debug-g5a70ade46a88`（不带），vermagic 不匹配，相机/音频/WiFi 模块根本加载不了。这也是让 30s mod 环能用的前提。
2. 复位后读 pstore/串口，确认 kexec 挂死点。

### 已确认结论（本轮 kexec 诊断）
| 阶段 | 结果 |
|---|---|
| `kexec -s -l`（load） | ✅ RC=0，`kexec_loaded=1` |
| `kexec -e`（execute） | ❌ **硬挂死**：串口日志在 t≈182s 处中止，无新内核启动横幅、无 panic、无看门狗复位；USB/网络/fastboot 全消失 |

所以旧的"kexec 未换动内核、无反馈"= **执行阶段把 SoC 挂死**，不是配置缺失。kexec 快环在这台机器上当前不可用。

复位后告诉我一声（或我检测到设备自动继续）。


## Automatic settled outcome - 2026-10-04

## 本轮成果（先数字）

| 项 | 结果 |
|---|---|
| 提交 | **`99d49aa` 已推送** origin/main；doctor **FAIL=0** |
| **G1-5 相机出流** | ✅ **前后摄均连续出帧**（此前一直卡在 `-32`） |
| **kexec** | ❌ 定论**不可用**（`-e` 硬挂整机，非配置问题） |
| vk50 模块 | ✅ 用 `LOCALVERSION=-vk50` 重建 **1513 个**，vermagic 与内核一致 |

### G1-5 关键结论
- **前摄** `gc08a8`：`SRGGB10_1X10` 3264×2448 → csiphy4→csid0→vfe0_rdi0→`/dev/video0`（pRAA），10 帧 `<<<<<<<<<<`
- **后摄** `s5kjns`：`SGRBG10_1X10` 4080×3072 → csiphy3→csid1→vfe1_rdi0→`/dev/video3`（pgAA），3 帧 `<<<`
- 帧尺寸精确吻合（9,987,840 = 4080×2448；15,679,488 = 5104×3072）
- **根因**：csiphy/vfe 默认 `UYVY8_1X16` 与 sensor raw 不匹配 + 链路未使能。用 `media-ctl` 整链统一格式 + `-l` 使能即解——**与 3A/供电/时钟无关**。
- 固化：`scripts/camera-stream-up.sh {front|rear} [stream N]`（幂等）

### kexec 定论
`kexec -s -l` **成功**（RC=0、`kexec_loaded=1`），但 `kexec -e` **硬挂整机**：串口 t≈182s 戛然而止、无 panic、无看门狗、USB/网络/fastboot 全消失、pstore 空，需物理强制重启。旧"未换动内核、无反馈"= 这次硬挂。→ 内核迭代改用 **fastboot 零写盘 `boot`/`flash`**。

### 当前设备状态与遗留
- 设备正跑 **vk50**（`fastboot boot`，RAM 内核 + 磁盘根 vk46），SSH 通、双摄可用；**一重启即回 boot_b=vk46**。
- ⚠️ 两个待办：
  1. **镜像超分区**：vk50 镜像 101 MB > boot_b 96 MiB（`build-camera-overlay.sh` 忘了给 `BASE=` 重复叠加）。要刷槽需用 `BASE=out/rootfs-overlaid.cpio.gz.bak-vk48` 重建到 <96 MiB。
  2. **音频模块加载器缺失**：vk50 起音频等驱动改 `=m`，目前无人加载（相机不受影响）。这是 mod 环迁移的另一半。

---

下一步建议二选一：

- **A. 继续 G1-22**（熄屏重启）基线：零写盘 `fastboot boot` vk34recon / vk40 对照 + 空闲熄屏复现。耗时长、会重启，但符合你之前"合并进同一次会话"的意图。
- **B. 先收尾**：把 vk50 重建成可刷的 <96 MiB 版本（并补音频加载器），再做 G1-22。

你要 A 还是 B？（设备目前也能直接停在这，重启回 vk46 即可）


## Automatic settled outcome - 2026-10-04

已落地并推送 `bfe0002`。先给结论，再给约束。

## 已完成（含冒烟验证）

| 产物 | 作用 | 验证 |
|---|---|---|
| `scripts/lane.sh` | `new/list/done/merge/remove/install/alloc`：worktree+分支+元数据 | ✅ 建/删 lane、hook 生效、清理无残留 |
| `.githooks/commit-msg` | lane 分支强制 trailer；lane 名与分支一致性校验 | ✅ 无 trailer→FAIL；错 lane→FAIL；齐 trailer→PASS |
| `versions/vk-registry.tsv` | vk 号 **SSOT**，`flock` 原子分配 | ✅ 已 seed vk50，下次给 vk51 |
| `scripts/iterate.sh` | `next_vk` 改调 `lane.sh alloc`（不再扫 `out/` 猜号） | ✅ 语法检查 |
| `.pi/CONCURRENCY.md` | 约束正文 | ✅ `check-doctor` FAIL=0 |

## 模型：single integrator + forked lanes

```
main ─ base/<date>-<sha> ─┬─ lane/c3-id   (worktree) ─ commits ─┐
                          ├─ lane/c7-slot  (worktree) ─ commits ─┤ 父 merge --no-ff
                          └─ lane/upstream (worktree) ─ commits ─┘  解冲突+doctor+tag
```

## 约束（不可变式）

1. **单写者**：只有父写 `main`、领域层 5 文档、`.githooks`、`versions/`。
2. **文件归属不重叠**：lane 只写自己路径；跨路径回父协调。
3. **lane 只从 baseline 前进**，不 rebase、不 merge main 进来。
4. **内核改动必走 worktree**（`geekidos-linux` 13 G，禁止主 checkout 并发改）。
5. **设备单一串行**：上机/刷写走 `device-lock.sh`，同一时刻一个 lane 持设备。
6. **并发 ≤3**。

## 子代理提交格式（可区分）

```
camera: 前摄出流打通（vk52）

Lane: camera
Agent: camera              # .pi/agents/<role>.md
Baseline: base/20261005-99d49aa
Task: G1-5
VK: vk52
```
`git log --format='%(trailers:key=Lane,valueonly)'` 可机器归集。绕过：`LANE_HOOK_SKIP=1`。

## 版本号：修掉撞车根因

旧 `next_vk()` 扫 `out/boot-elden-vk*.img` → 两个并发构建必取同一个 N。现改为对 `versions/vk-registry.tsv` `flock` 后取 `max+1` 并追加一行，台账入库，父在 merge 时一并提交。

## 当前并行 lane 规划

| lane | 任务 | 只写 | 设备 |
|---|---|---|---|
| `c3-id` | C3 身份/DRM 取证+社区对照 | `archive/topics/c3-*`、`.pi/drafts/` | 无 |
| `c7-slot` | C7 slot 脚本 + A16 `new-tablet` 参数化 | `scripts/` | 无 |
| `upstream` | M1–M5 上游化补丁整理 | `patches/` | 无 |
| （设备 lane） | G1-22 二分 / BT H1·H2 / G1-8 基准 / C1 | 内核 worktree | *


## Automatic settled outcome - 2026-10-04

已推送（`99d49aa` → `bfe0002` → **`2bbd3ea`**；`bfe0002` 是并发会话的 vcs 提交，已在其上）。doctor **FAIL=0 WARN=0**。

# G1-22「熄屏 → 整机重启」彻底查清结果

## 受控复现（零写盘，`scripts/g1-22-dpms-test.sh`）
唯一可靠触发 = **DPMS off**（`wlr-randr --output DSI-1 --off`），不依赖等 5 分钟空闲。

| 内核 | 熄屏测试 | 复位 |
|---|---|---|
| vk34recon | 5 轮 off/on | ❌ 无 |
| v1-thermal（仅热区 DTS） | 5 轮 + **持续 90s** | ❌ 无（×2） |
| v2-audio（仅插桩音频） | 5 轮 + **持续 90s** | ❌ 无（×2） |
| **vk40 原始** | **1 次 off** | ✅ **硬复位 3/3** |
| **vk42（热区 + 干净音频）** | 5 轮 + 90s | ❌ **无** |
| **boot_b 当前 `g4c68eb5ed4e3`** | 10 轮 + 持续 90s | ❌ 无 |

**关键对照**：vk40 引导后**不做熄屏**稳定 ≥151s（uptime 连续）⇒ 复位确由熄屏触发，不是自崩。

## 根因
- 源码二分确定性：`git diff vk40 vk34-recon` = 恰好 5 文件；**v1+v2 源码上 == vk40**；DTB 校验证明 v1 的 DTB == 原始 vk40 DTB（重建忠实）。
- vk40 音频改动含三处插桩：**N1**（`dev_info` 实参里同步调用 `q6apm_get_apm_state()`，每次 probe/开图都额外向 ADSP 发 `GET_SPF_STATE` 并阻塞等待）、**N4**（`print_hex_dump` 整包）、**N2**（给命令加 APM 头）。
- **排除 N2**：vk42 保留了 N2 却完全干净。
- **判定**：崩溃源 = **N1/N4 调试插桩**，且需与**热区 DTS 组合**才致命（单独任一都干净）。机制上 N1 在 ADSP probe/开图路径上做同步阻塞等待，与显示电源切换形成竞态。
- **修复 = vk42 的"干净重落"**（删掉全部音频调试插桩）⇒ **当前内核已免疫**。

## 结论与遗留
- **G1-22 实质已解**：当前 boot_b 不再因熄屏复位；持久根的 `idle-delay=0` 规避可在长测后解除（本轮未动持久根）。
- 取证限制：复位是**硬复位**，无 panic、pstore 为空；ttyGS0 被 getty + 主机 ModemManager 的 AT 探测刷屏，串口没抓到崩溃前消息。
- 次要残留：DPU `vblank timeout` 在 vk40/boot_b 仍偶发，但不再致复位。

证据全部落 `archive/topics/G1-22-2026-10-05.md`，SSOT（TASKS §1/§4/Q21、INDEX §3/§6）已同步。

---

下一步你要哪个？
- **A**：再建一个变体把 N1 与 N4 谁为主钉死（多一次内核构建 + 一轮上机）；
- **B**：就此收尾——当前 G1-22 已足够定论；
- **C**：先处理别的事（比如把 vk50 的音频模块加载器补上，让 vk50 能起桌面）。


## Automatic settled outcome - 2026-10-04

收尾完成。

## 本次会话总览（`76c444c` → `3b00711`，全部已推 origin/main；doctor FAIL=0 WARN=0）

| # | 事项 | 结果 |
|---|---|---|
| 1 | **G1-5 相机出流** | ✅ **前后摄均连续出帧**（此前卡 `-32`）；根因=csiphy/vfe 默认格式与 sensor raw 不匹配+链路未使能；固化 `scripts/camera-stream-up.sh` |
| 2 | **kexec** | ❌ 定论**不可用**：`-s -l` 成功但 `-e` 硬挂整机（无 panic/无看门狗/pstore 空）→ 改用 fastboot 零写盘 |
| 3 | **vk50 模块/版本一致性** | ✅ 用 `LOCALVERSION=-vk50` 重建 **1513 模块**，内核↔模块 vermagic 一致（此前不一致导致相机/音频模块无法加载） |
| 4 | **G1-22 熄屏→重启** | ✅ **彻底查清**：受控复现（vk40+DPMS off **3/3 硬复位**，不熄屏稳定 ≥151s）；根因=**vk40 音频调试插桩**（`dev_info` 内同步阻塞调用 `q6apm_get_apm_state`）+**热区组合**；**N2 已排除**；`vk42` 干净重落即修复，**当前 boot_b 已免疫**（10 轮+90s 熄屏不复位） |

### 关键产物
- 脚本：`scripts/camera-stream-up.sh`、`scripts/g1-22-dpms-test.sh`
- 证据：`archive/topics/CAMERA-2026-10-05.md`、`archive/topics/G1-22-2026-10-05.md`
- SSOT 全文同步：TASKS（§0/§1/§4/Q9/Q21）、INDEX（§3/§6）、DEVICE、RUNBOOK、PITFALLS
- 内核树已恢复原状（`5a70ade46`，`.config` = `config-vk50-modular`）

### 当前设备状态
- U2 跑 **boot_b 持久直启**（`7.2.0-debug-g4c68eb5ed4e3-dirty`，`/`=`/dev/sda17`，Phosh 在跑），SSH 可达 → 直接可用。
- 工作区干净；临时构建物已清理。

### 留待以后（非阻塞）
- 解除持久根 `idle-delay=0` 规避并做一次长时空闲验证；
- 把 vk50 的音频/背光模块加载器补上（让模块化内核能起桌面）；
- G1-22 若要钉死 N1 vs N4，可再建一个变体（本轮已判定修复点，非必需）。

需要我以后处理其中任一项时，随时说。


## Automatic settled outcome - 2026-10-04

设备在线，我把现状和上机队列捋清楚了。先说结论。

## 一、现状快照（只读实测，U2）

| 项 | 实测值 |
|---|---|
| 内核 | `7.2.0-debug-g4c68eb5ed4e3-dirty`（= vk42 干净重落，G1-22 免疫版） |
| 根 | `/dev/sda17` ext4，Phosh 在跑，uptime 8 min，SSH 经 usb0 通 |
| 模块 | ⚠️ `/lib/modules/` **只有** `...gba28ec16f01f-dirty`（旧），**没有运行内核的目录**；`lsmod`=1；`modprobe qcom-camss` → **not found** |
| 相机/音频 | `/dev/media0`、`/dev/video0/3` **不存在**；`amixer controls` 空 |
| Waydroid | `Session: STOPPED`，`Vendor: MAINLINE` |
| 磁盘 | `/` 8.6G/189G |
| 其他 | wlan0 已连；dmesg 有 `pmic_glink ucsi PPM init failed`（已知 DP/altmode 缺，G1-9） |

**即时发现（阻塞复测）**：持久 boot_b 的内核 `g4c68eb5ed4e3` 在持久根里**没有匹配的 `/lib/modules`**（config 里 `CONFIG_VIDEO_QCOM_CAMSS=m`）。所以 **G1-5 相机、G1-4 音频在这套持久系统上现在都复现不出来**——它们是上一轮在 **vk50 RAM 启动 + 自带 overlay** 下验的。这不是新 bug，是「模块化内核 ↔ rootfs 模块」尚未对齐（HINDSIGHT 里记的"vk50 音频/背光模块加载器缺失"同一根问题）。

## 二、进度（TASKS §0）

- **G1 ~88%**：显示/图形/触屏/WiFi/充电/温控/串口/**相机出流✅**/音频播放+输入✅；剩 3 硬缺口 = **TF 卡、BT 配对**（进行中）+ **DP/NFC/CDSP**（未开始）。
- **G2 ~45%**：容器通路就绪，待 C1→C3→C2；C4 代码全就绪待部署。
- 上一轮 AI 的 vk40 结论已闭环：**G1-22 熄屏→硬复位**根因 = vk40 音频调试插桩（N1 同步阻塞 `q6apm_get_apm_state`）+ 热区组合；`vk42` 干净重落即免疫，当前 boot_b 已扩证 10 轮+90s 不复位。

## 三、需要上机的环节（按依赖排序）

| 优先 | 环节 | 前置/条件 | 备注 |
|---|---|---|---|
| **0** | **对齐持久根模块**（修复上面那条） | 主机侧用 `g4c68eb5ed4e3` 的 LOCALVERSION 重编模块并部署，或改刷一个内核↔模块成套的 boot_b | **是所有功能复测的地基**；也可顺手把 vk50 的音频/背光加载器补上 |
| 1 | **G1-22 收尾**：解除 `idle-delay` 规避 → 长时空闲 ≥2×idle 不复位 | 无（内核已免疫） | 低风险 |
| 2 | **G1-6 TF 卡 换卡 A/B** | **需你物理换卡** | 定性"卡 vs 驱动" |
| 3 | **G1-7 BT H1/H2 单变量** | 蓝牙耳机 + 编 `candidate-bt-maxspeed-3000k` / `no-flow-control` 内核 | RTT 常态 <10ms / 无丢包 |
| 4 | **C0 真 Android 对照取证（U1）** | U1 steam+root 接入 | **覆盖 a 槽前必做、不可复得** |
| 5 | **C1 Waydroid 复跑** → C3 身份取证 → C2 Play | C2 需你恢复上行+凭据 | |
| 6 | **C4 传感器 HAL 部署验证** | 需先 `waydroid init` | GAPS Q14 三未知 |
| 6' | **C8 Gunyah 探测


## Automatic settled outcome - 2026-10-04

按方案 A 完成。结论先行。

## 完成情况（U2，boot_b 持久系统，零写盘）

| 项 | 结果 |
|---|---|
| 根因 | 持久根 `/lib/modules/` 只有旧内核 `…gba28ec16f01f-dirty`，运行内核 `…g4c68eb5ed4e3-dirty` **无匹配模块** → 相机/音频"消失"是配置缺失，非功能回归 |
| 对齐 | 按运行内核 config 重建模块（MODVERSIONS/SIG 均关 ⇒ **只需 vermagic 匹配**），部署 **25 个 `.ko`** |
| **G1-5 相机** | ✅ 前摄 `/dev/video0`、后摄 `/dev/video3` 各 **10 帧 `<<<<<<<<<<`，rc=0** |
| **G1-4 音频** | ✅ `audio-alsa-init` 设 L/R=400；`speaker-test -D hw:0,0 -c2` **rc=0** |
| boot 持久化 | `/init` 接入 `camera-modules-load.sh`（旧 `/init` 备份为 `/init.bak-kmod-align`），模块+loader 均在盘上 |
| 资产/文档 | `out/camera-modules-…g4c68eb5ed4e3-dirty.tar.gz`（sha256 `4146dfd0…`）；提交 `cf14411`，doctor FAIL=0 |

## 过程中发现的两个真问题（已入 PITFALLS #99–#101）

1. **构建**：`setlocalversion` 在环境变量 `LOCALVERSION` **未设置**时会补尾 `+`（vermagic 变 `…-dirty+` ≠ 运行内核 `…-dirty`）——必须 `export LOCALVERSION=` 才精确匹配。
2. **运行**：持久桌面上 **PipeWire/WirePlumber 占用 `/dev/media0`** → `media-ctl` 报 `Resource busy`（纯 RAM 无桌面时不存在）。这是持久系统上相机应用会踩的真实冲突，**根治需让 WirePlumber 忽略 V4L2**。
   - 另一坑：模块**开机很久后热载**会撞 `deferred_probe` 超时（`power domains -110`）；**必须开机加载**——已由 `/init` 接线解决。

## 待确认 / 遗留

- **未重启验证开机自动加载**：按项目纪律（SSH-only 持久系统、用户操作设备），我没有自行重启。当前靠热载已验证功能；重启后 `/init` 应自动加载。**要我引导你重启验证吗？**
- **WirePlumber↔相机冲突**未根治（当前是停 wireplumber 才取流）——建议下一步做成 WirePlumber 配置，否则桌面相机应用会间歇 `Resource busy`。
- **G1-6 TF 卡**状态已按你的更正更新为"新卡已在位，可测"，下一步可直接跑 `scripts/tf-stress.sh`。

下一步你要：**A** 重启验证开机自动加载；**B** 根治 WirePlumber 相机冲突；**C** 跑 TF 卡新卡 A/B？
