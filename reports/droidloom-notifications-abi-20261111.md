# droidloom 通知通道 ABI 死循环定位（静态分析，2026-11-11）

> 纯主机侧只读分析。**零设备操作、零写盘**（除本报告）。
> 现象（设备实测 2026-11-11）：user journal 无限循环两行
> `Droidloom notifications: invalid Android frame; disconnected` /
> `Droidloom notifications: Android connected`；
> 同时 `droidloom-wayland` 启动宣告 `DROIDLOOM_NOTIFICATIONS_ABI=3`。
> 结论 = 通知不可用 + 日志刷屏。

分析对象：`build/droidloom/droidloom`（工作树 @ `7072f8d`，**未修改**）。

---

## 1. 日志产出点与协议归属

### 1.1 两条日志都来自**宿主侧接收端**（`droidloom-wayland`），不是 Android 侧

| 日志原文 | 产出点 | 端 |
|---|---|---|
| `Droidloom notifications: Android connected` | `build/droidloom/droidloom/graphics/droidloom-wayland/src/notifications/mod.rs:484` | 宿主 receiver（accept 成功后立即打印，**不等 hello**） |
| `Droidloom notifications: invalid Android frame; disconnected` | `build/droidloom/droidloom/graphics/droidloom-wayland/src/notifications/mod.rs:532` | 宿主 receiver（`Peer::ingest()` 返回 `Err` 的唯一出口） |

同目录 `clipboard/mod.rs:412` 有一句**同名不同域**的 `Droidloom clipboard: Android connected`（前缀 `clipboard`），与本现象无关。

### 1.2 协议 = 私有 Unix socket + 4 字节大端长度前缀 + JSON 帧（非 D-Bus、非 binder）

- 通道号：`HostChannel.NOTIFICATIONS = 3`（`build/droidloom/droidloom/android/framework/host-channels/src/com/android/droidloom/runtime/HostChannel.java:18`）——**整条链上唯一的「3」**，见 §2.4。
- 宿主 socket 路径：`socket_path.with_file_name("notifications.sock")` ⇒ `$XDG_RUNTIME_DIR/droidloom/notifications.sock`（`graphics/droidloom-wayland/src/main.rs:3065-3066`）。
- 启动打印顺序（与设备日志逐行吻合，本身即判据）：`main.rs:3032` `DIRECT_INPUT_ABI=1` → `main.rs:3033` `HOST_CHANNELS_ABI=1` → `Bridge::start()` 内 `NOTIFICATIONS_ABI` → `main.rs:3089` `session mode:` → `clipboard/mod.rs:5` 的 `CLIPBOARD_ABI=1`。设备 journal 行序正是此序 ⇒ **设备二进制与源码同构**。

**关键结构事实（解释为何会「连上→立刻断」无限循环）**：
`mod.rs:478-487` 的 `Event::Accept` 分支**无条件**打印 `Android connected` 并覆盖 `peer`，**不做任何握手检查**；
紧接着第一条数据到达 `mod.rs:488-533`，任何 `ingest()` 错误（含 hello ABI 不匹配）都 just `peer = None` +
打印 `invalid Android frame; disconnected`。Android 侧 `NotificationBridge.java:127-131` 每 `2000 ms` 重连一次。
⇒ 两端各自都是「立即断开 + 2 s 重连」，**循环周期 = 2 s，永不自行收敛**，与实测刷屏完全一致。

---

## 2. ABI 版本号来源与帧格式逐字段比对

### 2.1 权威定义：代码内「双侧常量 + 打包硬断言」，没有单独头文件

| 侧 | 常量位置 | 值 |
|---|---|---|
| 宿主宣告 | `graphics/droidloom-wayland/src/notifications/mod.rs:82` `eprintln!("DROIDLOOM_NOTIFICATIONS_ABI=2;")` | **2** |
| 宿主入站校验 | `notifications/mod.rs:186` `Frame::Hello { abi: 2 } if !self.hello =>`（**只接 `abi == 2`**）；其余落入 `mod.rs:242` `_ => Err("invalid notification sequence")` | **2** |
| 宿主回发 | `notifications/mod.rs:499` `json!({"type":"hello","abi":2})` | **2** |
| Android 宣告 | `android/framework/droidloom-systemui/src/com/android/systemui/notifications/NotificationBridge.java:59` `Log.i(TAG,"DROIDLOOM_NOTIFICATIONS_ABI=2;")` | **2** |
| Android 入站校验 | `NotificationBridge.java:102` `hello.optInt("abi")!=2` → `throw` | **2** |
| Android 发送 | `NotificationBridge.java:89` `.put("type","hello").put("abi",2)` | **2** |
| 更新器校验 | `tools/droidloom-update/src/bundle.rs:140,141,198,415,433` | **2** |
| 包校验脚本 | `packaging/verify-bundle:24` `NOTIFICATIONS_ABI=b'DROIDLOOM_NOTIFICATIONS_ABI=2;'`；`:75` 对 **SystemUI.apk 与 `usr/bin/droidloom-wayland` 同时**断言 | **2** |
| 契约文档 | `docs/contracts/runtime-layout-v1.md:329`「Notification ABI **2** binds SystemUI and presenter」 | **2** |

**§2.1 结论：工作树里两端 ABI 全为 2，且打包链两处硬断言 2 ⇒ 源码层面无版本错配、无帧格式差异。**

### 2.2 线上编码（两侧逐字节同构）

```
[4 字节 big-endian u32 = JSON 体长度][JSON 体 UTF-8，≤131072]
```

| 环节 | 位置 | 一致 |
|---|---|---|
| 宿主收 | `notifications/mod.rs:165-175`（`u32::from_be_bytes`；`==0` 或 `>MAX_FRAME` → `Err("invalid notification frame")`；凑齐 `length+4` 才解析） | ✅ |
| 宿主发 | `notifications/mod.rs:261-265` | ✅ |
| Android 收 | `NotificationBridge.java:117-121`、`:222-227` | ✅ |
| Android 发 | `NotificationBridge.java:245-250` `out.writeInt(bytes.length)`（Java `DataOutputStream` 本身就是大端） | ✅ |
| 上限 | 两侧均 `MAX_FRAME=131072`（`mod.rs:24` / `NotificationBridge.java:36`） | ✅ |

### 2.3 帧类型表与 `Note` 字段逐字段比对

帧枚举：宿主 `#[serde(tag="type", rename_all="snake_case", deny_unknown_fields)]`（`mod.rs:141-149`）：
`hello{abi}` / `begin` / `post{notification}` / `remove{key,version}` / `end`。

| `type` | 方向 | 宿主校验 | Android 产出 | 一致 |
|---|---|---|---|---|
| `hello{abi}` | 双向各一次 | 必须 `==2`（`mod.rs:186`） | `abi=2`（`JB:89`），且要求对端 `==2`（`JB:102`） | ✅ |
| `begin` | A→H | 已 hello 且无在途 snapshot（`mod.rs:187-189`） | `JB:141` `if(initial)` 先 begin | ✅ |
| `post{notification}` | A→H | `Note::valid()`（`mod.rs:112-139`） | `JB:156` encode | ✅ |
| `remove{key,version}` | A→H | `synced` + 无在途 snapshot + 长度上限（`mod.rs:216-224`） | `JB:146-149` 先退役再新增 | ✅ |
| `end` | A→H | 必须有在途 snapshot（`mod.rs:213`） | `JB:155` `if(initial)` 末尾发 | ✅ |
| `dismiss`/`action` | H→A | `mod.rs:246-265` | `JB:207` `command()` | ✅ |

`Note`（宿主 `mod.rs:99-110` ↔ Android `NotificationBridge.java:183-196`）：

| 字段 | 宿主约束 | Android 产出 | 一致 |
|---|---|---|---|
| `key` | 1..=2048 无 NUL | `sbn.getKey()` | ✅ |
| `version` | 1..=96 | `session+"-"+(++generation)` | ✅ |
| `package` | ≤256，仅 `[A-Za-z0-9._]` | `sbn.getPackageName()` | ✅ |
| `app` | ≤1024 | `text(label,256)` | ✅（更严） |
| `title` | ≤8192 | `text(...,2048)` | ✅（更严） |
| `body` | ≤32768 | `text(...,8192)` | ✅（更严） |
| `actions[]` | `{key,label}`，key ∈ `default`\|`action-0..15`，≤17 | `default`/`action-N`(N<16)，label ≤256 | ✅ |
| `urgency` | u8 ≤2 | 0 或 1 | ✅ |
| `ongoing`/`clearable` | bool | `isOngoing()`/`isClearable()` | ✅ |
| `icon` | 空 或 **恰 48*48*4=9216** | 每次 4 B × 2304 = 9216；异常 `[]` | ✅ |

**§2.3 结论：线上编码、帧类型、字段名/类型/顺序、长度上限，两侧全部一致。**

### 2.4 唯一一个「3」：`HostChannel.NOTIFICATIONS = 3`（**不是 ABI**，但极易被误读）

| 事实 | 位置 |
|---|---|
| `public static final int TEXT_INPUT = 1, CLIPBOARD = 2, NOTIFICATIONS = 3;` | `android/framework/host-channels/src/com/android/droidloom/runtime/HostChannel.java:18` |
| `HostChannel.BUILD_ABI = "DROIDLOOM_HOST_CHANNELS_ABI=1;"`（真正的 ABI 常量紧邻上一行） | 同文件 `:17` |
| SystemUI 用它打开通知通道：`HostChannel.open(HostChannel.NOTIFICATIONS)` | `NotificationBridge.java:87` |

⇒ **「通知 = 3」在代码里指的是「第 3 号通道」，与「通知 ABI = 2」是两个不同维度的数字。**
如果设备上的二进制把「通道号」误打印成 ABI，或反过来，就会正好输出 `=3`。**这是目前唯一能从现有代码解释出「3」的路径。**

### 2.5 ★根本前提：**本地分析树 = 上游 0.1.0-25，设备装的是 0.1.0-30**（已实测比对）

| 证据 | 内容 |
|---|---|
| `build/droidloom` **不在 git 管理下** | `git check-ignore -v build/droidloom/droidloom/Cargo.toml` → `.gitignore:35:/build/`；**无任何 commit 引用它** |
| 本地有上游源码 tarball | `/var/tmp/droidloom-20261031/droidloom-source-0.1.0-25.tar.gz`（含 `droidloom/` 全树） |
| **整树逐文件比对 = 完全相同** | `diff -rq /tmp/dl-src25/droidloom build/droidloom/droidloom` → **0 行差异**；`Cargo.lock` md5 同为 `a2454873d72975a82aef5ac3e3608a63` |
| 本地有 0.1.0-25 x86_64 运行时 | `/var/tmp/droidloom-20261031/rt/usr/bin/droidloom-wayland`；`grep -ao 'DROIDLOOM_NOTIFICATIONS_ABI=[0-9]*;'` → **`=2;`**（且 `droidloom-wayland` 里**只出现一次**） |
| 设备实际装的版本 | 会话记录：`droidloom-runtime-0.1.0-**30**-aarch64.pkg.tar.zst`（4 次下载）、`droidloom-image-0.1.0-**30**-aarch64`；`.PKGINFO depend = droidloom-image=0.1.0-30`（`reports/droidloom-feasibility-20261108.md:64`） |
| 设备上的二进制 | 2026-11-05 19:47 mtime 的 `/opt/dl-test/usr/bin/droidloom-*`（`TASKS/sessions/2026-11-11-droidloom-L3-上机打通.md` 证据指针） |

**⇒ 本报告§2.1–§2.3 的全部「两侧均为 2」结论，只对「修订 25」这个快照成立**；
修订 26→30 的**源码变更本地没有**（只有二进制）。这是本轮静态分析的天花板。

### 2.6 那么「3」该归谁：三个可判定的候选（按可验证性排序）

| 候选 | 为什么可信 | 反证 / 缺口 |
|---|---|---|
| **C1（版本错配）**：修订 26–30 把**宿主端** `NOTIFICATIONS_ABI` 升到 3，而**设备上的 SystemUI（来自 image）仍是 2** | 最能解释「宿主宣告 3 + Android 发送 2 + 宿主只接 3 → 立即断开」 | 需核：修订 30 的 image 与 runtime 是否同发；`packaging/verify-bundle:24,75` 把 ABI 写死为 2 ⇒ **如果 30 真是 3，那这个 verifier 应该会拒绝打包**；需确认 30 是否仍用它 |
| **C2（代码内缺陷：按通道号打印）**：修订 26–30 把 `eprintln!` 改成引用 `HostChannel.NOTIFICATIONS`（=3）而非 ABI 常量 | 只剩 2.5 这一条路径能从现有代码解释「3」 | 与「invalid Android frame」同时发生则需另一条独立原因（除非打印与校验用了同一错误常量） |
| **C3（部分替换 / 混装）**：`/opt/dl-test` 里 `droidloom-wayland` 来自 30、而 SystemUI 来自 29 或更早 | 实验装置是手摊的（非 pacman），无法保证原子 | 两者都是 tar 一次性解包（`tar --zstd -xf /tmp/rt.pkg.tar.zst`），理论上原子；但 image 与 runtime 是**两个独立包**，混装完全可能 |

**已排除**：帧格式差异（§2.2/2.3 已逐字节一致）、长度/上限差异、字段名差异、socket 路径差异、UID 鉴权差异
（宿主 `authenticated_peer()` 要求 peer uid 匹配，否则**不打印 connected**；既然 device 打印了 connected，鉴权是过的）。

---

## 3. 根因假设（按概率）与单次验证方法

### 3.0 先立一个「交换机」判据（两个假设的预测**不同**，这是本轮最有用的产出）

由代码流程可知一个不对称事实：

- 宿主 `serve()` **不在 accept 时发 hello**；它只在 `ingest()` 成功解出 `hello` 之后才回发（`mod.rs:491-499`）。
- 所以 ABI 不匹配时，**总是宿主先判错、先断**：`mod.rs:186` 的 `Frame::Hello { abi: 2 }` 模式不匹配 ⇒ `mod.rs:242` `_ => Err` ⇒ `mod.rs:531-533` 打印 + `peer = None`。
- Android 侧感知 = 它的 `input.readInt()` 拿到 0/EOF ⇒ `NotificationBridge.java:126-127` 打 `Notification transport disconnected: …`。

### 3.0b ★另一个硬证据：0.1.0-25 的打包校验器会**拒绝**一个 `=3` 的构建

`packaging/verify-bundle:24` 把通知 ABI 写死成 **`=2;` 的子串硬断言**，而 `:75-77` 对
**SystemUI.apk 与 `usr/bin/droidloom-wayland` 两边同时**执行 `if any(NOTIFICATIONS_ABI not in data …) → raise`。
注意 `:27-30` 的 `abi()`（能抽取数字的宽松检查）**只用于 `DROIDLOOM_INPUT_ABI`**（`:13` MARKER、`:48`、`:67`），
通知 ABI **没有**走宽松路径。

⇒ **推论（可一步验证）**：若出版包 0.1.0-30 的宿主二进制真的是 `=3`，那么 **与 30 同修订的 `verify-bundle` 必然已不再硬断言 2**（否则发不出去）。
因此「那个 verifier 在 30 里改成什么」直接决定 §3.1 还是 §3.2：

```bash
# 拿 0.1.0-30 的 runtime 包（含 usr/bin/droidloom-wayland）跑 25 的 verifier：
#   它一定会失败（因为写死 2）⇒ 不验证任何事
# 真正要拿的是 30 自带的 packaging/verify-bundle 文本（GitHub tag/commit）
curl -s https://raw.githubusercontent.com/denialwm/droidloom/<30的commit>/packaging/verify-bundle | grep -n 'NOTIFICATIONS_ABI'
```

### 3.0c 设备侧第一步判据：抓宿主与 Android 两侧日志（不需要改任何代码）

```
journalctl --user -u droidloom -n 50            # 宿主：只看 Droidloom notifications: …
logcat -d -s DroidloomNotifications              # Android：TAG 在 NotificationBridge.java:33
```

| 观察到的组合 | 指向 |
|---|---|
| 宿主 `invalid Android frame` + Android **`Notification transport disconnected: IllegalArgumentException`**（来自 `JB:102` 的抛异常） | **A / C**：帧确实来自一个发 `hello.abi≠2` 的发送端 |
| 宿主 `invalid Android frame` + Android **无异常类型 / 仅 EOF、SocketException** | **B**：宿主用于校验的不是 `abi==2`（若打印与校验同源，就是 3） |
| Android 根本没打 `DROIDLOOM_NOTIFICATIONS_ABI=2;` | 桥未启动（与宿主断连无关）⇒ 另一个问题 |

### 3.1 假设 A（估 60%）：修订 26–30 把宿主侧 ABI 升到 3，设备 image 的 SystemUI 仍为 2——**订版混装/版本错配**

**依据**：
- 设备宣告 3（二进制真实存在），而**本地可验证的两个快照（源码 25 + 二进制 25）都是 2** ⇒ 3 只能是 26–30 新增的。
- `docs/INSTALL.md:45` 要求「Both packages are required and must have the **same version and release**」⇒ 上游自己把「runtime 与 image 必须同版」当作硬前提。
- §2.1 的 `verify-bundle:24` 写死 2 ⇒ 若 30 仍用它，30 内部就应同为 2；反之若 30 变成 3，则 image 也必须同步。

**若成立应看到的额外现象**：
1. Android 侧 logcat 有 `Notification transport disconnected: IllegalArgumentException`（来自 `JB:102` 的 `throw new IllegalArgumentException()`）。
2. **其他通道全部正常**（`DROIDLOOM_HOST_CHANNELS_ABI=1`、`CLIPBOARD_ABI=1`、输入、`applications`）——因为只有通知这一个 ABI 被提升。实测正是如此。
3. `Droidloom notifications: session bus disconnected; retrying`（早前无 DBus 时）与 `invalid Android frame` **不同时出现**：前者是 `run()` 返回 `Err` 后 `mod.rs:58-62` 的重试打印，后者是 `ingest()` 返回 `Err` 后的 `mod.rs:531-533`，分属两个不同分支。

**一次验证**：
```bash
# ① 直接从设备上那个二进制里读常量（不改任何东西）
strings -a /opt/dl-test/usr/bin/droidloom-wayland | grep -o 'DROIDLOOM_NOTIFICATIONS_ABI=[0-9]*;'
# ② 从已展开的 image 里读 SystemUI 的常量
grep -ao 'DROIDLOOM_NOTIFICATIONS_ABI=[0-9]*;' \
  /opt/dl-test/usr/lib/droidloom/images/images/system.img 2>/dev/null || \
  echo 'system.img 是 erofs/ext4 ⇒ 需先 mount 或 debugfs 抽 SystemUI.apk'
```
若 ① `=3` 且 ② `=2` → **假设 A 成立**，结论 = 订版混装。

### 3.2 假设 B（估 35%）：代码内缺陷——打印与校验引用了错误常量（「通道号 3」 vs 「ABI 2」）

**依据**：`HostChannel.java:18` 里 `NOTIFICATIONS = 3` 与 `:17` 的 `BUILD_ABI` 相邻；
`socket_path.with_file_name("notifications.sock")` 在 `main.rs:3065` 是**按名字**取的，不依赖通道号，
所以「3」在此代码里**只可能**来自通道号。若修订 26–30 把 `eprintln!` 重构为「引用一个共享常量」且误取了通道号：
- 打印变 3（与实测一致）；
- 如果同一个错误常量同时进了 `Frame::Hello { abi: 2 }` 的模式位置，则**两端都发 3 也可能互相拒绕**（取决于改的是哪一侧）。

**若成立应看到的额外现象**：
1. Android 侧 **无** `IllegalArgumentException`（因为它发 2、宿主也发 3 → 它自己也会 throw；若两侧都改 3 则反而能通）
2. 修一行常量即通，与 image 版本无关。

**一次验证**：
```bash
# 把宿主二进制里所有 ABI 常量与它自己打印的那行放一起看：
strings -a /opt/dl-test/usr/bin/droidloom-wayland | grep -o 'DROIDLOOM_[A-Z_]*=[0-9]*;' | sort -u
```
再看 `DROIDLOOM_HOST_CHANNELS_ABI=1;` 的**邻接字符串**里是否出现 `TEXT_INPUT/CLIPBOARD/NOTIFICATIONS`
（在 0.1.0-25 的 x86 二进制里，`NOTIFICATIONS_ABI=2;` 的邻接是 `droidloom-notifications`，见 §2.5）；
若 30 里邻接出现 `notifications`+`3` 共存且无 `=2`，则高度指向 B。

### 3.3 假设 C（估 5%，但最便宜排除）：**两个包本身就不是同一修订**

`/opt/dl-test` 是**手摊**（`tar --zstd -xf /tmp/rt.pkg.tar.zst`），不是 pacman，`depends=droidloom-image=0.1.0-30` **不会被强制执行**。
若 image 当初拿的是 29 而 runtime 是 30（或反之）就会出现与 A 完全相同的现象但根因不同：

```bash
# 一次验证：两侧 PKGINFO 都在盘上（附 `.PKGINFO` 没被删的话）
cat /opt/dl-test/.PKGINFO 2>/dev/null | grep -E 'pkgver|depend'
# 没留着就逐文件 sha 比：拿宿主上已下的 30 包内 usr/bin/droidloom-wayland 与设备上那个比
sha256sum /opt/dl-test/usr/bin/droidloom-wayland
```

### 3.4 三个假设的区分矩阵（一次实验即可分完）

| 观察量 | A 显式 3/2 | B 常量误用 | C 包混装 |
|---|---|---|---|
| 宿主二进制 strings 中 `NOTIFICATIONS_ABI` | `=3`（单一） | `=3` 但邻接出现通道号域 | 同 A |
| image 内 SystemUI 的 `NOTIFICATIONS_ABI` | `=2` | `=2`（正常） | 与 runtime **不同修订** |
| Android logcat 异常类型 | `IllegalArgumentException` | 无 / EOF | 同 A |
| `.PKGINFO` 两包 pkgver | 同为 30 | 同为 30 | **不同** |

---

## 4. 结论：版本错配还是代码内缺陷

### 4.1 先回答题目间的两个问题

**问题 1：两端帧格式是否一致？**——**一致，且已被逐字节证明**（§2.2 编码、§2.3 帧类型 + `Note` 11 个字段、§2.5 整树 0 差异）。
**所以「帧格式不懂」不是原因；唯一对不上的只有「hello 帧里的 `abi` 数字」。**

**问题 2：本地源码能不能证明原因？**——**不能，且原因已定位到证据边界**：
`build/droidloom/droidloom` 与上游 `0.1.0-25` **整树完全相同**（§2.5，`diff -rq` 0 行），
而设备装的是 **0.1.0-30**。⇒ **报告的「3」发生在本仓库没保存的修订 26–30 区间里**，
本地源码与本地 x86 二进制都只会打印 2。这是静态分析在本仓库里的硬上限。

### 4.2 判定

| 结论 | 证据 |
|---|---|
| **不是「帧格式/协议实现」缺陷** | §2.2 / §2.3 逐字段全一致；且 0.1.0-25 的同一份代码在同一台设备上（x86 实测）打印 2 |
| **是「宿主运行的那份二进制」与「本仓源码快照」不同修订** | §2.5：整树 = 25，设备 = 30 |
| **最可能：版本错配（A，60%）**，次要：代码内常量误用（B，35%） | §3.1 / §3.2 |
| **直接可试的绕行**（不需重装）：把宿主换成与 image 同修订的 runtime；若 image 是 30、runtime 也是 30，则需按 §3 一步判据确认后再定向 | 见 §4.3 |

### 4.3 必须同装的版本组合（回答题目第 4 问）

**上游硬契约**：`docs/INSTALL.md:45`「Both packages are required and must have the **same version and release**」。

| 证据源 | 当前值 |
|---|---|
| 工作区 crate 版本（全 workspace 同一） | `Cargo.toml:41` `version = "0.1.0"`（所有 crate 用 `version.workspace = true`，如 `graphics/droidloom-wayland/Cargo.toml:4`） |
| 打包修订号来源 | `packaging/arch/PKGBUILD.in:4-5` `pkgver=@VERSION@` / `pkgrel=@RELEASE@`（由打包脚本注入，**源码树里不写死**） |
| 设备实际组合 | `droidloom-runtime-0.1.0-**30**-aarch64` + `droidloom-image-0.1.0-**30**-aarch64`（会话记录，且 `runtime .PKGINFO` 有 `depend = droidloom-image=0.1.0-30`） |
| 本地可验证的参照组 | `0.1.0-**25**`（源码 + x86_64 runtime，**两者均 `ABI=2`，自洽**） |

**⇒ 必须同装的组合**：

1. **首选 = (runtime, image) 同为 `0.1.0-30`** —— 设备当前**已经是这个组合**（按会话记录）。
   如果 §3 的判据显示 runtime 里是 `=3` 而 image 里是 `=2`，
   **那就说明上游 0.1.0-30 自己就是不自洽的** ⇒ 属上游缺陷，应降级到 **`0.1.0-25` 自洽组**。
2. **降级对照组 = `0.1.0-25`（runtime + image 同时降）** —— 本地有源码 + x86 二进制双证 `ABI=2`，且
   `verify-bundle:24,75` 会把「SystemUI 与 presenter 都是 2」当硬门（即 25 的包能过这个门）。
   注意：降级要**两个包一起降**，否则就是 §3.3 的 C 场景。
3. **自建**：本地 `build/droidloom/droidloom` 就是 25 的完整树，可直接产出 25 的 aarch64 runtime，
   但 image 需同步（`tools/droidloom-image`，见 `docs/BUILDING.md`）。**本轮未做构建**。

### 4.4 未完成项（静态分析的边界，需设备侧一步确认）

1. **0.1.0-30 的源码未取得**（本仓只有 25；`build/` 被 `/build/` 忽略，不入库）
   ⇒ 无法从源码确认 26–30 是否升了 ABI。「上游 30 是否 `=3`」**待核**。
2. **`/opt/dl-test` 与 image 里的 `system.img` 未取回** ⇒ 「image 那侧 SystemUI 是 2 还是 3」**待核**（§3.1 的 `strings`/`grep -ao` 两步从未在设备上跑过）。
3. **Android 侧 logcat 从未采集** ⇒ 无法区分 A / B（§3.4 判别矩阵第一行已给出两条命令）。
4. 本报告**没有**验证「宿主自己是否也发 abi=3」——这需要 §3.1 的 `strings` 或抓 socket 字节（`socat`/`strace`）；
  从 25 的代码推断是「只在收到 hello 后才回发」（`mod.rs:495-499`），所以 **A 与 B 在 25 上无法重现**。
5. 未评估 `packaging/verify-bundle` 在 30 上是否仍断言 2 —— 若仍然是，则 §4.3 的「30 自不自洽」可用该脚本一次判定
   （拿解包的 30 运行 `python3 packaging/verify-bundle <root>`）。

---

**一句话结论**：两端帧格式与 ABI 常量在本地可验证的快照（上游 **0.1.0-25**，与本仓 `build/droidloom` **整树完全相同**）里**完全一致且同为 2**；
设备宣告的 **3** 只可能来自本仓**未保存的修订 26–30**，而「通知=3」在本代码里唯一能解释为数字的是
`HostChannel.NOTIFICATIONS = 3`（通道号）。
**最可能是版本错配（宿主与 image 非同修订，60%），其次是代码内常量误用（35%）**；
**必需组合 = runtime 与 image 同 `pkgver-pkgrel`（现为 `0.1.0-30`；不自洽则双双降到自洽的 `0.1.0-25`）**。

DONE
