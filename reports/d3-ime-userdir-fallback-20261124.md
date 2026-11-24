# D3 源码正解：`Completers.Rime user-data` 空串兜底（2026-11-24 主机侧 lane）

> lane 类型：**纯主机侧**（零 ssh / 零上机 / 零发信）。设备侧现态见 `reports/d3-rime-ondevice-20261124.md`。
> 基线：phosh-osk-stub **0.46.0** pristine（`/tmp/osks/phosh-osk-stub-0.46.0`，orig.tar.xz 解包）。
> 所有外部命令带 `timeout -k`。产物：`patches-userland/zh-ime-rime-20261123/rime/0004-osk-stub-rime-userdir-fallback.patch`
> + `NOTES-userdir-fallback.md` + `out/osk-stub-rime-userdir-20261124/`。

## 0. 一页结论

| 项 | 值 |
|---|---|
| **根因（一句）** | `sm.puri.phosh.osk.Completers.Rime user-data` 默认 `''`，B 案 completer 把空串原样塞给 `RimeTraits.user_data_dir`；librime 只判「非 NULL」就当真路径（`rime_api.h`），`InstallationUpdate` 对 `""` 调 `create_directories("")` 必败 ⇒ 每次启动 `deployment_tasks.cc:90 Error creating user data dir:`，用户词典/定制/`installation_id` 不持久化、部署产物落进进程 cwd |
| **补丁** | `rime/0004-osk-stub-rime-userdir-fallback.patch`（git 格式，2 文件 +21/−2；**叠加在 0003 之后**） |
| **改动** | `.c`：空/未设 ⇒ `g_build_filename (g_get_user_data_dir (), "rime", NULL)` + `g_mkdir_with_parents (…, 0700)`，失败只 `g_warning` 并继续（不阻塞键盘）；gschema：`<summary>` 删掉错误断言「Empty disables the user dictionary」，`<description>` 改为「Empty ⇒ XDG 默认目录」 |
| **门禁** | 6/6 通过：`git apply 0003+0004` rc=0、干净树 `patch -p1` rc=0、`gcc -fsyntax-only -Wall -Wextra` rc=0、`glib-compile-schemas --strict --dry-run` rc=0、aarch64 交叉 `ninja` rc=0、风格自查 |
| **新二进制** | aarch64 ELF，`sha256 688acbe706e902d30937b033b608018f432c97c48d4fc6fdbbb4865b17a7598d`（旧在机件 `cde21b9c…`，md5 旧 `2c040ca7…` / 新 `66808a5c…`），NEEDED 仍含 `librime.so.1` |
| **下一步（需设备窗）** | 一次 divert+hold 部署新件 + 新 gschema，三条判据：①`user-data` **保持空**时 `journalctl _COMM=phosh-osk-stub \| grep -c 'Error creating user data dir'` = 0；②`~/.local/share/rime` 出现 `build/`+`*.userdb/` 且属主是会话用户；③`gsettings get … user-data` 仍是 `''`（兜底在代码里，不靠 dconf） |

## 1. 补丁改动点（file:line = 打完 0003+0004 后的行号）

`src/completers/pos-completer-rime.c`

```
30:  #include <errno.h>
33:  #include <glib/gstdio.h>
362-375:  /* Empty user-data means "use the XDG default" … 非致命，只丢持久化 */
368:    if (*user == '\0') {
369:      g_free (user);
370:      user = g_build_filename (g_get_user_data_dir (), "rime", NULL);
371:      if (g_mkdir_with_parents (user, 0700) < 0)
372:        g_warning ("Rime: can't create user data dir '%s': %s; "
373:                   "the user dictionary won't persist",
374:                   user, g_strerror (errno));
375:    }
379:  traits.user_data_dir = user;      /* 不变：空串已在此前被换掉 */
```

`data/sm.puri.phosh.osk.gschema.xml:100-107`（`<default>''</default>` **有意不改**：兜底在代码里，
用户已有 dconf 值不会被覆盖；`shared-data`/`schema` 不动）

```diff
-      <summary>Directory for Rime's per-user data. Empty disables the user dictionary.
+      <summary>Directory for Rime's per-user data.
       </summary>
-      <description/>
+      <description>Empty uses the XDG default directory ($XDG_DATA_HOME/rime,
+        usually ~/.local/share/rime), so the user dictionary still persists.
+      </description>
```

设计取舍（3 条，供评审）：
1. **兜底放代码而不是改 gschema 默认值**：改默认值对已部署设备无效（dconf 已有显式 `''` 值），且默认值写死绝对路径
   违反 XDG；放代码 = 一次重编对「所有人」都成立。
2. **失败不阻塞**：`g_mkdir_with_parents` 失败（只读 `$HOME`、配额满）时 librime 仍会退化成旧行为 —— 候选照出，
   只是词典不持久化。这符合 `reports/rime-completer-userdir-20261124.md` §3.3 的实测语义（空 user dir ≠ 无候选）。
3. **不新建 helper 函数**：6 行内联，两侧（`init` 唯一调用点）不需要复用；加静态函数反而要新签名单测面。

## 2. 门禁：原始命令 + 输出

### 2.1 干净副本应用（`/tmp/osks/osk-gate-0004` = pristine 0.46.0 的 `cp -a`）

```sh
$ git apply 0003-osk-stub-rime-completer-wiring.patch ; echo rc=$?
rc=0
$ git apply 0004-osk-stub-rime-userdir-fallback.patch ; echo rc=$?
rc=0
$ git apply --check 0004…   # 重复应用应失败（已应用）
rc=1
$ patch -p1 -R --dry-run < 0004…   # 反向试跑（`patch -p1` 路径亦可用）
checking file data/sm.puri.phosh.osk.gschema.xml
checking file src/completers/pos-completer-rime.c
rc=0
```

另一份干净树（`/tmp/osks/osk-patch-clean`）走**构建脚本实际用的** `patch -p1` 路径，0003、0004 均 `rc=0`。

### 2.2 语法级（glib/gio + osk-stub src + rime_api.h）

```sh
$ gcc -fsyntax-only -Wall -Wextra \
    -I patches-userland/zh-ime-rime-20261123/verify/include -I src \
    $(pkg-config --cflags glib-2.0 gio-2.0) src/completers/pos-completer-rime.c
（无输出）rc=0
```

### 2.3 gschema 严格编译

```sh
$ cp osk-gate-0004/data/sm.puri.phosh.osk.gschema.xml /tmp/gschemas-final/
$ cp /tmp/osk-build/data/sm.puri.phosh.osk.enums.xml   /tmp/gschemas-final/   # 上游 mkenums 生成的 flags 定义
$ glib-compile-schemas --strict --dry-run /tmp/gschemas-final ; echo rc=$?
rc=0
```

### 2.4 aarch64 交叉重编（同一 sysroot + 同一 cross-file，**不进设备**）

```sh
$ cp -a /tmp/osk-src /tmp/osk-src.before-0004          # 备份
$ cd /tmp/osk-src && patch -p1 -N -s < …/0004-…patch ; echo rc=$?
rc=0
$ export PKG_CONFIG_LIBDIR=/tmp/trixie-sysroot/root/usr/lib/aarch64-linux-gnu/pkgconfig:/tmp/trixie-sysroot/root/usr/share/pkgconfig
$ export PKG_CONFIG_SYSROOT_DIR=/tmp/trixie-sysroot/root
$ ninja -C /tmp/osk-build
[4/5] Linking static target src/completers/libpos-completer-rime.a
[5/5] Linking target src/phosh-osk-stub
rc=0                     # 增量：只重编 rime completer + 链接；其余 warning 全为既存（如 -Wdeclaration-after-statement@:76）
$ sha256sum /tmp/osk-build/src/phosh-osk-stub
688acbe706e902d30937b033b608018f432c97c48d4fc6fdbbb4865b17a7598d
$ aarch64-linux-gnu-readelf -d … | grep -c librime.so.1
1                        # 依赖链不变
$ md5sum src/phosh-osk-stub  out/osk-stub-rime-20261123/phosh-osk-stub
66808a5c53573688fa2f538cdfc16f2a  …/userdir-20261124/phosh-osk-stub
2c040ca717084f04a3abc85bafb113fd  …/osk-stub-rime-20261123/phosh-osk-stub   # 在机件，已不同
```

> 本轮**没进 chroot**（`sudo` 需交互，本 lane 不索取）：交叉编译在宿主完成，与 11-23 那轮用同一
> `/tmp/trixie-sysroot` pkgconfig + `cross.txt`。`ninja` 增量耗时 < 1 min，**未占用 build-slot**（阈值 15 min）。

### 2.5 风格自查

`scripts/checkpatch.pl`（内核 C 规则）对 phosh 源码**不可比**：它把 GLib 的 `func (` 与 2 空格缩进全量报错，
本轮如实记录（`2 errors, 17 warnings`，无一条来自真实缺陷）。实际自查：
`awk 'length>80'` 对补丁只命中 3 行**既存**上下文（`<summary>` 原行等，非新增行）；新增续行按 `g_warning (` 左括号对齐；
块注释 `*/` 单独成行，与文件头注释一致。细节见 `NOTES-userdir-fallback.md` 末节。

## 3. 产物

| 路径 | 内容 |
|---|---|
| `patches-userland/zh-ime-rime-20261123/rime/0004-osk-stub-rime-userdir-fallback.patch` | git 格式增量补丁（2 文件 +21/−2） |
| `patches-userland/zh-ime-rime-20261123/rime/NOTES-userdir-fallback.md` | 改动点 file:line、叠加次序、门禁、风格说明 |
| `patches-userland/zh-ime-rime-20261123/rime/pos-completer-rime.c` | **同步**成修后版（仓内 .c 与补丁产物一致，除既存 `:17` 注释漂移） |
| `out/osk-stub-rime-userdir-20261124/{phosh-osk-stub,sm.puri.phosh.osk.gschema.xml,SHA256SUMS}` | 本次重编产物（sha256 见 SHA256SUMS） |

未动：`out/osk-stub-rime-20261123/`（在机件取证基线，保持原样）、`rime.completer`（逻辑未变）、
`rootfs/debian/daily-baseline.sh`、`scripts/deploy-*.sh`、git 索引。

## 4. 下一步：设备窗一次 divert+hold 部署（需人手/授权，本 lane 未做）

```sh
# 0) 上机前先撤销 11-24 的 dconf 工作区绕法（要证的是代码兜底，不是配置）
su -l xuqianhui1001 -c 'XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
  gsettings set sm.puri.phosh.osk.Completers.Rime user-data ""'
# 1) 换件（PITFALLS #654 形态）
scp phosh-osk-stub sm.puri.phosh.osk.gschema.xml root@192.168.7.1:/tmp/
install -m755 /tmp/phosh-osk-stub /usr/bin/phosh-osk-stub          # divert 已在
cp /tmp/sm.puri.phosh.osk.gschema.xml /usr/share/glib-2.0/schemas/ && glib-compile-schemas /usr/share/glib-2.0/schemas/
apt-mark hold phosh-osk-stub
# 2) 让 osk-stub 重建（phosh 会在需要键盘时重新拉起）
```

三条判据（全自动可判）：

1. `journalctl _COMM=phosh-osk-stub --since -5min | grep -c 'Error creating user data dir'` = **0**（user-data 仍为空时）；
2. `~/.local/share/rime/{build,*.userdb}` 被 osk-stub 自己建出，属主 = `xuqianhui1001`（证明 XDG 兜底生效，产物不再落 cwd）；
3. `gsettings get sm.puri.phosh.osk.Completers.Rime user-data` 仍为 `''`（证明修复来自代码而非配置），
   且键盘/英文照打（不阻塞）。

回退：`dpkg-divert --rename --remove /usr/bin/phosh-osk-stub && apt-mark unhold phosh-osk-stub`（回收旧件）。

## 5. 来源

- `reports/d3-rime-ondevice-20261124.md` §0b/§6（技术债条目 = 本 lane 的任务定义）、`reports/rime-completer-userdir-20261124.md` §1.2/§3.3
- `reports/ime-rime-backend-20261123.md` §1.3（`-fsyntax-only` 命令）、`out/osk-stub-rime-20261123/DEPLOY.md`（部署/divert 配方）
- 上游行号：`rime_api.h:74-75`（`RIME_PROVIDED` 只判非 NULL）、`librime 1.13.1 src/rime/lever/deployment_tasks.cc:82-92`
