# #638 `to-fastboot.sh` 的 ssh 半开：设备暖复位后连接不会 FIN，脚本停在「device -> fastboot」十几分钟

- 日期：2026-11-13
- pi 会话 id：本项目会话（11-13 上午）
- 主题：Linux → fastboot 单一入口的等待缺陷（用户现场指出「设备从 Linux 到 fastboot 时 ssh 还挂着连接」）

## 症状

`bash scripts/to-fastboot.sh --boot <img>` 打出 `[to-fastboot] device -> fastboot (PSCI vendor reset)...` 之后
**长时间不动**，`fastboot devices` 早已能看到设备，但脚本不往下走（`wait_until "fastboot 上线"` 根本没轮到）。

## 机制

`eldroid-bootctl reboot bootloader` 走的是 **PSCI `SYSTEM_RESET2` vendor reset**（暖复位，不是 ACPI/软件重启）：
整机在毫秒级复位，**TCP 层收不到 FIN/RST**，已建立的 ssh 会话变成半开连接。
客户端只能等内核 TCP 重传超时（默认 `net.ipv4.tcp_retries2=15` ⇒ 约 **13–15 分钟**）才返回。
旧代码 `$SSH 'sync; eldroid-bootctl reboot bootloader' || true` 没有 `timeout`，于是整条链被这一个 ssh 卡住。

## 判据

- 脚本输出停在 `device -> fastboot (PSCI vendor reset)...`，同时主机侧 `fastboot devices` 已经列出设备；
- `ss -tnp | grep 192.168.7.1` 能看到那条 ESTAB/半开连接还在；
- 手工给同一条命令套 `timeout 12` 时，12 s 后立刻继续（设备已在 fastboot）。

## 处置（本机已修）

`scripts/to-fastboot.sh`：
```bash
timeout -k 5 12 $SSH 'sync; eldroid-bootctl reboot bootloader' >/dev/null 2>&1 || true
```
口径与既有脚本一致（`scripts/kexec-bs-cycle.sh` `timeout 12`、`scripts/sd-run-variant.sh` `timeout 15`、
`scripts/uefi-ddr-trial.sh` nohup 后台 —— 它们早就绕过了这个坑，只有单一入口漏了）。

## 规则

**凡「发一条会让设备复位」的 ssh 命令，必须套 `timeout` 或 `nohup ... &`**；
`ConnectTimeout` 只约束「建连」，对「已建连后对端消失」完全无效。
判据不能只看「命令有没有返回」，要看「下游步骤有没有开始」。

---

# #639 日常线一直缺 ADSP `qcom,non-secure-domain`：`/dev/fastrpc-adsp` 不出现、传感器假死，而 vk185 那次是好的

- 日期：2026-11-13
- pi 会话 id：本项目会话（11-13 上午）
- 主题：vk190 定位（vk189 上机时发现 hexagonrpcd 失败）

## 症状（vk189 零写盘上机）

`hexagonrpcd.service` = `failed (status=4/NOPERMISSION)`，日志
`Could not open FastRPC node (/dev/fastrpc-adsp): No such file or directory`；
`/dev/` 里只有 `fastrpc-adsp-secure` / `fastrpc-cdsp(-secure)`；`iio-sensor-proxy` inactive、
`monitor-sensor` 起不来。而 **vk185-adsp 当年三项全 true**（G1-34 收口判据）。

## 根因

`qcom,non-secure-domain` 这行 DT bug 在 2026-11-07 已修并投上游（`patches/upstream/sm8750-adsp-nonsecure-20261107/`），
但当时只在 **vk185 的独立三提树** 里落地；**日常线 `build/daily`（vk184 / vk188 / vk189 全都从它出）从来没带上**。
fastrpc 驱动按该属性分流：没有它 ⇒ ADSP 只注册 `-secure` 设备 ⇒ 用户态拿不到 non-secure 节点。

## 判据陷阱（本轮的真正教训）

**不能靠 `strings <dtb> | grep -c qcom,non-secure-domain` 判断**：DTB 的属性名在 `strings` 块里**按名去重**，
cdsp 节点已经用了这串 ⇒ 计数恒为 1。必须二选一：

- 主机侧 `dtc -I dtb -O dts <dtb>` 后看 `label = "adsp"` 那个节点的属性表；
- 设备侧 `ls /proc/device-tree/soc@0/remoteproc@6800000/glink-edge/fastrpc/`（有 `qcom,non-secure-domain` 才是真带上）。

本轮实测三件：vk184 = 无、vk185-adsp = 有、vk189 = 无 ⇒ 判据成立。

## 处置

`build/daily` 上 `git apply` 该补丁（`--check` rc=0）→ 只重编 DTS/DTB → 重打包 `out/boot-elden-vk190.img`。
上机判据：`/dev/fastrpc-adsp` 出现、`qrtr-lookup` 有 `400 Snapdragon Sensor Core service`、
`iio-sensor-proxy` active、`HasAccelerometer/HasProximity = true`、`monitor-sensor` 打出 `+++ iio-sensor-proxy appeared`。

## 规则

**上游已投 ≠ 日常线已带**：投上游的补丁如果当时是在独立实验树里构建的，收口时必须回头把同一行搬进日常线，
并把「日常线 DTB 是否带该属性」写进上机判据（本轮就是靠 `strings` 计数误判才让它藏了 5 天）。

---

# #640 「config 快照」与镜像不同源 + ABI 门默认参考停在 10-18 旧件 ⇒ 门禁要么必红、要么自己比自己

- 日期：2026-11-13
- pi 会话 id：本项目会话（11-13 上午）
- 主题：vk189→vk190 打包时 ABI 门红的账单

## 症状

打包 `vk189` 时 `scripts/assert-kernel-sane.sh` 必红（`CONFIG_SUSPEND` 差异），当时以 `SKIP_KERNEL_ASSERT=1` 绕过；
而 `scripts/config-vk189-suspend-20261112` 这份「vk189 的 config 快照」打开看，
`CONFIG_LOCALVERSION="-debug-vk188-sysfbfb"`、且**没有** GUNYAH 系列符号 ⇒ 它是 vk188 时点的状态，
与镜像 manifest 的 `config_sha256=feefc38b…` 对不上（现树是 `79f288cf…`，差在 GUNYAH/VIRT_DRIVERS/SYS_HYPERVISOR）。

## 根因（两层）

- **快照不是镜像的 config**：`apply-kernel-fragment.sh` 的 `SNAP=` 是把「当时的树 .config」拷一份；
   之后同一棵树上又改过 config（Gunyah 模块、LOCALVERSION）却没重新出快照 ⇒ 快照与镜像脱钩，
   而 manifest 里只记 sha、不存文件 ⇒ 事后无法复原「那一次到底用的什么 config」。
- **ABI 门的默认参考 = `patches/config-vk127-working-*`（2026-10-18）**，`config-daily-*` 只是
   「找不到 vk127 时才兜底」的备用分支 ⇒ 日常线一旦合法地开 `CONFIG_SUSPEND`，门永远红；
   把它改成「拿当前树比当前树」又会变成循环自证（等于没门）。

## 处置（本轮已做）

- 出 **`patches/config-daily-c2-suspend-20261113`**（= vk190 实际用的 `.config`，含 SUSPEND+Gunyah），
  并把 `scripts/check-abi-config.sh` 的默认参考顺序**反转**：先取最新 `config-daily-*`，没有才退回
  `config-vk127-working-*`（注释里写明 2026-11-13 口径变更）。
- 另一棵在册树 `build/m3v2-7.3rc7` 同步应用 suspend 片段（快照 `patches/config-m3v2-suspend-20261113`），
  让两棵树对同一 SSOT 一致 —— 否则 doctor §5f 会把「没开 suspend 的纯上游验证树」报成漂移。
- 门禁复跑：`build/daily/.config` 与 `build/m3v2-7.3rc7/.config` 均 `✅ 27 项一致`；打包不再需要 `SKIP_KERNEL_ASSERT`。

## 规则

**config 快照 = 打包那一刻的 `.config`，出完镜像立刻存**（`SNAP=` 用绝对路径，并在 registry 行里写文件名）；
**参考 config 必须跟随在机模块树的世代**，换世代时同步换参考，并在注释/known-issues 里记「何时换、为什么」。

---

# #641 `build/` 被 gitignore ⇒ 「在机内核的源侧状态」根本不在 git 里，树一丢就重做

- 日期：2026-11-13
- pi 会话 id：本项目会话（11-13 上午）
- 主题：收尾把 11-13 的散改动收进 git 时发现的存量欠账

## 症状 / 风险

`build/` 整个目录在 `.gitignore`（内核树 13 GB 量级，必须如此），但 **`build/daily` 的脏状态**才是
「vk190 能复现」的全部依据：HEAD 停在 `4da9a8b69fc8`（7.3.1 + payload v2），其上叠着
**6 枚上游批 1 补丁 + ADSP DT 一行 + ramoops DT + CDSP stream-ID + 12 MB Gunyah 移植源码（untracked）**。
这些**一个都不在项目仓里**；历史上 `build/m1-73` 就整棵丢过（M1 行至今标 MIGRATION-LOST）。

## 处置（本轮已做）

出一条全量 worktree patch 入库：
`patches/local/20261113-daily-worktree/0001-daily-worktree-state-vk190.patch`（38 文件 / +8976 −15 / 274 KB，
sha256 `7b6b5137c6f8…`）+ `README.md`（内容分组、回灌命令、`.config` 另存 `patches/config-daily-c2-suspend-20261113`）。

**自检判据**（比「看着对」硬）：在当前脏树上 `git -C build/daily apply --check --reverse <patch>` 必须成功
⇒ reverse 能打 = patch 与工作区逐字一致。生成时注意：untracked 源文件要先 `git add -N` 才会进 `git diff`，
出完 patch 记得 `git reset` 把索引还原。

## 规则

**每出一个要持久化的内核号，收尾必须二选一**：① 增量全部转成 `patches/{upstream,local}/<topic>/` 的独立 mbox；
② 出一条整个 worktree 的 diff 入库。只写「树里已 apply」= 不可复现。

---

# #642 `patches/current-tree` 指到了「验证树」而不是「在机内核那棵树」（静默编错树，2 个月无人发现）

- 日期：2026-11-13
- pi 会话 id：本项目会话（11-13 上午）
- 主题：收尾核对「裸跑脚本会编哪棵树」时发现

## 症状

`patches/current-tree` 的有效行是 `build/m3v2-7.3rc7`（7.3-**rc7** 的 M3 验证树，HEAD `e18a4a66eb7`），
而在机内核 vk184→vk190 **全部出自 `build/daily`**（7.3.**1** + payload v2，HEAD `4da9a8b69fc8`）。
`scripts/env-build.sh` 的 `KDIR` 默认值就取这个指针 ⇒ 裸跑 `scripts/build-kernel.sh` / `iterate.sh` /
`apply-kernel-fragment.sh` 会**默默编另一棵树**，产出的 Image 与在机模块树/DTB 不同源
（历史上同类事故：`#162` 死内核、`#109` 两份实现漂移）。

## 为什么会漂

2026-11-05 交接计划明确「日常线树重建 = `build/daily`，`patches/current-tree` 改指它」，
11-07 又在 `build/daily` 上做了 7.3.1 重基 —— 但 11-12 评估上游合并候选时把指针当成「M3 验证树」
改成了 `m3v2-7.3rc7`，**没有同步 DEVICE/README 的内核树一节**，随后 vk188/vk189/vk190 都靠 `KDIR=` 显式指定，
于是指针错误一直没人碰到。

## 判据（以后现查，不靠记忆）

- `patches/current-tree` 的最后一行必须等于 `${在机内核的源树}`；
- 交叉验证：该树 HEAD 必须能对上 `versions/vk-registry.tsv` 里在机 vk 行的源提交
  （vk190：HEAD `4da9a8b69fc8-dirty` ← payload v2 + 6 枚批 1 + ADSP DT）；
- `bash scripts/assert-kernel-sane.sh`（裸跑、不传 KDIR）必须绿 —— 它现在会拿指针指向的树做闸门
  （本轮实测：`✅ ABI 27 项一致 / ✅ UTS 对齐 / ✅ 非陈旧`）。

## 处置（本轮已做）

指针改回 `build/daily`（注释里写明 11-05 计划、11-07 重基、11-13 复位三段来由）。
`check-doctor` 复跑 FAIL=0；`build/daily/.config` 与 `patches/config-daily-c2-suspend-20261113` 一致
（ABI 参考已随世代换代，见 `#640`）。

---

# #643 「候选词又没了」的真凶是**我们自己的基线脚本**：`daily-baseline.sh` 把 `Items/0=keyboard-us` 写回去

- 日期：2026-11-13
- pi 会话 id：本项目会话（11-13 上午）
- 主题：G1-38「候选窗」11-12 晚报「还是没有候选词」的根因

## 症状

2026-11-11 晚候选窗已验证出真候选（`[你 那 呢 能 年]`，`PITFALLS #619`），三项判据当时也全绿
（`Items/0=rime` / `CurrentUI=kimpanel` / `org.kde.impanel` owner=1），但 11-12 晚用户报「还是没有候选词」。

## 根因（实测对账，不是推测）

设备上三份 profile 摆在一起就一目了然：

| 文件 | `Items/0` | `DefaultIM` |
|---|---|---|
| `~/.config/fcitx5/profile`（现在，手改后） | **rime** | keyboard-us |
| `profile.bak-20261111` | **keyboard-us** | rime |
| `profile.bak-20261112` | **keyboard-us** | rime |

后两份正是 `rootfs/debian/daily-baseline.sh` §3b 那段 heredoc **原样**写出的内容：
`DefaultIM=rime` + `Items/0=keyboard-us`。而按 `#619` 的机制，**新输入上下文只拿 `Items/0`**、
`DefaultIM` 对它无效 ⇒ 只要跑过一次基线脚本（或从脚本重建根），候选就必然空。
脚本里那条「已达标」判据也只 `grep DefaultIM=rime` ⇒ **它认为自己是 OK 的**，缺陷每轮静默复发。

## 处置（本轮已做）

`rootfs/debian/daily-baseline.sh`：
- 判据改成只看 `Items/0`（`awk` 取 `[Groups/0/Items/0]` 下的 `Name=`），`DefaultIM` 降级为提示；
- 写回模板改成 `Items/0=rime` / `Items/1=keyboard-us`，并在写之前 **`systemctl --user stop fcitx5` + `pkill -x fcitx5`**
  （`#619`：fcitx5 退出会把内存态写回 profile，先改后停等于白改）；
- 设备实测：`scripts/mobian-daily-baseline.sh --check` ⇒ `MISS=0 FIX=0`（`Items/0=rime`）。

## 规则

- **修好一次 ≠ 修好**：同一缺陷若还写在「重置脚本」里，就等于给自己埋了定时炸弹。修设备态的同时必须搜一遍生成该状态的脚本
  （`rg -n "Items/0|DefaultIM=rime" rootfs/ scripts/ packaging/`）。
- 门禁要盯**真正生效的字段**：这条坑里 `DefaultIM` 是文档字段、`Items/0` 才是行为字段，门禁看错字段 ⇒ 假绿。

---

# #644 「点空白处键盘收不起来」不是时延参数问题：**Firefox 根本不给 blur 信号**，桥只能靠空闲超时收

- 日期：2026-11-13
- pi 会话 id：本项目会话（11-13 上午）
- 主题：用户三连报（无候选/空白处出光标/收起很慢）里的第 3 条

## 实测（有仪器，不靠感觉）

判据脚本：`vtap3.py`（/dev/uinput 虚拟触摸屏点一下）+ 50 ms 轮询 `sm.puri.OSK0.Visible`。

| 场景 | 收起耗时 |
|---|---|
| 点 URL 栏（键盘出）→ 点页面空白 | **42 991 ms**（≈ 部署里的 `ELDEN_IME_IDLE_SEC=45`） |
| 同上，focusd 改 4 s 空闲阈值后 | **2 183 ms** |

**根因**：Firefox（Wayland/Gecko）点页面空白时，**既不向 fcitx5 发 `Enable(false)`，也不让 IC 变 `State=0`**
（focusd 日志连续两条都是 `hide requested by idle timeout`，从来没有 `State=0` / `zero spot rect`）。
`zero spot rect` 与 `Enable(false)` 两条快路径都拿不到信号 ⇒ 桥唯一能用的判据就是**空闲超时**，
而当时部署值是 45 s（仓库 unit 写的是 300 s，**两份还漂移**）。

## 处置（本轮已做）

- `rootfs/debian/ime/elden-ime-focusd.service`：`ELDEN_IME_IDLE_SEC` 300 → **4 s**（设备上原为 45 s，已同步）；
- focusd 源码两处：零矩形确认 2 s → **400 ms**、`idle_check` 轮询 1 s → **250 ms**；
- 新增 `composing` 判定（`SetLookupTable` 非空 / `UpdatePreeditText` 非空）：组字期间空闲阈值 **+16 s**，
  **有界**——否则 Firefox 不给 blur 时键盘会永久悬浮。
- 判据：同一脚本复测 42 991 ms → **2 183 ms**；`verify.sh --rebuildable` FAIL=0 WARN=0。

## 教训

**「反应慢」先分清是参数问题还是信号问题**：本机看起来像「阈值调大调小」，实际是**上游客户端不发事件**——
调参数只能把「永远不收」变成「N 秒后收」。凡是靠启发式兜底的桥（kimpanel→OSK），必须把
「本应用到底会不会发 blur」当作已知量写进注释，并给启发式一个**有界**的兜底（本例 4 s / 组字 +16 s）。

---

# #645 候选窗一直没有：`CurrentUI=kimpanel` 时**面板（focusd）就是唯一该画候选的人**，而它只桥 OSK

- 日期：2026-11-13
- pi 会话 id：本项目会话（11-13 上午）
- 主题：用户三连报里的第 1 条（中文能上屏但看不见组字/候选）

## 证据链

- 焦点在 Firefox URL 栏、敲 `n i` 时，`dbus-monitor` 抓到 fcitx5 在 `/kimpanel`
  （`org.kde.kimpanel.inputmethod`）**连发 `ShowPreedit` / `ShowLookupTable` / `ShowAux`** ⇒ IME 侧组字/候选都存在；
- 但屏上只有 URL 栏里的裸字母，**没有 preedit 下划线、也没有候选条**；
- 回看 2026-11-11「用户目视确认候选窗」的那张 `reports/artifacts/ime-candidates-20261111.png`：
  **其实只有 preedit `ni hao`，没有候选窗**（当时的「确认」是被 DBus 里的 `SetLookupTable` 数据误导了）。

## 机制

fcitx5 同一时刻只有一个 UI addon 生效：

- `classicui` 在 phoc 上建不出窗（`PITFALLS #619` 实测）；
- ⇒ 现役 `CurrentUI=kimpanel`，于是 **preedit 与候选都必须由 kimpanel 面板（= focusd）自己画**；
- focusd 只为「弹/收 OSK」解析了 `SetLookupTable`/`SetRelativeSpotRect`，**没有渲染任何 UI**。

## 处置（未做，待决策）

在 focusd 里补一个 GTK4 + layer-shell 的小浮条：preedit 文本 + 候选行（高亮 `UpdateLookupTableCursor`），
点选候选走 kimpanel 的 `SelectCandidate`（`libkimpanel.so` 里确有 `SelectCandidate`/`LookupTablePageUp/Down`/`TriggerProperty`）。
替代路线（成本更高）：让 fcitx5 用 `waylandim` 接管 zwp_input_method_v2（stevia 让位）+ wvkbd，
候选仍需 UI addon（classicui 那条路依旧堵着）⇒ **不值得先动**。

## 教训

**「UI 是谁」这件事必须写死在判据里**：`CurrentUI=kimpanel` 意味着「没有面板就没有任何可见反馈」，
而我们在验收时只看了 DBus 数据（`SetLookupTable` 有内容）就当成「候选窗可见」——
**可见性必须以截图为准，不能以协议数据为准**。

---

# #646 候选浮条 v1 上机失败：**layer-surface 一 map，焦点/输入上下文被打断**，页面被顶掉再回来、组字缓冲被直接提交

- 日期：2026-11-13
- pi 会话 id：本项目会话（11-13 上午）
- 主题：G1-38 候选窗的第一次真机试行（方案 A）与撤下

## 做法（已落库，代码保留）

`CurrentUI=kimpanel` 时候选/preedit 只能由面板画（`#645`）⇒ 新增两个件：
- `patches-userland/zh-ime/elden-ime-focusd.c`：把 kimpanel 收到的内容转发成自己的信号
  `org.elden.ImePanel`（`Lookup(preedit, items, cursor)` / `Show(b)` / `Spot(iiii)`）；
- `rootfs/debian/ime/elden-ime-candidates.{py,service}`：GTK4 + layer-shell 浮条，订阅上面的信号画
  「上行组字串 + 下行候选（当前项高亮）」。

**渲染本身是通的**（主机侧用 `busctl emit` 灌数据能得到正确截图：
`nihao` + `1 你 2 那 3 呢 4 能 5 年 6 宁`，第 2 项高亮）。

## 真机症状（用户实测）

「输入 `n` 的一瞬间弹出的候选窗把整个页面顶掉了，然后返回原页面；切换过程让刚刚缓冲的输入字符被直接打上屏幕。」

⇒ 后果比没有候选窗更糟：**输入被打断/误提交**。已 `disable --now`，并从 `daily-baseline.sh` 撤下（不再安装/启用）。

## 机制判断（下次重做的硬约束）

`Lookup`/`Show(true)` 走的是 `set_visible(True) + present()`，`Show(false)` 走 `set_visible(False)`
⇒ **每次组字开始/结束都会 map/unmap 一个 layer surface**。在这个合成器上（phoc 0.58 + 我们自己的 patch），
layer surface 的 map/unmap 会触发焦点重算 ⇒ 客户端的输入上下文被打断（fcitx 提交/重置组字），
表现出来就是「页面被顶掉再回来 + 缓冲字符被直接上屏」。
另外实测 fcitx5 在组字期间会穿插「空 lookup」事件，v1 因此还叠加了 show/hide 抖动。

**重做必须满足**：
- layer surface **全程 mapped**（启动即 present 一次），显示/隐藏只切 **opacity / 内容**，绝不 unmap；
- `keyboard-interactivity=none` + `gtk_window_set_focusable(False)` 之外，还要在合成器侧确认「映射新 surface 不改焦点」
   （判据 = 打字过程中 `NotifyFocusOut` 计数必须为 0）；
- 定位只用 `LayerShell.set_margin`，不要改 anchor/layer（这些在 mapped 后改也可能重排）。

## 教训

**「能画出来」≠「能用」**：主机侧灌数据渲染成功没有任何意义，UI 类改动的最小验收必须是
**真机输入不被打断**（判据：组字期间不出现 `NotifyFocusOut`、缓冲字符不被直接提交）。
先证明「新 surface 不影响焦点」再谈候选渲染。
