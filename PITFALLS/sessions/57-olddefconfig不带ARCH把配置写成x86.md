## 五十七、`make olddefconfig` 不带 `ARCH`/`CROSS_COMPILE` 会把配置写成 x86（#362，2026-10-20 实受）

**现象**：给 vk129 树重编模块，`make modules` 跑起来先进入 **Kconfig 交互提问**：

```
Compile the kernel with warnings as errors (WERROR) [N/y/?] n
Local version - append to kernel release (LOCALVERSION) [-debug] -debug
Kernel compression mode
> 1. Gzip (KERNEL_GZIP) (NEW)
  2. Bzip2 (KERNEL_BZIP2) (NEW)
...
choice[1-7?]:
Error in reading or end of file.
make[1]: *** [Makefile:2179：modpost] 错误 2
```

我当时把它当成「配置过期」，跑 `make olddefconfig` 修 —— **这是错的**，两处都错：

- **交互提问本身不是「过期」**，是 `syncconfig` 需要回答一个尚未生成的选项；`make syncconfig < /dev/null` 就能过。
- **`make olddefconfig` 我没带 `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`**，
   于是它用**宿主机 x86 编译器**重新推导，把整个 `.config` 重写成 x86 配置：

```
< # Linux/arm64 7.3.0-rc7 Kernel Configuration
> # Linux/x86 7.3.0-rc7 Kernel Configuration
< CONFIG_CC_VERSION_TEXT="aarch64-linux-gnu-gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0"
> CONFIG_CC_VERSION_TEXT="gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0"
< CONFIG_DRM_SCHED=y        → CONFIG_DRM_SCHED=m
< CONFIG_SND_COMPRESS_OFFLOAD=y → =m
```

**为什么差点没发现**：`.config` 的 sha256 我事先存了（`/tmp/cfg-before-sync.txt`），
但 `make olddefconfig` 报告的却是 **"No change to .config"** —— 因为它比较的是它自己刚写的那份。
**必须先做备份再比，且比的是「改动前快照」不是它自己的输出。**

**正确做法**

```bash
# 恢复真实构建态（本项目 vk129 的权威快照）
cp patches/config-suspend-s2idle-20261018-173529 build/m1-73/.config
# 验证与镜像内嵌 ikconfig 逐字相同 —— 这是唯一可靠的「真实构建态」判据
diff -q /tmp/<从镜像抽的>/ikconfig.txt build/m1-73/.config && echo OK
```

**更根本的做法**：**别用 `olddefconfig` 去「修」一个想保持逐字不变的配置**。
真正需要同步时，必须带全套参数：

```bash
make -C <tree> ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
```

**教训（层级）**

- 任何 `make <target>` 作用于交叉编译树，**`ARCH`/`CROSS_COMPILE` 必须每次都给**。
   漏一次就可能静默重写 `.config`，而 `.config` 决定 ABI（见 #360），后果是启动即死。
- **「真实构建态」的唯一可信来源是镜像内嵌的 ikconfig**（`IKCFG_ST`…`IKCFG_ED`，gzip 段），
   不是工作树里的 `.config`。核对方法见本节末。
- `make olddefconfig` 说 "No change" 不等于没改 —— 它的基线是它自己。

**从镜像抽 ikconfig 的方法**（本项目实测可用）

```python
import zlib
d = open('Image','rb').read()          # Image.gz 解开后的 Image
s = d.find(b'IKCFG_ST') + 8
cfg = zlib.decompress(d[s:s+400000], 16+zlib.MAX_WBITS)   # gzip 段，wbits=16+MAX
```

**证据**：`build/m1-73/.config` sha `52ae455f…`（正确）vs `0fb67a2f…`（被写成 x86）；
恢复后与 `/tmp/vk129x/ikconfig.txt` 逐字相同。
