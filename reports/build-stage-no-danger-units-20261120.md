# lane C：构建器 stage 不装危险件（P0-2，2026-11-20）

结论先行：**危险单元已从构建链三处封死**（基线清单禁装 → stage 构建/门禁 mask → build-rootfs 装后门禁），
`bash -n` 3 个脚本全过、`check-pkgmap.sh` FAIL=0、`stage.sh --check` 新增门禁全绿、
`check-doctor.sh` **FAIL=0 WARN=7（全是 C 类存量）**。设备侧验证留作需上机项。

## 1. 来源链（谁把危险件装进来的）

逐个 grep 了 `rootfs/debian/`（build-rootfs.sh、daily-baseline.tsv、daily-baseline.sh、apt-list.txt、
apt-list-min.txt、pkgmap.tsv、overrides.tsv、debian-exclude.tsv、stage.sh、svc-deps.tsv）、
`scripts/mobian-daily-baseline.sh`、`scripts/deploy-desktop-shell.sh`、`packaging/elden-userland/`：

| 危险件 | 来源 | 证据（grep 原文行） |
|---|---|---|
| `hexagonrpcd` | **基线清单显式装 + stage 显式预启用**（唯一直接来源） | `rootfs/debian/apt-list.txt:55`（原 `hexagonrpcd` 活行）；`rootfs/debian/pkgmap.tsv:181`（原 `hexagonrpcd	add	hexagonrpcd	SSC 用户态守护…`）；`rootfs/debian/stage.sh:227-228`（原 `ln -sfn /usr/lib/systemd/system/hexagonrpcd.service  "$STAGE/etc/systemd/system/default.target.wants/hexagonrpcd.service"` 预启用） |
| `droid-juicer` | **不在任何基线清单/脚本里**（repo grep 零命中，仅 deploy-desktop-shell.sh 的运行时 mask 提到） | `grep -rnE 'droid-juicer' scripts/ rootfs/ packaging/ initramfs/` → 除 deploy-desktop-shell.sh 外无输出 |
| `plymouth×4` | 同上，**不在基线清单**（应为依赖/现场带入） | 同上；另证：主机两套构建产物 `/opt/elden/mobian-rootfs`、`/opt/elden/arm64-sid` 的 `var/lib/dpkg/status` 中 `^Package: (droid-juicer\|plymouth)$` 均为 **0 命中**（builder 从未装过它们） |

⇒ 处置分两类：hexagonrpcd 走「清单移除」（指令 ①）；droid-juicer/plymouth 走「stage 构建/基线侧
mask 落盘」（指令 ②/③：不装拦不住，必须在 stage 里 mask）。

## 2. 处置（本轮改动，5 个文件）

1. **`rootfs/debian/pkgmap.tsv`**：`hexagonrpcd` 行 `add → drop`，加注释「永不安装：attach ADSP
   硬崩整机（PITFALLS #692/#694）」+ 崩因摘要。
2. **`rootfs/debian/tools/check-pkgmap.sh`**：禁用项 case 增加 `hexagonrpcd`（与 linux-image-* 同级门禁，
   防止将来被改回 add）。
3. **`rootfs/debian/apt-list.txt`**：由 `check-pkgmap.sh` 重新生成（非手改），`hexagonrpcd` 已不在
   （149 个包；`grep hexagonrpcd apt-list.txt` → 无输出）。
4. **`rootfs/debian/stage.sh`**：
   - 原 hexagonrpcd `default.target.wants` 预启用块 → **无条件 mask**（`hexagonrpcd.service -> /dev/null`）；
     drop-in 与 `hexagonrpcd-adsp-sensorspd` 别名**保留**（等崩因定位后恢复只差删一条 symlink；
     iio-sensor-proxy 的 `After=` 对 masked 单元合法，不会成环）。
   - 新增「危险单元构建期 mask」段：`droid-juicer / plymouth-start / plymouth-quit /
     plymouth-quit-wait / plymouth-switch-root` 各建 `-> /dev/null` 悬空 symlink（幂等，
     对不存在的单元也合法；与设备侧 `scripts/deploy-desktop-shell.sh` 的 `STUCK_UNITS` 同一清单）。
     只 mask、不 rm 包文件，不在 build-rootfs.sh 里引入 systemd 之外的花活。
   - 门禁段新增 6 条 mask 断言（readlink 必须逐字 = /dev/null）。
5. **`rootfs/debian/build-rootfs.sh`**：
   - 前置门禁加 `grep -qE '^hexagonrpcd$' "$APTLIST" && die …`（与 linux-image 门同位）。
   - 最小档与桌面档门禁各加一组：6 个 mask symlink 断言 + `dpkg-query -W hexagonrpcd` 禁装断言。

明确记录（指令 ③）：**plymouth×4 按「必须 stage mask 而不是不装」处置**——它不在任何显式清单里，
来源是依赖/现场带入，删除清单拦不住；mask 落盘后即使被带入，首启 `is-enabled` = masked、不会挂进队列。

## 3. 验证（静态）

- 语法：`bash -n` → `stage.sh` / `build-rootfs.sh` / `tools/check-pkgmap.sh` 全部 OK。
- `bash rootfs/debian/tools/check-pkgmap.sh` → `统计: map=97 drop=24 add=16 解析失败=0 … 结果: FAIL=0 WARN=0`，
  apt-list.txt 已再生且无 hexagonrpcd。
- `bash rootfs/debian/stage.sh --check`（重建后的 out/stage-debian）新增门禁实测输出：
  ```
  ok    mask 在: hexagonrpcd.service -> /dev/null
  ok    mask 在: droid-juicer.service -> /dev/null
  ok    mask 在: plymouth-start.service -> /dev/null
  ok    mask 在: plymouth-quit.service -> /dev/null
  ok    mask 在: plymouth-quit-wait.service -> /dev/null
  ok    mask 在: plymouth-switch-root.service -> /dev/null
  ```
- `timeout -k 3 200 bash scripts/check-doctor.sh` → **FAIL=0 WARN=7**；7 条 WARN 全为 C 类存量
  （geekidos-linux 源树已档 75 行暂不可核、账本 uts_dup 例外、4 个 posctrl 旧 boot 镜像解不出、
  无 .config/无构建树跳过、`reports/dwc3-v10-plan-20261120.md` 无人引用——是别的 lane 的产出），与本轮无关。
- **存量备注（非本轮引入）**：`stage.sh --check` 另有 3 条 MANIFEST sha FAIL
  （q28-race-hunt.sh / elden-session-user / time-sync.sh，repo 副本被其他 lane 改过而 MANIFEST 未更新）；
  本轮 diff 只含上述 5 个文件（`git diff --stat` 可证），未触碰这些文件。
- debugfs 只读核对：本轮未产出新镜像；`out/android-slim-v3-20261119/new/` 为 Android 侧 super/system，
  与 Debian 用户态单元无关，不适用。旧产物 `/opt/elden/mobian-rootfs` 是**改动前**构建（hexagonrpcd
  已装、无 mask），重建后由 build-rootfs.sh 新门禁把关。

## 4. 新根首启判据（需上机）

重建根（`sudo bash rootfs/debian/build-rootfs.sh`）上机首启后：

```
systemctl is-enabled droid-juicer hexagonrpcd plymouth-quit
# 期望三条均 = masked（stage 落了 /dev/null symlink；对不存在的 plymouth 依赖也判 masked）
systemctl is-active  droid-juicer hexagonrpcd plymouth-quit-wait   # 期望 inactive
systemctl list-jobs | grep -c running                               # 期望 0（queue 不被卡）
```

判 `masked` 而非 `not-found`：plymouth 系若被依赖带入，单元文件存在但被 mask ⇒ is-enabled 输出
`masked`；若真没带进来且 stage 的悬空 mask 仍指向 /dev/null，systemd 同样报 `masked`（悬空 symlink
对 systemd 是合法 mask）。若输出 `not-found` 说明 stage 层被跳过（构建门禁 FAIL 应已拦截）。
另：hexagonrpcd 一旦因传感器链需要恢复，先在设备上复现 #692 崩因（取证通道就绪后），再删
stage 里那条 mask symlink，别名/drop-in 已就位、无需重写配置。
