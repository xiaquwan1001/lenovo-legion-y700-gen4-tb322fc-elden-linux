# #410–#412 · 迁移门禁三坑：依赖闭包模拟用错 status、管道 SIGPIPE 误判、rsync 漏空目录

> 2026-10-26 · 场景 = Debian/Mobian 迁移物料（`rootfs/debian/`）的门禁建设。
> 三个坑都会让门禁**说谎**（假绿或假红），且都不报错、只在数字上体现。

## #410 依赖闭包模拟必须用**空 dpkg status**，不能用 chroot 现成那个

**现象**：`apt-get -s install $(apt-list)` 报「python3 / libglib2.0-bin / sysvinit-utils 不在闭包里」，
于是我在 `pkgmap.tsv` 里补了 `add` 行并写进报告说「缺 7 个包」。改用空 status 复测：
**这 3 个其实闭包会带**（由 waydroid/gvfs/init-system-helpers 等 Depends 拉进来）；
真正缺的只有 **3 个**：`alsa-ucm-conf` / `ca-certificates` / `login`。

**根因**：`-o Dir::State::status=$CHROOT/var/lib/dpkg/status` 把 chroot 里**已装**的包当成「已在系统上」，
apt 对它们输出的是 `python3 已经是最新版`，而不是 `Inst python3`。而那个 chroot 是用
`scripts/host-arm64-chroot.sh` 建的，里面已有 `build-essential`（连带 python3、libglib2.0-bin、sysvinit-utils）。
⇒ 「Inst 里没有」= 「目标系统不需要装」这个推论在**非空 status** 下不成立。

**正确做法**（已落进 `rootfs/debian/tools/check-pkgmap.sh` E 段）：
```bash
: > /tmp/elden-empty-status
apt-get -s --no-install-recommends \
  -o Dir::State::status=/tmp/elden-empty-status \
  -o Dir::State::Lists=$CHROOT/var/lib/apt/lists \
  -o APT::Architecture=arm64 ... install $(cat apt-list.txt) \
 | awk '/^Inst /{print $2}'
```
得到的才是「**minbase 根上真会装上**」的集合。

**教训**：任何「闭包/依赖差集」的判断，先问「status 是哪来的」。用现成环境做模拟 =
把环境的历史当成了依赖关系。

## #411 `dpkg-deb -c | grep -q` 在 `set -o pipefail` 下会把「文件在」判成「缺失」

**现象**：`stage.sh` 的固件门禁报 `FAIL 包内缺 qcom/sm8750/adsp.mdt`，但 `dpkg-deb -c` 手工跑明明有。

**根因**：`grep -q` 命中第一条就退出并关闭管道 → `dpkg-deb` 的 tar 子进程吃 SIGPIPE
（stderr 可见 `dpkg-deb: 错误: tar 子进程被信号(断开的管道) 终止了`）→ 整条管道非 0 →
`if 管道; then ok else bad` 走 else。与 `PITFALLS #199`（fastboot 客户端不得接 `head`/`grep -q`）
是同一类错误的另一处落点。

**正确做法**：先落清单到临时文件，再 grep：
```bash
DEB_LIST=$(mktemp); dpkg-deb -c "$DEB" > "$DEB_LIST" 2>/dev/null || die ...
grep -qF "./lib/firmware/qcom/sm8750/adsp.mdt" "$DEB_LIST"
```
**排查线索**：看到 `tar 子进程被信号(断开的管道) 终止` 就是它；`set -euo pipefail` 的脚本里尤其致命。

## #412 `rsync --files-from` 不传空目录 → 「目录存在」的门禁假红，且布局会缺一层

**现象**：传感器 DSP 树门禁报 `MISS(qcom) .../sensors/registry/ 为空`，而设备上 `registry/` 本来
就是**空目录**（`find ... | wc -l` = 1，只有目录本身）。另外我第一次把门禁路径写成
`.../TB322FC/sns_reg.conf`，实际是 `.../TB322FC/sensors/sns_reg.conf`。

**两条事实**：
- `rsync --files-from=<file>` 只搬清单里列出的**文件**，不会为文件隐式创建的空目录建目录
  ⇒ 空目录必须 `mkdir -p` 显式补（否则 `-R` 根下的相对路径少一层，DSP 读会 ENOENT）。
- `hexagonrpcd` 的 `-R` 根是 `.../LENOVO/TB322FC`，而载荷在 `sensors/` 子目录下
  （DSP 请求自带 `sensors/` 前缀）。看 `-R` 值时别顺手少写一层。

**附带教训**：门禁判「目录非空」时，先确认**源**本身是否为空——否则门禁在惩罚正确行为。
对这类「源就是空的」目录，判据要降级成「目录存在」。

## 复现

```bash
# #410 正/反两版
: > /tmp/s                           # 空 status = minbase 模拟（正确）
git show HEAD:rootfs/debian/apt-list.txt > /tmp/old.txt
apt-get -s -o Dir::State::status=/tmp/s -o Dir::State::Lists=/opt/elden/arm64-sid/var/lib/apt/lists \
  -o APT::Architecture=arm64 install $(cat /tmp/old.txt) | grep -cE '^Inst '     # 816
apt-get -s -o Dir::State::status=/opt/elden/arm64-sid/var/lib/dpkg/status \
  -o Dir::State::Lists=/opt/elden/arm64-sid/var/lib/apt/lists \
  -o APT::Architecture=arm64 install $(cat /tmp/old.txt) | grep -cE '^Inst '     # 674（被已装包吃掉）

# #411
dpkg-deb -c out/debian/elden-firmware_*_all.deb | grep -q adsp.mdt ; echo "rc=$?"   # 会打印 SIGPIPE

# #412
ssh root@192.168.7.1 'find /usr/share/qcom/sm8750/LENOVO/TB322FC/sensors/registry | wc -l'   # 1 = 空目录
```
