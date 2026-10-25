# gunyah_share_mod — 独立内核模块(不改内核源码)

把 in-tree 的 gunyah `SHARE_BLOB` 改动 + "命门探针" lend/share 探针,从内核源码树中**完全解耦**为一个独立 `.ko`。编译/加载这个模块不需要修改 `drivers/virt/gunyah/` 下任何文件。

对应的原始改动备份在:`~/gunyah-share-backup-129ebe2013a8/`
(基线 commit、tracked patch、两个新文件)。

## 它是怎么做到"不改内核"的

原 patch 有三处插进 gunyah 核心的钩子,模块无法直接表达,这里用三种手段绕开:

| 原 patch 改动 | 模块里的替代手段 |
|---|---|
| 在 `gh_vm_ioctl()` 的 switch 里加 `GH_VM_ANDROID_SHARE_BLOB` | 模块自带 `/dev/gunyah_share` 字符设备,ioctl 里把 gunyah VM fd 作为参数传入 |
| `gh_vm_mem_share_blob()` 新函数 | 在模块内**逐行复刻**,调用 gunyah 内部 helper |
| `gh_share_probe_register()` 由 `gh_vm_start()` 调用 | debugfs 触发行直接带上 VM fd,不再依赖核心回调 |

未导出/static 的内部符号(`gh_vm_mem_alloc`、`gh_rm_mem_share`、`gh_rm_mem_lend`、
`__gh_vm_mem_find_by_label`、`gh_vm_mem_reclaim_mapping`、`gh_vm_ioctl`)在加载时
通过 kallsyms 解析地址(经 kprobe 拿 `kallsyms_lookup_name`),用函数指针调用,
绕过 `EXPORT_SYMBOL` 链接限制。`struct gh_vm` / `struct gh_vm_mem` 的私有布局按
本内核(6.1.118)**原样 vendored** 进 `.c`。

## 前置条件

- 内核 `CONFIG_KPROBES=y`、`CONFIG_KALLSYMS=y`(本树已满足)。
- gunyah 驱动**先于**本模块加载(否则符号解析失败,init 返回 -ENOENT)。
- `CONFIG_MODULE_SIG_PROTECT=y`(GKI 强制签名):本 `.ko` 必须用内核同一把 key
  签名,或启动时关闭 sig 强制,否则 `insmod` 被拒。

## 构建

需要 GKI `out/` 已完整 build 过(`~/kernel/build.sh` 跑过一次即可),用同一套 clang
工具链编译,保证 vermagic 与 `struct gh_vm` 布局完全一致。已在 6.1.118 验证通过:

```sh
cd ~/gunyah_share_mod
./build.sh            # = make -C common O=out M=$PWD modules (clang/LLVM)
./build.sh clean      # 清理
```

产物 `gunyah_share_mod.ko`:vermagic `6.1.118-g129ebe2013a8`,`depends:` 为空,
未定义符号只有核心内核符号(无任何 gunyah 链接依赖,全部运行时 kallsyms 解析)。

```sh
# 推到设备后(需 gunyah 已就绪;CONFIG_GUNYAH=y 时它已内建,直接可用):
insmod gunyah_share_mod.ko
```

## 用法

### SHARE_BLOB(生产路径)

```c
#include "uapi_gunyah_share.h"
int vmfd = /* 你已持有的 gunyah VM fd */;
int gs = open("/dev/gunyah_share", O_RDWR);
struct ghsm_share_blob b = {
    .vm_fd = vmfd, .label = L, .flags = GH_MEM_ALLOW_READ | GH_MEM_ALLOW_WRITE,
    .guest_phys_addr = gpa, .memory_size = sz, .userspace_addr = (uintptr_t)buf,
};
ioctl(gs, GHSM_SHARE_BLOB, &b);   // 返回后 b.mem_handle 即 RM memparcel handle
```

与 in-tree 唯一的 ABI 差异:不再是 `ioctl(vmfd, GH_VM_ANDROID_SHARE_BLOB)`,
而是 `ioctl(/dev/gunyah_share, GHSM_SHARE_BLOB)` 且结构体里多一个 `vm_fd`。

### lend/share 探针(throwaway,验证完即可删)

```sh
# "<vm_fd> <size_hex> [1=LEND(默认)|2=SHARE]"
echo "7 0x100000 2" > /sys/kernel/debug/gh_share_probe
dmesg | grep gunyah_share   # 看 handle / host_pa / magic
```

## 风险

这是**刻意 fragile** 的方案:依赖 gunyah 私有 struct 布局与内部符号名。gunyah 驱动
一旦改动,需重新 vendor `struct gh_vm` 并核对符号表。任何要正式发布的东西,优先用
备份里的 in-tree patch。
