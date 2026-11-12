# #625 主机重启后构建树的 `.o` 会静默损坏（ld 报 bad reloc / segfault，看着像内核或补丁坏了）

- 日期：2026-11-12
- pi 会话 id：本项目会话（11-12 晚）
- 主题：上游合并批 1 + 待机功耗线重启时的构建事故与处置

## 现象（两个假象叠在一起）

- `scripts/build-kernel.sh` 在 `LD vmlinux.unstripped` 处 **Segmentation fault（错误 139）**，
   `make` 自动删除 `vmlinux.unstripped` 并退出 ⇒ 看起来像「内核代码/新补丁把链接器搞崩了」。
- 重跑一次变成 **`ld.bfd: final link failed: bad value`**，报
   `drivers/clk/clk-en7523.o: bad reloc symbol index (0x854 >= 0x7a) for offset 0x1865 in section '.debug_info'`
   ⇒ 看起来像「新补丁把某个 .o 弄坏了」。

## 真因

**构建树里个别 `.o` 本身是坏的**（`.debug_info` 里 reloc 索引越界 = 文件被截断/写坏），
来源于上一轮构建被中断/机器异常重启后的半成品对象。`make` 只按时间戳判断新旧，
**不会重编这些对象**，于是每次都拿坏对象去链，表现为链接器崩溃或 `bad value`。

## 判据与处置

- 判据：手动跑 `aarch64-linux-gnu-ld -r -o /tmp/x.o --whole-archive vmlinux.a ...`，
  `bad reloc symbol index` 点名的那个 `.o` 就是坏件（本轮点名 2 个：
  `drivers/clk/clk-en7523.o`、`drivers/iommu/arm/arm-smmu/arm-smmu.o`）。
- 处置：删掉被点名的 `.o` 后重跑链接，**循环到 link 通过**（坏了几个就循环几次）：

```bash
for i in $(seq 1 10); do
  out=$(cd build/daily && make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- vmlinux 2>&1) && break
  bad=$(printf '%s' "$out" | grep -oE '[A-Za-z0-9_/.-]+\.o: bad reloc' | sed 's/: bad reloc//' | head -1)
  [ -n "$bad" ] || { printf '%s\n' "$out" | tail -6; break; }
  rm -f "build/daily/$bad"
done
```

- 教训：**别把 `vmlinux.unstripped` 的 segfault 先归因给新补丁**；先用 `V=1` 拿到真实 `ld` 命令行手跑一次，
  再按 `bad reloc` 点名清坏件。全量 `make clean` 能解决但代价是 20+ 分钟重建。

## 附：同轮落地的 suspend/CDSP 相关事实

- `CONFIG_SUSPEND=y` 的内核**必须配一整套同 config 编出的模块树**（`struct device.of_node` 偏移会变；
  vk128/vk129 的「背光亮一下即掉电」就是这么来的，`reports/vk129-abi-fix-verified-20261020.md` 已实证）。
  本轮 UTS 改成 `-debug-vk189-suspend`（**新目录**）并把 1499 个 `.ko` 全量重编部署，
  避免污染在机的 `-vk188-sysfbfb…` 与 `-vk184…` 两棵树。
- 打包门 `scripts/assert-kernel-sane.sh` 的 ABI 子门以 `patches/config-vk127-working-*` 为参考，
  `SUSPEND=y` 必然报差异 ⇒ 本轮用 `SKIP_KERNEL_ASSERT=1` 打包，**前提是配套模块树已换**（已换），
  并在 `versions/vk-registry.tsv` 写明理由。
