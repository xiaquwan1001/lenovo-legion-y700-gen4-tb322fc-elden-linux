# T14/T17「S3 + S4 + S6」主机侧离线复核（2026-11-14）

> 性质：**离线复核**，不是新结论。目标是回答「S3 固件传感器 DSP 目录 / S4 `depmod -b` /
> S6 18 个 systemd unit + `systemd-analyze verify` 到底还差什么」，全部命令零 sudo、零设备、零写盘
> （只在 `/tmp` 与 `out/` 的既有副本上跑）。
> 结论先行：**三项都已经在这个仓库里实现并有门禁**（`rootfs/debian/elden-firmware/{build.sh,paths-qcom.txt}`、
> `rootfs/debian/stage.sh` 的 B/D/G/H 段），本轮独立复跑拿到数字；**唯一剩下的缺口 = `elden-hapticd`
> 二进制不在仓库（T14 债务，`MANIFEST repo_src=-`）**，与 `stage.sh --check` 的 WARN D2 同一条。

## 0. 数字结论

| 步 | 判据 | 本轮实测 |
|---|---|---|
| **S3** | 传感器 DSP 树（`/usr/share/qcom/sm8750/LENOVO/TB322FC`）进固件包并带三项必备（`sensors/sns_reg.conf` + `sensors/config/` + `sensors/registry/`） | 已在 `paths-qcom.txt`（第二内容树）+ `qcom_stage()` 门禁 A' 内；暂存树 `out/stage-debian/usr/share/qcom/sm8750/LENOVO/TB322FC/` 存在 ✅ |
| **S4** | `depmod -b <暂存根> <UTS>` 免 root、vermagic 逐字、`modules.dep` 无 not found | **rc=0**；**1529** 个 `.ko`、`modules.dep` **1529** 条依赖、`not found` **0** 行；`modinfo -F vermagic` 全量 **1529/1529 逐字相同** = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163 SMP preempt mod_unload aarch64` ✅ |
| **S6** | 单元语法/ExecStart 在暂存树内可解析；启用状态与依赖名 | 暂存树 **19** 个单元文件（`out/stage-debian/usr/lib/systemd/system/*.service`）；`systemd-analyze verify --root=… --recursive-errors=no` = **15 clean / 4 未解析**（明细见 §3）；`stage.sh --check` = **FAIL=0 WARN=1**（WARN D2 = hapticd 二进制） |

## 1. 复现命令（原样可跑）

```sh
cd /home/xuqianhui/y700-elden
UTS=7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk163

# S4：在暂存树副本上跑 depmod（不污染 out/）
rm -rf /tmp/stage-verify && cp -a out/stage-debian /tmp/stage-verify
depmod -b /tmp/stage-verify "$UTS"; echo rc=$?
find /tmp/stage-verify/lib/modules/$UTS -name '*.ko' | wc -l                       # 1529
grep -c '' /tmp/stage-verify/lib/modules/$UTS/modules.dep                          # 1529
grep -c 'not found' /tmp/stage-verify/lib/modules/$UTS/modules.dep                 # 0
find /tmp/stage-verify/lib/modules/$UTS -name '*.ko' -print0 \
  | xargs -0 -n1 modinfo -F vermagic | sort | uniq -c                               # 1 行 × 1529

# S6：逐单元 verify（⚠ 必须 --recursive-errors=no，见 §2 的坑）
cd /tmp/stage-verify/usr/lib/systemd/system
for u in *.service; do
  printf '%-32s ' "$u"
  systemd-analyze verify --root=/tmp/stage-verify --recursive-errors=no \
    "/usr/lib/systemd/system/$u" >/dev/null 2>&1 && echo ok || echo FAIL
done

# 仓库自带门禁（覆盖 A–I 九段，含固件双树、模块、单元、语义红线、启用状态、依赖名）
bash rootfs/debian/stage.sh --check
```

## 2. 坑：`systemd-analyze verify --root=<overlay 树>` 不加 `--recursive-errors=no` 会假红

`out/stage-debian` 是 **overlay**（只有我们加的东西），不是完整 rootfs。直接

```sh
systemd-analyze verify --root=/tmp/stage-verify /usr/lib/systemd/system/*.service
```

会输出 **100+ 行 `Unit <发行版单元> not found.`、rc=1**（`alsa-restore.service`、`apt-daily.service`、
`bluetooth.service` …），看起来像「18 个单元全坏」，实际只是**依赖的发行版单元不在 overlay 里**。
这类假红只能靠两条判据排除：① `--recursive-errors=no`（只校验指定单元）；② 把 `ExecStart` 路径**在暂存树内**
逐条解析（`stage.sh` 的 D2 段就是后者，且它会区分 overlay ∪ `PKGROOT`）。

## 3. S6 的 15 clean / 4 未解析明细（全部有归属，无未知项）

| 单元 | 未解析的 ExecStart | 归属 | 何时闭合 |
|---|---|---|---|
| `elden-hapticd.service` | `/usr/local/bin/elden-hapticd` | **我们的件**，`MANIFEST.tsv` 里 `repo_src=-`（`elf, aarch64 静态, 729312 B, sha256 aca55cb1…`） | **T14 债务**：仓库无源码/无构建 recipe；`out/hapticd/elden-hapticd` 的 sha 与 MANIFEST 一致但 `out/` 不入库 ⇒ 目前**不可复现** |
| `greetd.service` | `/usr/sbin/greetd` | Debian 包（M5 chroot 装 `apt-list`） | chroot 步骤 |
| `iio-sensor-proxy.service` | `/usr/libexec/iio-sensor-proxy` | Debian 包 | chroot 步骤 |
| `ssc-udp-relay.service` | `/usr/bin/python3` | Debian 包 | chroot 步骤 |

`ssc-udp-relay` 的脚本本体（`/usr/local/bin/ssc-udp-relay.py`）在暂存树里，只缺解释器 ⇒ 属跨发行版必然项。

`stage.sh --check` 的 D2 段已把这一条写成 **WARN（不是 FAIL）**，并明确标「设备侧二进制（T14 债务）」——
即当前门禁口径正确：overlay 阶段只保证「我们自己铺的东西都在」，发行版件与未复现的自家 ELF 分开记。

## 4. 结论 / 下一步

- **S3、S4、S6 不需要再做「实现」**；本轮把它们从「待办」降为「已实现 + 已离线复核」，证据 = 本文件 §0 的数字。
- **唯一真缺口 = T14 三件不可重建的用户态件**（`ffrumble`、`waydroid-sensord(-udp)`、`elden-hapticd`；
  前两者见 `reports/userland-service-inventory-20261025.md:37,55-58`）。它同时是 S6 的 WARN D2 与换根后的
  「振动/传感器 HAL 静默消失」风险 —— **纯主机可做，但需要写源码/recipe，不是验证动作**。
- 换根前的设备侧动作仍只有 S7 一条 `fastboot boot`（`reports/modular-mobian-transition-20261026.md` §6 M6），本轮未做、也不该在无设备时做。
