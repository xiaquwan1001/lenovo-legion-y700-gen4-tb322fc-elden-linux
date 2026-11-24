# Rime completer 的 user-data：真因、`deployment_tasks.cc:90` 语义、修复与免触摸验证（2026-11-24 D3 主机侧）

> lane D3（**主机侧定因，零设备接触**：本报告所有命令都在本机跑，未 ssh/adb/fastboot）。
> 设备侧现态由主会话提供：Debian trixie / phosh+phoc+phosh-osk-stub **0.46.0** / 我方 B 案的件已部署
> （`/usr/bin/phosh-osk-stub` md5 `2c040ca717084f04a3abc85bafb113fd`、origin 件已 divert）。
> 上游基线两份，均可复现下载：librime **1.13.1**（= 设备 `librime1t64 1.13.1+dfsg1-1`，
> `codeload.github.com/rime/librime/tar.gz/refs/tags/1.13.1`，本机解包在 `/tmp/librime-1.13.1`）、
> librime 1.16.1（本机 `/usr/lib/x86_64-linux-gnu/librime.so.1.16.1`，作行为对照）。
> 所有外部命令带 `timeout -k`。

---

## 0. 一页结论

**真因（一句）**：`sm.puri.phosh.osk.Completers.Rime` 的 `user-data` 默认值是**空串**，我们的 completer 把空串**原样**塞进
`RimeTraits.user_data_dir`（`pos-completer-rime.c:356,361`），librime 把「非 NULL 空串」当成**合法但为空的路径**
（`RIME_PROVIDED` 只判非 NULL，`rime_api.h:74-75`）⇒ 部署任务 `InstallationUpdate` 里
`fs::create_directories("")` 必然失败 ⇒ 每发一次 `deployment_tasks.cc:90 Error creating user data dir:`（**冒号后为空**正是空路径指纹）。

| # | 问题 | 结论 | 证据 |
|---|---|---|---|
| **1** | user/shared data dir 怎么决定 | `g_settings_new("sm.puri.phosh.osk.Completers.Rime")` 读三键 → 原样赋给 `RimeTraits.{shared,user}_data_dir`，**不做空值/默认目录兜底** | `pos-completer-rime.c:349,355-357,360-361`；补丁同名 hunk `0003-…-wiring.patch:497,504,508-509` |
| **2** | gschema 有没有定义三类键 | **定义了**（`<schema id='sm.puri.phosh.osk.Completers.Rime'>`，含 `shared-data`/`user-data`/`schema`）。`gsettings list-recursively sm.puri.phosh.osk.Completers` 只列 `default` 是**正常行为，不是缺键**：GLib 只把「键名以 `/` 结尾」的**可重定位子 schema** 当 children，而我们是**独立 schema id + 自带 `path=`**，永远不会出现在父 schema 的列表里 | `out/osk-stub-rime-20261123/sm.puri.phosh.osk.gschema.xml:92-112`；GLib `gio/gsettings-tool.c:271-305`（`list_recursively`→`g_settings_list_children`）+ `gio/gsettingsschema.c:1085-1109`（只收 `key` 以 `/` 结尾者）；本机实测见 §2 |
| **3** | `deployment_tasks.cc:90` 是哪一步、判据 | librime **1.13.1** `src/rime/lever/deployment_tasks.cc:82-92` 的 `InstallationUpdate::Run()`（`RimeStartMaintenance` 的**第一个**任务）。判据 = `!fs::exists(user_data_path)` → `fs::create_directories(user_data_path, ec)` 返回 false → 打该 ERROR（`deployment_tasks.cc:86-91`） | §3 |
| **4** | 这错 == 候选为空？ | **不等价**。librime 1.13.1（真机同版本）实测：`user_data_dir=""` 时**这条 ERROR 照出，`nihao` 仍出 5 个候选**（`你好/妳好/逆號/擬好/你`）——候选来自 `librime-data` 预编译的 `/usr/share/rime-data/build/*.bin`（`FallbackResourceResolver` 回退，`src/rime/resource.cc:36-45`）。它真正破坏的是**用户词典/用户定制/installation_id 持久化**，并把产物写进**进程 cwd** | §3.3 三段对照实验 |
| **5** | 修法 | 一条 `install -d` + 一条 `gsettings set` + 让 osk-stub 重建。**零重编、幂等、可回退** | §4 |
| **6** | 免触摸验证 | ①`gsettings` 直接读三键；②journal 计数；③`~/.local/share/rime/build` 文件数 + 用户词典 `LOCK` 被 osk-stub 持有；④**可选**：`reports/rime-completer-probe-20261124.c`（aarch64 探针，同 1.13.1，输出候选文本）。**只有「屏上候选条/选词」需人手** | §5 |

**与并行产出的差异（请主会话裁决，不擅自改他人报告）**：`reports/d3-rime-ondevice-20261124.md` §0 把该日志直接写成
「⇒ 用户词典/部署从未建成 ⇒ **候选空**」。§3.3 的 1.13.1 复现说明**「候选空」这一步推不出来**（空 user dir 下候选照样有）。
该报告的**修复动作与修复后证据仍然成立且正确**，只是「换固定因」缺一条隔离实验。

---

## 1. Q1：B 案补丁里 user/shared data dir 是怎么决定的（file:line）

**源码**（仓内交付件，只读）：`patches-userland/zh-ime-rime-20261123/rime/pos-completer-rime.c`

```c
349:  self->settings = g_settings_new ("sm.puri.phosh.osk.Completers.Rime");
355:  shared = g_settings_get_string (self->settings, "shared-data");
356:  user   = g_settings_get_string (self->settings, "user-data");
357:  schema = g_settings_get_string (self->settings, "schema");
359:  RIME_STRUCT_INIT (RimeTraits, traits);
360:  traits.shared_data_dir = shared;
361:  traits.user_data_dir  = user;        /* ← 空串原样传出，无兜底 */
369:  self->api->setup (&traits);
370:  self->api->initialize (&traits);
371:  if (self->api->start_maintenance (True))
372:    self->api->join_maintenance_thread ();
374:  self->sid = self->api->create_session ();
380:  if (schema && *schema && !self->api->select_schema (self->sid, schema))
```

**接线补丁**（同一逻辑在交付 diff 里的行号）：`rime/0003-osk-stub-rime-completer-wiring.patch:497`（`g_settings_new`）、
`:504`（读 `user-data`）、`:508-509`（赋给 traits）、`:519`（`start_maintenance`）。

**gschema 定义**（交付件 `out/osk-stub-rime-20261123/sm.puri.phosh.osk.gschema.xml`）：

```
92:  <schema id='sm.puri.phosh.osk.Completers.Rime'
93:          path='/sm/puri/phosh/osk/completers/rime/'>
94:    <key name='shared-data' type='s'><default>'/usr/share/rime-data'</default>   # 93-99
100:   <key name='user-data'   type='s'><default>''</default>                       # 100-105 ← 坑源
106:   <key name='schema'      type='s'><default>'luna_pinyin'</default>            # 106-111
112:  </schema>
```

三点说明：
1. `shared-data` 默认 `/usr/share/rime-data`，与设备实际数据目录一致 ⇒ **不需要改**（仍建议显式 set，见 §4，纯幂等/自文档）。
2. `user-data` 默认 `''`，`<summary>` 还写着「Empty disables the user dictionary」——**这句是错的**：空串并不会「关掉用户词典」，
   而是让 librime 的**部署链整体退化**（§3.2），必须改成「空 ⇒ 用 XDG 默认目录」并加兜底（§6 技术债）。
3. 与上游一致性：同文件里 `sm.puri.phosh.osk.Completers`/`.Pipe`（`:71-90`）也是「独立 schema id + 自己的 `path=`」，
   我们的 `Completers.Rime` 与它们**同构**，没有引入新范式。

---

## 2. Q2：三类键在不在？为什么 `list-recursively` 看不到（本机实测）

### 2.1 实测（本机 glib 2.88.0，与设备 trixie 的 glib 同代；用交付件 + 上游生成件原样编译）

```sh
$ mkdir -p /tmp/gschemas
$ cp out/osk-stub-rime-20261123/sm.puri.phosh.osk.gschema.xml /tmp/gschemas/
$ cp /tmp/osk-build/data/sm.puri.phosh.osk.enums.xml       /tmp/gschemas/   # 上游 mkenums 生成的 flags 定义
$ glib-compile-schemas /tmp/gschemas && export GSETTINGS_SCHEMA_DIR=/tmp/gschemas

$ gsettings list-recursively sm.puri.phosh.osk.Completers
sm.puri.phosh.osk.Completers default ''
                                          # ← 与设备观测完全一致：只有 default
$ gsettings list-recursively sm.puri.phosh.osk.Completers.Rime
sm.puri.phosh.osk.Completers.Rime schema 'luna_pinyin'
sm.puri.phosh.osk.Completers.Rime shared-data '/usr/share/rime-data'
sm.puri.phosh.osk.Completers.Rime user-data ''          ← 三键都在，值就是空串
$ gsettings get sm.puri.phosh.osk.Completers.Rime user-data
''
$ gsettings list-schemas | grep phosh.osk
sm.puri.phosh.osk
sm.puri.phosh.osk.Completers
sm.puri.phosh.osk.Completers.Pipe
sm.puri.phosh.osk.Completers.Rime      ← 我们的 schema 是**独立 id**
```

### 2.2 为什么「父 schema 的 list-recursively」看不到它（GLib 源码判据）

- `gsettings list-recursively <SCHEMA>` 走 `gio/gsettings-tool.c:271` `list_recursively()` → `g_settings_list_children()`
  → `g_settings_schema_list_children()`。
- `gio/gsettingsschema.c:1085-1109`：**只把「键名以 `/` 结尾」的条目**当 children 返回。这种条目只由
  **可重定位子 schema**（父 schema 里 `<child name='X'/>`）产生。
- 我们是 `path=` 型（非 relocatable）**独立 schema id**，GLib 不会把它挂在 `sm.puri.phosh.osk.Completers` 名下。

⇒ **结论：设备上那条观测是误判对象（查了父 schema），不是「缺键」也不是「没跑 `glib-compile-schemas`」。**

### 2.3 怎么确证「原件在设备上已编译生效」（不用改任何东西）

```sh
# 以会话用户 + 会话总线查（否则 dconf 后端缺失，只能读到默认值 —— 会误导）
su -l xuqianhui1001 -c 'XDG_RUNTIME_DIR=/run/user/1001 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
  gsettings list-recursively sm.puri.phosh.osk.Completers.Rime'
# 期望：三行（schema/shared-data/user-data），user-data 现为 '' 或已是 /home/xuqianhui1001/.local/share/rime
```
另一条硬证据：**osk-stub 每发都打 `deployment_tasks.cc:90`** ⇒ 它已经成功走到 `g_settings_new("…Completers.Rime")`
之后的 librime `setup/initialize`（`pos-completer-rime.c:349→369`）。若 schema 未编译，`g_settings_new` 会直接
`g_error` 崩掉（"Settings schema … is not installed"），根本不会有 librime 日志——**所以「没重跑 glib-compile-schemas」这一假设被日志本身排除**。

> 签发新 gschema 时才需要重跑：`glib-compile-schemas --dry-run --strict /usr/share/glib-2.0/schemas/`（只读校验；
> 注意该目录里 `sm.puri.phosh.osk.enums.xml` 是 `flags=` 定义的来源，缺它则整文件被 GLib 忽略，我在本机复现过这条报错）。

---

## 3. Q3：`deployment_tasks.cc:90` 是哪一步、何时打、是否等于「候选空」

### 3.1 代码（librime 1.13.1 原样）

`src/rime/lever/deployment_tasks.cc:82-92`（`InstallationUpdate::Run()`）：

```cpp
82: bool InstallationUpdate::Run(Deployer* deployer) {
83:   LOG(INFO) << "updating rime installation info.";
84:   const path& shared_data_path(deployer->shared_data_dir);
85:   const path& user_data_path(deployer->user_data_dir);
86:   if (!fs::exists(user_data_path)) {
87:     LOG(INFO) << "creating user data dir: " << user_data_path;
88:     std::error_code ec;
89:     if (!fs::create_directories(user_data_path, ec)) {
90:       LOG(ERROR) << "Error creating user data dir: " << user_data_path;   // ← 设备日志这一条
91:     }
92:   }
93:   path installation_info(user_data_path / "installation.yaml");
...
159:   return config.SaveToFile(installation_info);
160: }
```

调用链（同一版本源码）：

```
RimeStartMaintenance(full_check=True)            src/rime_api_impl.h:65-89
  └ LoadModules(kDeployerModules)                 setup.cc:28
  └ RunTask("clean_old_log_files")                rime_api_impl.h:68
  └ RunTask("installation_update")                 rime_api_impl.h:69  → deployment_tasks.cc:82 InstallationUpdate::Run
  └ ScheduleTask("workspace_update"/"user_dict_upgrade"/"cleanup_trash") + StartMaintenance
```

`user_data_dir` 的来源（为何是空串而不是默认目录）：

```cpp
src/rime/setup.cc:46-49   SetupDeployer():  if (RIME_PROVIDED(traits, user_data_dir))
                                             deployer.user_data_dir = path(traits->user_data_dir);
src/rime_api.h:74-75      RIME_PROVIDED(p, member)  ((p) && RIME_STRUCT_HAS_MEMBER(*(p), (p)->member) && (p)->member)
src/rime/deployer.cc:15-24 Deployer() 默认 shared_data_dir("."), user_data_dir(".")  ← 只有「NULL 不传」才留默认
```
（`fs` = `std::filesystem`：`src/rime/lever/deployment_tasks.cc:32 namespace fs = std::filesystem;`，1.13.1 已不用 boost）

⇒ **判据就是「指针非 NULL」**：我们传的是 `""`（非 NULL）⇒ `RIME_PROVIDED` 为真 ⇒ `user_data_dir = path("")`（空路径），
不是「不提供」，所以既没走默认值也没报「未设置」。空路径下 `fs::exists("")==false`、`fs::create_directories("")==false`
⇒ 必打 :90 且**冒号后为空**（与设备 journal 逐字吻合）。

### 3.2 这条错误往下会坏什么（源码级）

| 影响面 | 机理（1.13.1 file:line） | 后果 |
|---|---|---|
| 部署链继续跑 / 或整体中止 | `installation_update` 若是**唯一**失败点，`RimeStartMaintenance` 仍返回 True 继续调度后续任务；但 `:159 return config.SaveToFile("installation.yaml")` 在 cwd **不可写**时返回 false，`rime_api_impl.h:69-71` 直接 `return False` ⇒ `workspace_update` 等**全部不执行** | cwd 可写（桌面用户 HOME）时：**候选不受影响**；cwd 不可写（如 `cwd=/`）时：`start_maintenance` 返回 0，预设二进制符号链接/用户词典升级全跳过（**候选仍然可用**，见 §3.3） |
| 产物落点 | `setup.cc:63-67`：`prebuilt_data_dir = shared/build`、`staging_dir = user_data_dir/build` ⇒ **相对的 `build`（挂在进程 cwd 上）** | `installation.yaml`、`build/`、`<schema>.userdb/`、`user.yaml` 全写进 osk-stub 的 **cwd**（本机实测：4 项都在 cwd 里落地），用户词典**跟着 OSK 进程的 cwd 漂** |
| 用户定制/用户词典 | 用户词典目录 = 空路径 ⇒ LevelDB 落在 cwd；`user.yaml`（`simplification` 之外的持久选项、用户词频）不在用户目录 | 学词可能「看起来生效但换个 cwd 就没了」；`installation_id` 每次启动重生成（同步/多端合并语义失效） |

### 3.3 是否等价于「候选为空」—— **不等价**（三段对照实验，librime **1.13.1 arm64** 实跑）

装置：`reports/rime-completer-probe-20261124.c`（复刻 `pos-completer-rime.c:349-382` 的初始化顺序；只判 librime，不经 OSK）。
交叉编译用的是**设备同版本**库与头（`/tmp/rimewrap/arm64root/usr/lib/aarch64-linux-gnu/librime.so.1.13.1`）＋ trixie sysroot，
`qemu-aarch64 -L /tmp/trixie-sysroot/root` 执行；rime 数据用本机 `librime-data`（arch: all，与设备同包）。

| 场景 | cwd | user_data_dir | `start_maintenance` | journal 错 | `nihao` 候选 |
|---|---|---|---|---|---|
| A 现态（复现设备） | 可写空目录 | `""` | 1（True） | **有** | **5 个：你好/妳好/逆號/擬好/你** |
| B 修复态 | 任意 | `/tmp/…/rime` | 1 | 无 | 5 个（同上） |
| C 现态 + cwd 只读（最坏） | `chmod 555` | `""` | **0（False）** | **有**（+`failed to save config`/`userdb` 打不开/`Missing ascii bindings`） | **5 个（同上）** |

```text
# A 场景原始输出（qemu-aarch64 + librime 1.13.1 arm64）
E20261124 16:10:54.475883 2939892 deployment_tasks.cc:90] Error creating user data dir:
user_data_dir=[]
start_maintenance(True) = 1
create_session = 136876135118384
select_schema(luna_pinyin) = 1
preedit=[ni hao] num_candidates=5
  cand[0]=你好 …
```
机理：候选来自 `librime-data` **预编译**的 `/usr/share/rime-data/build/luna_pinyin.{prism,table,reverse}.bin`，
而 `DictionaryComponent` 用的是 `CreateDeployedResourceResolver` = `FallbackResourceResolver(staging="build" → prebuilt=/usr/share/rime-data/build)`
（`src/rime/service.cc:181-187`、`src/rime/dict/dictionary.cc:394-401`、`src/rime/resource.cc:36-45`）；`/usr/share/rime-data/build` 命中 ⇒ 词典可用。
用户目录只影响**用户层**（用户词典/用户定制/installation_id）。

> 因此：**「日志里天天报这条错」与「候选是否有内容」是两个独立判据。**
> 若设备上确实观测到「候选条为空」，须另找原因（依次排除：`sm.puri.phosh.osk completion-mode` 是否含 `manual`
> ——PITFALLS #709 记 0.46 无 `always`；OSK 是否实际调用了 `feed_symbol`；`rime.completer` 的 `name` 匹配；
> `Completers default` 是否真是 `rime`）。本报告的修复**仍然是必须做的**（用户词典/产物落点/installation_id），
> 但不要把它当「候选空」的唯一解释。

---

## 4. Q4-A：设备侧修复命令序列（幂等、每条可回退）

设备：`ssh elden-root`（root）/ 桌面用户 `xuqianhui1001`（uid 1001，`HOME=/home/xuqianhui1001`）。全部命令带 `timeout -k`。

```sh
# 约定：USER=xuqianhui1001 / UID_=1001 / RIME_USER=/home/xuqianhui1001/.local/share/rime
# 会话总线前缀（改/读 dconf 必须带，否则只是读默认值）
ASUSER='setpriv --reuid=1001 --regid=1001 --init-groups env \
        HOME=/home/xuqianhui1001 XDG_RUNTIME_DIR=/run/user/1001 \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus'
```
> `ASUSER` 在**本机 shell**里定义（下面每条命令的 ssh 参数中它先由本机展开再远端执行）。
> 等价写法：`su -l xuqianhui1001 -c 'XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus …'`。

### 0) 只读基线（先留证据，便于回退）

```sh
timeout -k 5 20 ssh elden-root "$ASUSER gsettings get sm.puri.phosh.osk.Completers.Rime user-data"
timeout -k 5 20 ssh elden-root "journalctl _COMM=phosh-osk-stub -b --no-pager | grep -c 'Error creating user data dir'"
timeout -k 5 20 ssh elden-root "ls -la /home/xuqianhui1001/installation.yaml /home/xuqianhui1001/build /home/xuqianhui1001/user.yaml 2>&1 | head"
#   ↑ 现态下 librime 把产物写在 OSK 进程 cwd（通常就是 HOME）——本轮**只登记不建议删**，删前先比对 mtime
```

### 1) 建用户目录（幂等）

```sh
timeout -k 5 20 ssh elden-root "install -d -o 1001 -g 1001 -m 755 /home/xuqianhui1001/.local/share/rime"
# 回退：rmdir（非空则先清）——见 §4 末尾统一回退
```

> 注意现机已知坑：`/home/xuqianhui1001/.local` 可能是 `root:root`（重建根遗留）。`install -d` 只修叶子目录
> `…/.local/share/rime` 的属主；若 `install` 报 EACCES，则**不要**顺手 `chown -R ~`，只补
> `chown 1001:1001 /home/xuqianhui1001/.local/share /home/xuqianhui1001/.local`（这两级属重建根动作，主会话知会后再做）。

### 2) 三个配置键显式落值（幂等；一条命令三条 set）

```sh
timeout -k 5 30 ssh elden-root "$ASUSER gsettings set sm.puri.phosh.osk.Completers.Rime user-data /home/xuqianhui1001/.local/share/rime"
timeout -k 5 20 ssh elden-root "$ASUSER gsettings set sm.puri.phosh.osk.Completers.Rime shared-data /usr/share/rime-data"
timeout -k 5 20 ssh elden-root "$ASUSER gsettings set sm.puri.phosh.osk.Completers.Rime schema luna_pinyin"
# 核对：
timeout -k 5 20 ssh elden-root "$ASUSER gsettings list-recursively sm.puri.phosh.osk.Completers.Rime"
# 回退：$ASUSER gsettings reset sm.puri.phosh.osk.Completers.Rime user-data   （回到 ''，即旧行为）
```

### 3) gschema 无需重做（除非改过 xml）

现机 schema 已编译且被 osk-stub 读到（§2.3 判据）。**若将来换了 gschema 文件**才执行：

```sh
timeout -k 5 60 ssh elden-root "glib-compile-schemas --dry-run --strict /usr/share/glib-2.0/schemas/ ; \
                               glib-compile-schemas /usr/share/glib-2.0/schemas/"
# 回退：把 xml 换回备份件后重跑同一条 glib-compile-schemas
```

### 4) 让 osk-stub 用新配置重建（**正确方式**：只杀进程，让 phosh 按需拉起）

```sh
# 现状：phosh 直接 exec /usr/bin/phosh-osk-stub --allow-replacement（无 systemd unit）
#       所以不要 systemctl --user restart（会 "Unit not found"）；先确认有没有 unit：
timeout -k 5 20 ssh elden-root "su -l xuqianhui1001 -c 'XDG_RUNTIME_DIR=/run/user/1001 systemctl --user list-units --all | grep -i osk' || true"
# 无 unit ⇒ 按 PID 杀（POSIX sh + 不依赖 pgrep -x 的写法）：
timeout -k 5 20 ssh elden-root "for p in \$(ps -eo pid,comm | awk '\$2==\"phosh-osk-stub\"{print \$1}'); do kill \$p; done; \
                               sleep 1; ps -eo pid,comm | grep -c '[p]hosh-osk-stub'"
# （phosh 在该出现键盘时重新 exec 一份；旧的 D-Bus 名 sm.puri.OSK0 由新进程重新持有）
# 回退：无需回退（杀掉只是重启）；若新进程没被拉起，点一次输入框即可（phosh 按需 spawn）
```

> 若该机确实存在 user unit（上面的 `list-units` 有输出），则执行 `systemctl --user restart <unit>` 取代 `kill`。

### 5) 修复后判据（全部免触摸）

```sh
# a) 这条错必须消失（重启后新进程的日志段）
timeout -k 5 20 ssh elden-root "journalctl _COMM=phosh-osk-stub --since '-3min' --no-pager | grep -c 'Error creating user data dir'"   # want 0
# b) 用户目录被 osk-stub 自己填出来（build/ 预编译符号链接+用户词典）
timeout -k 5 20 ssh elden-root "ls /home/xuqianhui1001/.local/share/rime/build | wc -l"        # want ≥10（本机同数据得 24）
timeout -k 5 20 ssh elden-root "ls -la /home/xuqianhui1001/.local/share/rime"                   # 期望见 installation.yaml / user.yaml / luna_pinyin.userdb/ / build/
# c) osk-stub 真在「用」RIME：用户词典 LOCK 被它独占（探针构建/拷机见 §5 L1；先做 §5 L1 再回来做这条）
timeout -k 5 60 ssh elden-root "su -l xuqianhui1001 -c '/tmp/rime-probe /home/xuqianhui1001/.local/share/rime nihao luna_pinyin'" 2>&1 | head -3
#   期望出现 `level_db.cc:259] Error opening db 'luna_pinyin': IO error: lock …/luna_pinyin.userdb/LOCK: Resource temporarily unavailable`
#   之后仍打印 num_candidates=5 —— 这条 LOCK 报错是**正面证据**（= OSK 进程正持有同一 userdb）
# 备选（不跑探针）：看该进程 open 的 fd 里有没有 userdb
timeout -k 5 20 ssh elden-root "for p in \$(ps -eo pid,comm | awk '\$2==\"phosh-osk-stub\"{print \$1}'); do ls -l /proc/\$p/fd 2>/dev/null | grep -c userdb; done"  # want ≥1
```

### 6) 统一回退（一步回旧态，键盘功能不受影响）

```sh
timeout -k 5 20 ssh elden-root "$ASUSER gsettings reset sm.puri.phosh.osk.Completers.Rime user-data"
timeout -k 5 20 ssh elden-root "rm -rf /home/xuqianhui1001/.local/share/rime"
# 再执行 §4-4 的 kill 一次让进程重读配置；旧行为（每天一条 ERROR，候选仍可出）复现
```

---

## 5. Q4-B：不依赖触摸的验证命令（分三层，任一层过都不需要人手）

**L0 配置层**（§4-2 的 `gsettings list-recursively … Completers.Rime`）：三键值正确即「配置对」。

**L1 librime 层**（证明「同参数下 librime 真能出候选」，不需 OSK、不需触摸）——用仓内 aarch64 探针：

```sh
# 主机构建（设备同版本 1.13.1 头/库 + trixie sysroot；本轮已实测能编能跑）
# 两个本地基线件若已被 /tmp 清理，可重取（arm64 deb 解包即可，无需安装）：
#   dpkg-deb -x /tmp/rimewrap/arm64/librime-dev_1.13.1+dfsg1-1_arm64.deb /tmp/rimewrap/arm64root
#   （sysroot 用本仓既有的 /tmp/trixie-sysroot/root，即 11-23 编 osk-stub 用的同一份）
aarch64-linux-gnu-gcc -O1 -Wall -Wextra --sysroot=/tmp/trixie-sysroot/root \
  -I /tmp/rimewrap/arm64root/usr/include reports/rime-completer-probe-20261124.c \
  -L/tmp/rimewrap/arm64root/usr/lib/aarch64-linux-gnu -lrime -o /tmp/rime-probe
# 送上设备（root 拷到 /tmp，用户身份跑）
timeout -k 5 20 ssh elden-root 'cat > /tmp/rime-probe && chmod 755 /tmp/rime-probe' < /tmp/rime-probe
timeout -k 5 60 ssh elden-root "su -l xuqianhui1001 -c '/tmp/rime-probe /home/xuqianhui1001/.local/share/rime nihao luna_pinyin'"
# 期望：无 deployment_tasks.cc:90 那行；num_candidates=5；cand[0]=你好；退出码 0
# 对照（复现缺陷）：/tmp/rime-probe "" nihao luna_pinyin  ⇒ 有那行 ERROR，但仍然 num_candidates=5（§3.3 A 场景）
```
> 探针不是新增依赖：设备只需 `librime1t64`（已在）。若不想送新二进制，可用已部署的 A 案静态件
> `patches-userland/zh-ime-rime-20261123/verify/aarch64/librime-piped --oneshot nihao --shared /usr/share/rime-data --user <dir> --schema luna_pinyin`
> 得到同样的「候选非空」判据（`--oneshot` 0 候选 exit 3）。

**L2 进程层**（证明 **osk-stub 本体**已完成 librime 初始化，无需触摸）：§4-5 的 a/b/c 三条（journal 计数 0、
用户目录被填、`luna_pinyin.userdb/LOCK` 被 `phosh-osk-stub` 持有）。特别地：**LOCK 被它占用**是「RIME session 活着并在写用户词典」
的充分证据；用别的进程再开同一 userdb 会拿到 `Resource temporarily unavailable`（`level_db.cc:259`），这条报错因此是**正面证据**。

**必须人手**（明确写出，不用其它伪装）：
1. 屏上候选条是否出现（`nihao` → `1 你好 2 妳好 …`）、空格/数字选词是否上屏；
2. 选词后是否**追加空格**（H lane R1-6）；
3. 每键震动（`haptic/0001`，需人手判断幅度）；
4. terminal 布局方向键/Home/End 光标行为。
（本机 `/dev/uinput` 缺失、设备停在锁屏时，agent 无法注入手势——这三轮报告口径一致。）

---

## 6. 风险 / 回退 / 技术债

**风险**

| # | 风险 | 判据 / 缓解 |
|---|---|---|
| R1 | dconf 里已有**旧值**时 `gsettings set` 只影响该用户、且只在会话总线上生效；用 root 无总线执行会静默写不进 dconf（只改内存） | 每条 set 之后立刻用**同一条 `ASUSER` 前缀**读回（§4-2 的核对行） |
| R2 | `~/.local` 属主异常（root:root）导致 `install -d` 或 librime 建目录 EACCES | 看 `install` 退出码；只补 `.local` / `.local/share` 两级属主，不 `chown -R` |
| R3 | user-data 指向新目录后首次启动要**编译工作区**（本机实测目录体量 ≈32 MB，耗时数秒） | 只在重启后第一次延迟；不要在此期间杀进程；磁盘余量按 50 MB 预留 |
| R4 | 把 user-data 指到 `/usr/share/rime-data`（只读）会**永久**复现同一条错 | 不要那样配；user-data 必须是用户可写目录 |
| R5 | 旧行为下 librime 写在 OSK `cwd` 的 `installation.yaml`/`user.yaml`/`build/`+`*.userdb` 会与新目录**并存** | 只登记不删；若要清理，先 `ls -la` + mtime 比对，且确认不是别人的家目录文件 |
| R6 | 本报告用 1.13.1 arm64 **真机同版本**库做的结论，但 UI 层（候选条）未验证 | 见 §5「必须人手」四条 |

**回退**：§4-6 两步（`gsettings reset` + `rm -rf`）+ 一次 kill。回退后功能回到「候选仍可出、日志每天一条 ERROR、产物落 cwd」的旧态——**不会把键盘打坏**（§3.3 A 场景已证）。

**技术债（下一轮编译轮，需重编 osk-stub；不改本轮已交付件）**
1. `pos-completer-rime.c:356-361`：`user` 为空/空白 ⇒ 退化为 `g_build_filename (g_get_user_data_dir (), "rime", NULL)` + `g_mkdir_with_parents()`
   （`RIME_PROVIDED` 的语义是「非 NULL 即采用」，源码侧兜底比 gschema 默认值可靠）；
2. 同文件对 `shared-data` 做 `g_file_test (…, G_FILE_TEST_IS_DIR)` 校验并 `g_warning`，
   避免把空串/错路径喂给 librime 后**只**在 journal 里冒出一条 librime ERROR；
3. gschema `user-data` 的 `<summary>` 从「Empty disables the user dictionary」改成「Empty ⇒ 用 XDG 默认目录（`$XDG_DATA_HOME/rime`）」；
4. 把「journal 里 `Error creating user data dir` 计数 = 0」加进 `verify/ime-zh-rime-verify.sh` 作为常驻判据（本轮 L2-a 已给命令）。

---

## 7. 来源 / 复现清单

- 交付件（只读）：`patches-userland/zh-ime-rime-20261123/rime/pos-completer-rime.c`（`:349,355-357,360-361,369-382`）、
  `rime/0003-osk-stub-rime-completer-wiring.patch`（`:12-33` gschema hunk、`:497,504,508-509,519`）、
  `out/osk-stub-rime-20261123/{sm.puri.phosh.osk.gschema.xml,DEPLOY.md}`。
- 上游源码（1.13.1 tag，本机解包 `/tmp/librime-1.13.1`）：`src/rime/lever/deployment_tasks.cc:82-92,159`、
  `src/rime/setup.cc:46-49,60-67`、`src/rime/deployer.cc:15-24`、`src/rime_api.h:74-75`、`src/rime_api_impl.h:65-89`、
  `src/rime/service.cc:167-187`、`src/rime/resource.cc:20-45`、`src/rime/dict/dictionary.cc:394-401`。
- GLib：`gio/gsettings-tool.c:271-305`、`gio/gsettingsschema.c:1085-1109`（本机 glib 2.88.0 实测复现）。
- 本轮新增：本报告 + `reports/rime-completer-probe-20261124.c`（探针源；aarch64 构建命令见 §5 L1）。
- 并行产出（未改动，仅比对）：`reports/d3-rime-ondevice-20261124.md`（设备窗修复动作/修复后证据成立；其「该错 ⇒ 候选空」的
  因果链缺隔离实验，见 §3.3）。
