# 模块构建三缺件 + 错 ARCH 的 `prepare` 会把生成头清空（#381）

> 日期：2026-10-24 · 场景：在 `build/vk151`（= vk152 的树）给 `gunyah_wdt` 编一个探针模块。
> 目的：单模块迭代（`mod-loop` 同型）在本树首次跑时会连撞四个坑，报错文案**全部指向错误方向**。

## 1. 现象与真因

| 报错 | 真因 | 修法 |
|---|---|---|
| `fatal error: asm/compiler.h: 没有那个文件或目录` | 没带 `ARCH=arm64` ⇒ kbuild 按**宿主 x86** 找头（`arch/x86/include`） | 每条 `make` 都带 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-` |
| `unrecognized command-line option '-mrecord-mcount'` | 同上一次错 ARCH 的运行把 `.config`/`auto.conf` 带成 `CONFIG_FTRACE_MCOUNT_USE_CC=y`（在机真值是 `..._USE_PATCHABLE_FUNCTION_ENTRY=y`） | 还原 `.config` 后必须 `make ARCH=arm64 ... syncconfig`（**只改 `.config` 不 syncconfig 无效**） |
| `error: missing argument to '-mstack-protector-guard-offset='` | 错 ARCH 的 `make prepare` 重写了 `include/generated/asm-offsets.h`，里面**没有 `TSK_STACK_CANARY`** ⇒ `arch/arm64/Makefile:76` 的 awk 取到空串 | `make ARCH=arm64 CROSS_COMPILE=... prepare` 重生成（确认 `grep TSK_STACK_CANARY include/generated/asm-offsets.h`） |
| `没有规则可制作目标“xxx.ko”，由“__modfinal” 需求` | ① 顶层缺 `scripts/module.lds`（Image/dtb 构建不生成）；② 缺 `Module.symvers` | `make scripts/module.lds`；`cp vmlinux.symvers Module.symvers`（叶子模块够用） |
| `没有规则可制作目标“tmp/gwdt/gunyah_wdt.o”` | `M=` 给了绝对路径，kbuild 去掉了前导斜杠 | `M=` 用**树内相对路径**（如 `M=.gwdt-probe`） |

## 2. 一次性可用配方

```bash
cd <tree>
sed -i 's/^# CONFIG_XXX is not set/CONFIG_XXX=m/' .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- syncconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= prepare
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= scripts/module.lds
cp vmlinux.symvers Module.symvers
mkdir -p .probe && cp drivers/.../foo.c .probe/ && printf 'obj-m := foo.o\n' > .probe/Makefile
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= M=.probe modules
modinfo -F vermagic .probe/foo.ko     # 必须逐字等于在机 uname -r
```

## 3. 纪律

- **`LOCALVERSION=` 显式置空**：否则 UTS 带 `+` ⇒ vermagic 失配（`#367` 同型，静默、无警告）。
- 改 config 前备份（`cp .config /tmp/<tree>.config.bak`），做完还原并 `syncconfig`；
  不要在共享树上留「多开一个 =m」的状态，否则下次全量构建的 ABI 与模块树不一致（`#360` 同型）。
- 只编单模块时**不需要** `make olddefconfig`（会掉 `CONFIG_ARCH_QCOM`，`#362`）；`syncconfig` 足够。

## 4. 本次实证

`gunyah_wdt.ko` 编成后 `modinfo -F vermagic` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty SMP preempt mod_unload aarch64`，
与在机 `uname -r` 逐字相同 ⇒ `insmod` 成功、驱动绑定 `gunyah-wdt`、`rmmod` 干净。
见 `reports/gunyah-stage0-positive-20261024.md` §2。
