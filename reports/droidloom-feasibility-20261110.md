# Waydroid 网络现状定案 + droidloom 可行性复评（2026-11-10，设备实测）

- **lane**：本会话（droidloom × Waydroid）。设备在线（USB-NCM `192.168.7.1`，`7.3.1-debug-vk184-00002`）。
- **纪律**：只读为主；唯一写动作 = 设备 `/etc/subuid`/`subgid` 加一条 100000 的连续区间（可回退）、
  设备 `/opt/dl-test` 摊开一个 6.6 MB runtime 包、设备装 `wayland-utils`（读 registry 用）。
  **零刷写、零重启、零内核改动**（`build/daily/.config` 已实测后回滚）。
- **证据级别**：每条标 **实测 / 静态 / 推断**。

---

## 1. 结论（先数字）

| # | 问题 | 判定 | 级别 |
|---|---|---|---|
| W1 | Waydroid 出网到底通不通 | **通**。容器 → 宿主网关 → `wlp1s0` 直连 NAT，HTTP/HTTPS 均 200，DNS 正常 | 实测 |
| W2 | 之前「不明晰」的根因 | **三条互不相关的假象**（见 §2），**不是**容器网络坏 | 实测 |
| W3 | 容器代理设置是否还指着死端口 | **是**。`settings global http_proxy = 192.168.7.9:7897`，但**中继在宿主侧（192.168.7.9）**，从容器看是**另一台机器**；容器自己走直连，代理设置是残留 | 实测 |
| D1 | droidloom aarch64 包能否在本机跑 | **能装能跑**：runtime 包 6.6 MB 摊开即执行，`droidloom-doctor` 在设备上跑通 | 实测 |
| D2 | droidloom 内核阻塞项 | **只剩 1 个**：`CONFIG_NF_TABLES` 未开（`kernel.network_isolation` FAIL） | 实测 |
| D3 | droidloom 合成器阻塞项 | **phoc 0.58 / 0.59.rc1 都没有 `wp_linux_drm_syncobj_manager_v1`**（0.59.rc1 源码全树 0 命中），presenter 硬绑定 ⇒ 直接起不来 | 实测 + 静态 |
| D4 | 上面这条**不是**内核/驱动缺陷 | msm 驱动 `DRIVER_SYNCOBJ_TIMELINE` 在（`DRM_CAP_SYNCOBJ_TIMELINE`=1），wlroots 自己的探测（`handle=0/fd=-1` 期望 `ENOENT`）**通过**；且 `linux-drm-syncobj` 全局的**创建条件完全满足** | 实测 |
| D5 | G2 硬验收（PI/Widevine）净增益 | **0**。上游 `KNOWN_ISSUES` 原文仍免责；aarch64 与 Waydroid 同一结论 | 静态 |

⇒ **裁决：droidloom 从「只跟踪」升级为「可立项的最小试验」，但天花板不变**。
最小试验的全部前置 = **① 内核加 nf_tables（一次重编）② 换/补合成器（一行 + 重编 phoc）**，
做完才能回答「能不能真跑起一个 App」。**G2 的 PI/Widevine 结论不会因此改变。**

---

## 2. Waydroid 网络：三条假象 + 真链路

### 2.1 真链路（实测，逐跳）

```
容器 eth0 192.168.240.112/24  →  waydroid0 192.168.240.1（宿主）
   iptables-legacy POSTROUTING -s 192.168.240.0/24 ! -d 192.168.240.0/24 -j MASQUERADE
   ip_forward=1，FORWARD -i/-o waydroid0 ACCEPT
宿主 wlp1s0 114.214.179.189/20  →  默认路由 114.214.176.1
```

实测矩阵（容器内 `curl`，2026-11-10）：

| 目标 | 容器 | 宿主（`--noproxy '*'` 直连） |
|---|---|---|
| `https://www.baidu.com` | **200**（0.43 s） | 200 |
| `https://mirrors.ustc.edu.cn/` | **200** | 200 |
| `https://pypi.tuna.tsinghua.edu.cn/simple/` | **200** | — |
| `https://www.google.com` | **302**（`gws` 头，正常 HK 跳转） | 000（宿主直连被墙，走代理才有） |
| `https://github.com` | **000** | 000（宿主直连也不通，代理才通） |
| `ping 192.168.240.1` | 0% loss | — |
| `ping 8.8.8.8` / `223.5.5.5` | **100% loss** | **同样 100% loss** |

### 2.2 三条假象（这才是「不明晰」的来源）

1. **ICMP 全灭 ≠ 网络坏**。宿主自己 `ping 8.8.8.8` 也是 100% loss（校园网 ICMP 出站被拦），
   容器跟着一起「不通」。用 `ping` 判容器网络 = 必然误判。**判据必须是 TCP/HTTP**。
2. **没有 `/etc/resolv.conf` 不等于 DNS 坏**。容器里 `cat /etc/resolv.conf` → No such file；
   但 Android 走 `netd`/`dumpsys connectivity` 里的 `DnsAddresses: [ /192.168.240.1 ]`（dnsmasq），
   域名解析实测正常（`curl` 打域名 200，`ping github.com` 能解析出 `20.205.243.166`）。
3. **`github.com` 不通是上游策略，不是容器**。宿主直连同样 000；宿主经 `127.0.0.1:7890` 才 200。
   容器没配代理 ⇒ 只走直连 ⇒ github 打不开。**这条曾被误读成「容器网络不明」**。

### 2.3 代理现状（残留配置，不是故障）

- 容器 `settings get global http_proxy` = **`192.168.7.9:7897`**，指向**宿主**（USB-NCM 侧）中继；
  宿主侧 `systemd-socket-activate` 确实在 `192.168.7.9:7897` 监听，链路可用：
  容器 `https_proxy=http://192.168.7.9:7897 curl github` = **200**（实测）。
- 但容器**没有把这条代理应用到系统级**（`global_http_proxy_host/port` 读到 7.9/7897，实际 curl 未带）。
  所以现在容器 = 纯直连。**要么显式用代理，要么保持直连**，别指望 settings 里那两条自己生效。
- `systemd/host-net-proxy.service` 在**宿主**（PC）上 `enabled+active`，`Linger=yes`，
  监听 `192.168.7.9:7897`；**平板上没有这个 unit**（`/home/xuqianhui1001/.config/systemd/user/` 下无），
  这是设计如此（中继必须在有 Bettbox 的那一端）。**不要**在平板上再装一份。

### 2.4 结论

Waydroid 网络**没有未解问题**。以后判据统一为：

```sh
waydroid shell -- curl -s -o /dev/null -w '%{http_code}\n' -m 8 https://www.baidu.com   # 期望 200
```

`ping` 与 `resolv.conf` 一律不作判据（见 PITFALLS 新条）。

---

## 3. droidloom 可行性：把「四道未知」压到「两件已知小事」

### 3.1 已实测打通的部分（本轮新增，全部设备实测）

| 项 | 结果 | 做法 / 证据 |
|---|---|---|
| aarch64 包可用性 | **过** | `droidloom-runtime-0.1.0-30-aarch64.pkg.tar.zst`（6 598 150 B）从 GitHub Releases 直取；`.PKGINFO arch=aarch64`，8 个 ELF 均 `ARM aarch64` |
| Debian 侧 ABI 兼容 | **过** | `tar --zstd -xf` 到 `/opt/dl-test`，`droidloom-doctor --help`、`droidloomctl --help`、`droidloomd --help` **全部直接跑起来**（只需 `libc`+`libgcc_s`；`droidloom-wayland` 另需 `libgbm/libxkbcommon/libwayland-server`，设备全有） |
| doctor 全项体检 | **13 过 / 1 阻塞 / 1 警告** | 见 §3.2 表；`ready:false, blocker_count:1` |
| 主 GPU 识别 | **过** | `/dev/dri/renderD128` 的 `device/driver` → `msm_dpu`；droidloom `host_gpu.rs` 的 `vendor()` 白名单含 `"msm_dpu"` ⇒ 判为 Qualcomm 原生渲染（不是 NVIDIA 转发路径） |
| syncobj 内核能力 | **过** | `DRM_CAP_SYNCOBJ`=1、`DRM_CAP_SYNCOBJ_TIMELINE`=1（card0 与 renderD128 同）；wlroots 的 `check_syncobj_eventfd()` 判据（`handle=0,fd=-1` → 必须 `ENOENT`）**返回 errno=2** ⇒ 通过 |
| EGL 显式同步能力 | **过** | `eglinfo`：`EGL_ANDROID_native_fence_sync`、`EGL_KHR_fence_sync`、`EGL_KHR_wait_sync` 全在（wlroots gles2 renderer 的 `features.timeline` 三条件齐） |
| 桌面前置协议 | **过** | phoc registry 56 全局，含 `xdg_wm_base v6`、`zwp_linux_dmabuf_v1 v5`、`zwp_text_input_manager_v3 v2`、`zwlr_output_power_manager_v1`、`wp_fractional_scale_manager_v1`、`wp_viewporter` |

### 3.2 doctor 体检表（设备实测，`/opt/dl-test/usr/bin/droidloom-doctor --user xuqianhui1001`）

| 检查 | 结果 | 说明 |
|---|---|---|
| `host.linux` / `cpu.architecture` | PASS | aarch64 原生 |
| `kernel.namespaces` | PASS | user/pid/mnt/ipc/uts/net/cgroup 全在 |
| `kernel.binderfs` | PASS | `CONFIG_ANDROID_BINDERFS=y` + `/proc/filesystems` 有 binderfs |
| `kernel.cgroup_v2` / `kernel.cgroup_freezer` | PASS | cpuset cpu io memory hugetlb pids 全有 |
| `kernel.seccomp` | PASS | `CONFIG_SECCOMP_FILTER` + 7 种 action |
| `identity.subordinate_ids` | **FAIL → 已修** | 原 `/etc/subuid` 只有 65536，契约要 **100000 连续**。`usermod --add-subuids 300000-399999 --add-subgids 300000-399999` 后 **PASS** |
| `kernel.network_isolation` | **FAIL（唯一阻塞）** | `CONFIG_NF_TABLES is disabled`；`CONFIG_VETH=m` 且模块可加载 ⇒ 只差 nftables |
| `graphics.render_node` | PASS | `/dev/dri/renderD128 (driver msm_dpu)` |
| `graphics.buffer_sync` | PASS | `DMA_SHARED_BUFFER` + `SYNC_FILE` + 运行时证据 |
| `graphics.dmabuf_heaps` | PASS（非阻塞） | `CONFIG_DMABUF_HEAPS=y`（`/dev/dma_heap` 未出现，doctor 判非阻塞） |
| `kernel.mount_filesystems` | PASS | proc/sysfs/tmpfs |
| `security.host_lsm` | **WARNING（非阻塞）** | 只有 `capability`，无 apparmor/selinux/landlock ⇒ 上游原文：整 cell 被攻破视作在边界外 |

### 3.3 真正的阻塞项（两条，都是「我们自己能干的小事」）

#### D-1 内核：`CONFIG_NF_TABLES`（已备好片段，未落树）

- 现役 `.config`（`build/daily`，vk184 血统）**`# CONFIG_NF_TABLES is not set`**；设备上
  `nft list ruleset` → `netlink: Error: cache initialization failed: Invalid argument`，
  `iptables -t nat -S` → 同样报错（`iptables-legacy` 才是现在生效的那套，实测 MASQUERADE 规则在 legacy 表里）。
- droidloom `DevelopmentNetwork::setup_rules()` 强制 `nft -f -`，失败即 `start_development_cell` 返回 Err ⇒ **cell 起不来的第一硬阻塞在内核配置**。
- 本轮已产出片段 **`patches/fragment-droidloom-nftables.config`**（10 条必须显式项），
  并在 `build/daily` 上实跑 `apply` + `make olddefconfig` 验证：
  **纯 nftables 的 40 行 diff，`CONFIG_ARCH_QCOM=y` 未受影响**（`make olddefconfig` 删 ARCH_QCOM 的旧坑未复现）。
  **验证后已把 `.config` 回滚到原样**（本轮不落内核改动）。
- 依赖已在：`NF_CONNTRACK=y`、`NF_NAT=y`、`NF_NAT_MASQUERADE=y`、`NETFILTER_NETLINK=y`、`NET_CRC32C=y`。

#### D-2 合成器：`wp_linux_drm_syncobj_manager_v1`（一行 + 重编 phoc）

- presenter 是**硬绑定**：`graphics/droidloom-wayland/src/main.rs:3217`
  `let sync_manager: WpLinuxDrmSyncobjManagerV1 = globals.bind(&qh, 1..=1, ())?;`（**无 fallback**，
  而同文件 `dmabuf v4` 有显式版本检查 + 专用错误）。实测：`droidloom-wayland` 在 phoc 会话里直接
  `Wayland global bind failure: the requested global was not found in the registry`。
- registry 实测：`wp_linux_drm_syncobj_manager_v1` **0 命中**（56 个全局里没有）。
- **不是内核/驱动问题**（这是本轮最重要的翻转）：
  - wlroots 0.20.2 `types/wlr_linux_drm_syncobj_v1.c:444-461` 的创建前置 = `HAVE_LINUX_SYNC_FILE`
    + `check_syncobj_eventfd()`（`DRM_CAP_SYNCOBJ_TIMELINE` + `SYNCOBJ_EVENTFD` 返回 `ENOENT`）——
    **设备上三项全过**（§3.1 实测）。
  - 即：**只要合成器调用一次 `wlr_linux_drm_syncobj_manager_v1_create(display, 1, drm_fd)`，全局就会出来**。
- phoc 侧：`src/desktop.c:655-741` 的全局创建清单里**没有**这一行；**0.59.rc1 源码全树 `syncobj` 0 命中**
  （GitHub 镜像 `PhoshMobi/phoc` @ `v0.59_rc1`，`meson.build version: '0.59.rc1'`）⇒ **不是「升到 0.59 就有」**。
- Debian sid 只有 `phoc 0.58.0-1`（`apt-cache madison`），且**没有 deb-src 源** ⇒ 补这一行必须自己配 `deb-src` 或直接编上游 tarball。
- 参考实现（社区同一行）：sway `sway/server.c:297-302`（条件 = `renderer->features.timeline && backend->features.timeline`）；
  labwc `src/server.c` 同样一行。**说明这是「合成器愿不愿意广告」的选择，不是能力问题。**

### 3.4 五维复评（相对 2026-11-08）

| 维度 | 11-08 | 现在 | 变化原因 |
|---|---|---|---|
| 可用性 | 1/5 | **2/5** | 包能装能跑、doctor 只剩 1 阻塞、subuid 已修 |
| 图形 | 2/5 | **3/5** | 内核/EGL/wlroots 三条件实测全过 ⇒ 缺口收敛为「合成器少一行调用」 |
| 输入 | 2/5 | **2/5** | 不变：presenter 走 `zwp_text_input_v3`，与 IME lane（见 `reports/ime-phosh-fcitx5-invest-20261110.md`）**同一根断点** |
| 音频 | 3/5 | **3/5** | 未测（PipeWire 在，`droidloom-audio` 未跑） |
| 身份/完整性 | 0/5 | **0/5** | 不变（上游免责原文未动） |

### 3.5 与 Waydroid 的取舍（不改 G2 结论）

| | Waydroid（现状可用） | droidloom（本轮复评） |
|---|---|---|
| 前置成本 | 0（已跑） | 内核加 nftables + 补 phoc 一行 + 重编两样 |
| 窗口形态 | 单窗口/全屏（容器内 SurfaceFlinger） | 每个 App 一个 `xdg_toplevel` |
| 相机/传感器/触觉 | **已打通**（C4/C5/C10，含马达 AIDL V2 + RRO） | 上游称 non-preview；`KNOWN_ISSUES` 未列打通 |
| PI / Widevine | **必失败**（C3 三档结论已出） | **同一结论**（上游 `threat-model-v2.md` 免责原文） |
| GMS | 可登录（用户人工验证过） | 需自建 `droidloom-gapps`（要本地 LiteGapps 包 + 校验），**未验证** |
| 存储成本 | 已占（`/var/lib/waydroid`） | image 0.90 GiB 下载 + 2.5 GiB 安装（设备剩 157 GiB，够） |

⇒ **不动 Waydroid**。droidloom 走**隔离试验**：两件小事做完后，只用 `droidloom-doctor` + presenter 起停 + 一个 App 判定，
**不替换任何现有桌面/容器**。

---

## 4. 最小落地序列（成本排序，均未执行）

| # | 动作 | 成本 | 判据 | 回退 |
|---|---|---|---|---|
| L0 | ~~subuid 100000~~ | **已完成** | doctor `identity.subordinate_ids` = PASS | `usermod --del-subuids 300000-399999 ...` |
| L1 | 内核加 `patches/fragment-droidloom-nftables.config` → 编 `Image.gz` → 零写盘 `fastboot boot` | 1 次增量编（片段已验证只 40 行 diff） | 设备上 `nft list ruleset` 返回空而不报错；doctor `kernel.network_isolation` PASS | 回 vk184 现成 boot.img |
| L2 | phoc 补一行 `wlr_linux_drm_syncobj_manager_v1_create()`（0.58.0 tarball + 条件判断照 sway），本机编，替换 `phoc` 二进制 | 半天（需 `deb-src` 或直接编 tarball；需装 6 个 `-dev`） | `wayland-info` 出现 `wp_linux_drm_syncobj_manager_v1`；`droidloom-wayland` 不再 bind 失败 | 留 `phoc-0.58.0-1` deb，`dpkg -i` 回滚 |
| L3 | 下 `droidloom-image-0.1.0-30-aarch64`（0.90 GiB）+ 起 cell | 半天 + 2.5 GiB | `droidloomctl start` 后 `droidloomctl applications` 列出 Android 应用 | `droidloomctl stop` + 删 `/var/lib/droidloom` |
| L4 | 一个 App 真开（微信/浏览器任一） | 1 h | 独立 Wayland 窗口 + 触摸/键盘 | — |

**退出条件**：L1 后 `nft` 仍报错 ⇒ 停；L2 后 phoc 起不来或屏幕异常 ⇒ 立即回滚，droidloom 降回「只跟踪」。

---

## 5. 未取证清单（不得当结论）

1. **L1 之后的真实 nft 行为**：片段只保证编译期符号在；`nft -f` 在 msm 平台上的实际执行未测。
2. **L2 之后 phoc 是否稳定**：显式同步会改变 page-flip 提交路径（`backend/drm` 的 timeline 分支），
   msm_dpu 上是否有回归**未测**（`PITFALLS #…` 无先例）。
3. **phoc 0.58 的 `bb1f7465`（keyboard-grab NULL 解引用）**：0.58.0 不含，Debian 是否 backport 未核验
   ⇒ 若走 L2 应顺带带上（见 `reports/ime-phosh-fcitx5-invest-20261110.md` §5 末表）。
4. **droidloom 音频/相机/传感器**：本轮完全未测。
5. **GApps**：需本地 `LiteGapps-arm64-17.0.zip`，**未做**；`droidloom-gapps` 的 `inspect/build` 未跑。
6. **x86_64 产品线与 Teto**：与本机无关，未看。
7. **`/dev/dma_heap` 不存在**：doctor 判非阻塞，但 SurfaceFlinger 的 allocator 实际走哪条未验。

---

## 6. 给 Main 的三句话

1. **Waydroid 网络没有未解问题**：直连 NAT 通（baidu/ustc/pypi 全 200，google 302），
   之前的「不明」= ICMP 全灭 + 无 resolv.conf + github 上游被墙三条假象叠加；判据改用 HTTP 码。
2. **droidloom 已从「四道未知」压到「两件小事」**：`CONFIG_NF_TABLES`（片段已备并验证）+
   phoc 补一行 `wlr_linux_drm_syncobj_manager_v1_create`（内核/驱动/EGL 三条件实测全过，
   **0.59.rc1 也没有这行，不是升级能解决**）。
3. **天花板没变**：PI/Widevine 与 Waydroid 同一结论（上游免责原文未动），所以**不替换 Waydroid**，
   只做隔离试验；做完 L1+L2 才值得投 L3 的 0.90 GiB。

---

## 7. 证据指针

- 设备：`ssh root@192.168.7.1`（USB-NCM）；容器 `waydroid shell --`；会话 `su xuqianhui1001 -c`（`XDG_RUNTIME_DIR=/run/user/1001`）。
- 产物：`patches/fragment-droidloom-nftables.config`；设备 `/opt/dl-test/usr/bin/droidloom-*`（临时摊装，可删）。
- 上游源码：`denialwm/droidloom` @ `d09…`（`graphics/droidloom-wayland/src/main.rs:3217`、
  `runtime/droidloom-supervisor/src/development_network.rs`、`runtime/droidloom-doctor/src/lib.rs:600-620`、
  `runtime/droidloom-supervisor/src/host_gpu.rs`）；`PhoshMobi/phoc` @ `v0.59_rc1`（`src/desktop.c:655-741`）；
  wlroots 0.20.2 `types/wlr_linux_drm_syncobj_v1.c:425-461`、`render/gles2/renderer.c:687-691`、
  `backend/drm/drm.c:125`；sway `sway/server.c:297-302`。
- 基线报告：`reports/droidloom-feasibility-20261108.md`（本轮不重复其 §1–§5 的协议/形态核对）。

---

## 8. 2026-11-10 追加：合成器门槛的实测突破（不必先编 phoc）

### 8.1 headless sway 广告了 syncobj（实测）

```sh
# 设备上，普通用户，无需 DRM master
export XDG_RUNTIME_DIR=/tmp/xdg-swaytest
WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER_ALLOW_SOFTWARE=1 \
  sway -c /tmp/sway-headless.conf &
wayland-info | grep syncobj
```

输出（实测）：

```
interface: 'zwp_linux_dmabuf_v1',              version:  5, name:  3
interface: 'wp_linux_drm_syncobj_manager_v1',  version:  1, name:  4
interface: 'xdg_wm_base',                      version:  5, name: 13
```

`sway 1.12` + `libwlroots-0.20.2`（Debian sid 现成包，`apt install sway` 只装 4 个包）
在 `WLR_BACKENDS=headless` 下**广告了** `wp_linux_drm_syncobj_manager_v1`。
机制：`sway/server.c:297-302` 的条件是 `renderer->features.timeline && backend->features.timeline`；
headless 后端 `backend/headless/backend.c:79` **恒置 `features.timeline = true`**
（对比 `backend/drm/drm.c:125` 要 `DRM_CAP_SYNCOBJ_TIMELINE`，本机也满足；`backend/wayland` 则取决于上游合成器）。

### 8.2 droidloom presenter 在 sway 下通过了全部绑定（实测）

同一 headless sway 下跑 `/opt/dl-test/usr/bin/droidloom-wayland`：

```
DROIDLOOM_DIRECT_INPUT_ABI=1;
DROIDLOOM_HOST_CHANNELS_ABI=1;
DROIDLOOM_NOTIFICATIONS_ABI=3;
Droidloom session mode: desktop
DROIDLOOM_CLIPBOARD_ABI=1;
Droidloom clipboard backend: ext-data-control
```

**没有** `Wayland global bind failure`（在 phoc 0.58 会话里是直接失败退出）。
⇒ presenter 侧的全部门槛（`xdg-shell` / `linux-dmabuf` v4 feedback / `linux-drm-syncobj` /
`zwlr_output_power` / `viewporter` / `fractional-scale` / `alpha-modifier`）在 sway 下齐了。

### 8.3 这条改变了什么

| 原计划 | 现在 |
|---|---|
| L2 必须先「补一行 + 重编 phoc」（需配 `deb-src` 或编 tarball，半天） | **可以用现成 `sway` 包做前置验证**（零编译），只在「要回 Phosh 日用」时才需要补 phoc |
| 图形门槛判据 = `wayland-info` 有 syncobj | 同左，但**可以在 headless 后端上零风险取**，不动现有 Phosh 会话 |
| 不知道 presenter 除 syncobj 外还缺不缺别的全局 | **已知不缺**（§8.2） |

### 8.4 仍然卡住的两件（未变）

1. **内核 `CONFIG_NF_TABLES`**：`DevelopmentNetwork::setup_rules()` 强制 `nft -f -`；
   现役 `.config` 未开。片段 `patches/fragment-droidloom-nftables.config` 已备并验证。
   ⚠ headless sway 验证**不需要**这一项（不起 cell），所以 L1 与 L2 可解耦。
2. **image 包 0.90 GiB + GApps**：没下、没有 `LiteGapps-arm64-17.0.zip`。
   起 cell 之前的 `droidloom-package-helper prepare` 还会走 `pkexec` + `/etc/droidloom/cell.json`
   （`SPEC`/`RECIPE` 路径是 **Arch 打包路径**，Debian 上摊装需要手工铺 `cell.json` + `runtime.env`）。

### 8.5 结论更新

**图形前置不再是「半天编 phoc」，而是「`apt install sway` + headless 起一次」** —— 成本从半天降到 5 分钟，
且零编译、零替换现有桌面。**内核 nftables 仍是真门槛**（起 cell 才需要）。
⇒ C12 的最小可行试验 = `L1 内核 nftables` + `L3 image`；`L2 合成器` 已用 headless sway 验证通过，
只在「真窗口上屏」时才需要真后端（sway DRM 或补过一行的 phoc）。
