# elden-userland — 发行版无关的用户态固化包

> 目的：**让「这块板子上跑起来的用户态」不再只存在于设备里**。
> 现状问题（2026-10-25 实测）：自研脚本/二进制/服务定义散落在 **4 处**，其中一处**只存在于设备**：
>
> | 位置 | 内容 | 是否可重建 |
> |---|---|---|
> | `scripts/` | 大多数 `/usr/local/sbin` 脚本的**权威副本** | ✅ |
> | `rootfs/persistent-overlay/` | `/init`、`/usr/local/sbin` tar、greetd config、OpenRC initd（部分） | ✅ |
> | `rootfs/build-rootfs.sh:68-85` | `reboot2.c` 编译 + 一份**手抄的脚本白名单** | ⚠️ 白名单会漂 |
> | **设备 `/usr/local/bin` + `/etc/init.d` + `/etc/local.d`** | 7 个 ELF、10 个自研 initd、3 个 local.d、若干 conf.d | ❌ **无仓库源** |
>
> 后者就是「换 rootfs / 换 init（f2fs、Mobian）会静默丢能力」的根因：Debian 侧没有第二个副本。

## 设计（三条硬规则）

1. **一份清单 + 两份渲染**：`services.tsv` 是服务语义的唯一真源（依赖、参数、日志、重启策略、前置钩子），
   `tools/render.py` 渲染出 **OpenRC initd** 与 **systemd unit**，两种 init 都不再手写。
   ⇒ 换 Mobian 时不再「重写 7 类 unit」，而是「重跑一次 render」。
2. **文件二分区**：`files/` = **逐字采自设备**（sha256 比对，禁止手改）；`extra/` = **仓库新增/提取**
   （设备上没有，例如从 initd 内联 `start()` 里剥出来的 oneshot 脚本）。二者混写是最常见的漂移来源。
3. **ELF 不进 git**：`MANIFEST.tsv` 记 sha256/size，`sources.tsv` 记**重建命令 + 源文件**；
   `verify.sh` 强制「每个 ELF 都有源」，否则视为**不可重建资产**（当前 `ffrumble` 就是这种）。

## 目录

```
packaging/elden-userland/
├── MANIFEST.tsv        # 生成物：设备上每条文件的 dst/sha256/size/mode/repo_src（勿手改）
├── sources.tsv         # 人工维护：ELF 的构建命令与源文件（verify 校验源存在）
├── services.tsv        # 人工维护：服务语义（唯一真源）；INIT=ours/override/package
├── hooks/<svc>.pre     # 人工维护：启动前置钩子（原 initd 的 start_pre）
├── files/              # 生成物：采自设备的文本文件（逐字）
├── extra/              # 人工维护：仓库新增/剥离出来的包装脚本
├── templates/          # openrc-initd.in / systemd.service.in
├── tools/sync-from-device.sh   # 只读取设备 → files/ + MANIFEST.tsv
├── tools/render.py             # services.tsv → out/units/{openrc,systemd}
├── tools/verify.sh             # 离线/在线一致性门
└── out/units/                  # 生成物：可直接拷进任意 rootfs 的 unit
```

## 用法

```bash
# 采设备（只读；设备需 SSH 可达，默认 root@192.168.7.1）
bash packaging/elden-userland/tools/sync-from-device.sh
# 渲染两种 init
python3 packaging/elden-userland/tools/render.py
# 门禁（A–G；设备在线时 F 段额外比对「根画像」下的期望表）
bash packaging/elden-userland/tools/verify.sh

# 不连设备、改读本地树（负向测试 / 预演暂存 overlay）——门禁写完必须做这一步
LOCAL_ROOT=$PWD/out/stage-debian bash packaging/elden-userland/tools/verify.sh   # 正向：应全绿
LOCAL_ROOT=/tmp/fakeroot      bash packaging/elden-userland/tools/verify.sh   # 负向：篡改一个 unit 应 FAIL

# 强制根画像（默认自动：/etc/elden-init-mode → /run/systemd/system）
ROOT_PROFILE=openrc bash packaging/elden-userland/tools/verify.sh
```

## 门禁 F 段的「真值」优先级（2026-10-28 定）

换根（Alpine→Debian）后旧判据在 Debian 根上 **FAIL=3 全是假阳性**（`PITFALLS #455`）。现在的判据：

1. **期望 sha 优先取暂存 overlay**（`out/stage-debian/`，`rootfs/debian/stage.sh` 的产物）——
   那才是真正要 rsync 上去的内容；`rootfs/debian/overrides.tsv` 里「按发行版有意改写」的路径
   （如 `/etc/conf.d/greetd` 在 systemd `EnvironmentFile` 下不能带 `export`）自然不再报漂移。
2. **openrc 专属路径**（`/etc/init.d/`、`/etc/local.d/`）在 systemd 根上**不存在是预期**，聚合一行 ok，不逐条 WARN。
3. **渲染单元 ↔ 设备**（新 F2）：systemd 根对 `/usr/lib/systemd/system/*.service`，openrc 根对 `/etc/init.d/*`，
   与 `out/units/` 逐字比对——这条原先**完全没有门禁**（`render.py` 只保证渲染自洽，不保证部署一致）。
4. 全部 sha 一次 ssh 往返取（`xargs sha256sum`），73+ 条路径从分钟级降到 ~2.5 s。

## 服务迁移口径（换 init 时唯一要看的一列）

| INIT=ours | 我们自己写的，必须重新启用并验收 |
|---|---|
| INIT=override | 包自带的 unit 被我们打了补丁（greetd 崩溃守护、iio-sensor-proxy 等 SSC 400） |
| INIT=package | 纯包提供，迁移后只需 `systemctl enable`（qbootctl 属此类但需覆盖） |
| DISABLED=1 | 保留定义但默认不启用（如 Gunyah 模块加载，2026-10-25 已结项） |

⚠️ **不能省的语义**（都在 services.tsv 里，迁移时逐条对）：
- `qbootctl` 必须在 `default`/`multi-user` 里，否则 **~7 次重启后卡 fastboot**（`PITFALLS #181`）。
- `greetd` 必须带**崩溃重启**（`PITFALLS #318`：崩=无桌面、loginctl 无会话）。
- `iio-sensor-proxy` 必须**等 QRTR svc 400**（`G1-34`：不等则自动旋转永久 MODE_OFF）。
- `wifi-scan-refresh` 间隔必须 **< 180 s**（`PITFALLS #354`，120/150/170 可选）。
- `elden-hapticd` 的 `amplitude` 默认必须是 **255**（0 ⇒ 完全不动，不是「震得轻」）。
- 音频 tplg 必须**在 initramfs 里**加载（不在用户态服务里，属 boot.img 责任，见 `f2fs-plan` §5）。
