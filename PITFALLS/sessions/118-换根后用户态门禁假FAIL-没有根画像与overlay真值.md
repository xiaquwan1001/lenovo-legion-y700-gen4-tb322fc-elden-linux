# 118 · #455 换根（Alpine→Debian）后用户态门禁 FAIL=3 全是假阳性：门禁缺「根画像」与「overlay 真值」

- **日期**：2026-10-28
- **场景**：跑 `packaging/elden-userland/tools/verify.sh`（用户态固化门，T14 产物）在现役 **Debian forky/sid** 根上。
- **现象**：`FAIL=3 WARN=12`，与报告里「FAIL=0 WARN=3」的基线不符：
  - FAIL `/etc/conf.d/greetd`（设备 ≠ 仓库副本）
  - FAIL `/etc/init.d/greetd`（设备 ≠ 仓库副本）
  - FAIL `/etc/udev/rules.d/81-libssc-elden.rules`（设备 ≠ 仓库副本）
  - WARN×12：`/etc/init.d/*` 与 `/etc/local.d/*`「设备上已不存在」

## 根因（三条，全是判据错不是资产错）

- ① **门禁不知道「根画像」**：`MANIFEST.tsv` 采自 **Alpine/OpenRC** 根，其中 13 条路径
   （`/etc/init.d/*`、`/etc/local.d/*`）在 **systemd 根上本来就不存在** ⇒ 逐条 WARN 是噪声。
- ② **门禁不知道「按发行版有意改写」**：`rootfs/debian/overrides.tsv` 已声明
   `/etc/conf.d/greetd` 在 Debian 侧**必须**写无 `export` 版本（systemd `EnvironmentFile` 不认 `export`
   前缀，会整条丢弃）⇒ 拿 Alpine 副本的 sha 去比 Debian 文件，**必然**不一致。
   `rootfs/debian/stage.sh` 早就懂这件事（它的门禁 C 会跳过 overrides），`verify.sh` 没同步。
- ③ **门禁没有「渲染产物 ↔ 设备」这一层**：`render.py` 只保证两套 unit 渲染自洽，
   至于设备上 `/usr/lib/systemd/system/*.service` 是不是渲染出来的那份，**从来没查过**
   —— 而换根后这才是真正的漂移面（19 个 unit 实际**全部一致**，只是没人验证过）。

## 判据修法（`tools/verify.sh` §F，2026-10-28）

- **期望 sha 优先取暂存 overlay**（`out/stage-debian/`，stage.sh 的产物）⇒ overrides 路径自然归位。
- **openrc 专属路径在 systemd 根上聚合跳过**（一行 ok：`N 条 openrc 专属路径…不适用`）。
- **新增 F2**：渲染单元 ↔ 设备（systemd → `/usr/lib/systemd/system`，openrc → `/etc/init.d`）。
- 全部 sha **一次 ssh 往返**（`xargs sha256sum` 替代 73 次 ssh）⇒ 2.6 s。
- 新增 `LOCAL_ROOT=<dir>`（不连设备读本地树）与 `ROOT_PROFILE=systemd|openrc`（强制画像）。

## 实测（真机）

```
改前: FAIL=3 WARN=12
改后: FAIL=1 WARN=0   ← 唯一残留是真漂移：设备 81-libssc-elden.rules = 旧短版（规则行逐字相同，只差注释）
部署 staged 版（备份 /root/bak/…bak-20261028-102049）后: FAIL=0 WARN=0（80 条含渲染单元一致）
```

## 纪律（本条的真正教训）

**门禁写完必须做负向测试**（`PITFALLS #454` 同日第二次）：
- 正向对照 `LOCAL_ROOT=out/stage-debian` ⇒ `80 条一致 / FAIL=0`；
- 负向 `LOCAL_ROOT=/tmp/fakeroot` + 往 `qbootctl.service` 追加一行 ⇒ **精确 FAIL 到该文件**。
一条**会因换根而假红**的门禁与一条**静默跳过**的门禁同样危险：前者教人忽略红灯，后者假装绿灯。
判据里凡出现「设备绝对路径 ↔ 仓库副本」的比对，都必须先问一句**「这个根上它该不该存在、该不该同内容」**。
