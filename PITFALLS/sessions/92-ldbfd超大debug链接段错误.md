# #408 GNU ld.bfd 2.46 在 1.6 GB debug 链接上 SIGSEGV：改用 LD=ld.lld（且必须写在 make 参数位）

## 现象

`make … Image.gz` 在最后一步 `LD vmlinux.unstripped` 崩：

```
Segmentation fault (core dumped)
make[2]: *** [scripts/Makefile.vmlinux:72：vmlinux.unstripped] 错误 139
```

`coredumpctl list` 明确指向 `/usr/bin/aarch64-linux-gnu-ld.bfd`（SIGSEGV）。
带 `--strip-debug` 的中间链接（`.tmp_vmlinux1/2`）**都成功**，只有带完整 debug 的最终链接崩
（同树 10-24 那次能过，本次 `vmlinux.o` 1.67 GB；不是内存不足，61 GB 空闲）。

## 修法

用 LLVM 链接器（对象仍是 gcc 编的，内核支持混用）：

```bash
make -C build/vk151 -j24 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     LD=ld.lld LOCALVERSION=-debug-vk163 Image.gz dtbs modules
```

## 两个坑

- **`LD=ld.lld` 必须放在 make 的「参数位」**：`LD=ld.lld make …`（环境变量）会被内核 Makefile 里的
   `LD = $(CROSS_COMPILE)ld` 覆盖（makefile 赋值优先于环境变量），日志里仍是 `ld.bfd` 且照样崩；
   写成 `make … LD=ld.lld`（命令行赋值）才生效。
（2）`CROSS_COMPILE="ccache aarch64-linux-gnu-"` 这种写法会把 `LD` 变成 `ccache …-ld`；
   排查链接问题时先去掉 ccache 前缀（`scripts/env-build.sh` 默认就那样设，注意甄别）。

## 副作用

`CONFIG_LD_IS_BFD` 仍是 y（Kconfig 的探测结果没变），个别只有 bfd 认识、lld 不认识的 flag 若将来出现，
判据是同一命令下 `ld.bfd` 与 `ld.lld` 的报错差异；`--orphan-handling=warn`/`-z pack-relative-relocs`
lld 都支持（本轮实测全链通过，产物上机功能正常）。
