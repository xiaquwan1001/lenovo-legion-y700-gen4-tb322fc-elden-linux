# extra/ — 仓库新增的文件（设备上**不存在**，或只以内联形式存在）

规则：`files/` 是设备副本（逐字、sha 比对、禁止手改）；`extra/` 是我们从内联 initd / local.d
里**剥离**出来的独立脚本，以及为「换 init」新增的包装。`verify.sh` 对 extra 只做
「路径与 exec 对应、语法可解析」检查，不与设备比对。

| 文件 | 来源 | 为什么剥离 |
|---|---|---|
| `usr/local/sbin/elden-powerlog-mark.sh` | `/etc/init.d/elden-powerlog` 的内联 `start()` | systemd 侧要 `ExecStart=`，内联 shell 无法复用 |
| `usr/local/sbin/pstore-catch.sh` | `/etc/init.d/pstore-catch` 的内联 `start()` | 同上（原脚本 33 行里 20 行是逻辑） |
| `usr/local/sbin/elden-bt-alias.sh` | `/etc/local.d/elden-bringup.start` 的内联子 shell | 让「蓝牙别名」成为独立可失败单元，而不是一个大 oneshot 里的一行 |
| `usr/local/sbin/elden-bootlog.sh` | `/etc/local.d/elden-bootlog.start` | 整文件搬（原本就是独立脚本，只是没进仓库） |

## 已知缺口（本目录暂不能补的）

- **`/usr/local/bin/ffrumble` 无源**：仓库里只有 `scripts/elden-hapticd.c`（bridge daemon）与
  `/usr/local/bin/vibrate`（调用 ffrumble 的封装），ffrumble 本体源码从未入库。
  取证价值明确（`reports/motor-haptics-vk127-20261017.md` 用它做阳性对照：`ffrumble /dev/input/event2 900 0xffff`）。
  补齐有两条路：① 从设备反推参数后重写成 ~60 行 EV_FF 客户端（推荐，行为已知且简单）；
  ② 若主机还有构建残留（`out/`、旧 `/tmp`）则回收 source。**未做，先登记在 `sources.tsv` 的 missing 行。**
- `waydroid-sensord` / `waydroid-sensord-udp`：源码在 `patches-userland/waydroid-sensord-udp/`，
  但构建依赖 gbinder/glibutil 开发包，`sources.tsv` 里给的是「在设备/debootstrap 环境内 make」，
  宿主交叉编译 recipe 未写。
