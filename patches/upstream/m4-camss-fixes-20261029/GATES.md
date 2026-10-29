# 编排者独立复核（2026-10-29，不采信 lane 自报）

系列形状 = **3 枚通用修复**（csid power-on unwind / video DMA 连续性 + `prepare_buffer` 钩子 /
video 起流失败回退）。九枚「add SM8750 support」已按 2026-10-29 列表公开承诺撤下。

## 1. 干净重放（pristine 7.3-rc7 = `24a19b953`）

```sh
git -C build/m4-base worktree add /tmp/amtest 24a19b953 -b tmp/camssfix-test
cd /tmp/amtest && git am ../../patches/upstream/m4-camss-fixes-20261029/000{1,2,3}*.patch
# 应用：csid: unwind the power-on path through a single error label
# 应用：video: check that a buffer is DMA contiguous and add a prepare hook
# 应用：video: stop the subdevices already started when a start fails
git diff --stat 24a19b953
#  camss-csid.c   | 45 +++++++-------
#  camss-video.c  | 78 +++++++++++++++----------
#  camss-video.h  |  1 +
#  3 files changed, 68 insertions(+), 56 deletions(-)
```

⇒ **3/3 干净应用**，终态与补丁集一致。

## 2. checkpatch `--strict`

```sh
./scripts/checkpatch.pl --strict --no-signoff .../000{1,2,3}*.patch
# 0001: total: 0 errors, 0 warnings, 0 checks, 70 lines checked
# 0002: total: 0 errors, 0 warnings, 0 checks, 43 lines checked
# 0003: total: 0 errors, 0 warnings, 0 checks, 89 lines checked
```

⇒ **3/3 = 0E/0W/0C**。

## 3. 编译（W=1，`build/m4-base/.config`，`ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`）

```sh
cp build/m4-base/.config .config; export LOCALVERSION=
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 \
     drivers/media/platform/qcom/camss/ -j26
# 尾行：LD [M] drivers/media/platform/qcom/camss/qcom-camss.o
# grep -iE 'warning|error' → 空
```

⇒ **rc=0 / 0 warning**（含 `LD [M]`）。

## 4. cover letter

`0000-cover-letter.patch` 原为 `*** SUBJECT HERE ***` / `*** BLURB HERE ***` 占位（`git format-patch`
未给 blurb），已补正文并机械校验纯 ASCII：

```
grep -Pn '[^\x00-\x7F]' → 无命中
```

正文要点：三枚均为既有代码缺陷、不依赖任何 SoC 使能；1/3 漏放 parent 引用、2/3 非连续 payload
静默越界、3/3 起流失败留下已启动子设备；明确声明本系列不含 SoC 使能 / DT binding / CSIPHY 改动。

## 5. 未做（仍待）

- **未投递**（需用户批准；且按 2026-10-29 决定的顺序，先修「提交形态」与信誉事件再发）。
- **未上机**：三枚中 1/3 与 3/3 是错误路径修复，2/3 改变缓冲校验行为（拒绝非连续 buffer），
  建议上机时用现有 `cam-loopback.sh` / 相机出流判据各跑一次前后摄 90 帧（判据 = 不出现新的
  `-EINVAL` 拒绝、帧率不变）。

## 6. 维护提醒：cover 正文与 `git format-patch`

`0000-cover-letter.patch` 的正文来自本目录 `COVER-BLURB.txt`。**任何一次重新
`git format-patch --cover-letter` 都会把它重置成 `*** SUBJECT HERE ***` / `*** BLURB HERE ***`**
（2026-10-29 实测发生一次）。重生成后必须重新贴回，校验：

```sh
grep -c 'SUBJECT HERE\|BLURB HERE' 0000-cover-letter.patch   # 必须为 0
grep -Pn '[^\x00-\x7F]' 0000-cover-letter.patch              # 必须无命中
```
