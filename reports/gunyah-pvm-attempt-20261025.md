# Gunyah pVM 尝试 — 2026-10-25（U1，Alpine/boot_b，kernel 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty）

> ⚠️ **错误码口径更正（2026-10-25，PITFALLS #393）**：驱动 `rsc_mgr.c:633` 用 `%d` 打印 RM 错误码，
> 所以文中 `Error: 10` = **10₁₀ = 0xA `MEM_INVALID`**（`Error: 16` 才是 0x10 `IRQ_INUSE`）。
> 2026-10-24 那份「卡在 IRQ_INUSE」的结论因此作废；本报告表格里凡是写「Error: 10（0x10/IRQ_INUSE）」的地方，
> 一律按 **0xA MEM_INVALID** 读。


## 数字结论

| # | 变体 | SET_FW_CONFIG | VM_START | dmesg 最后一行 | 判定 |
|---|------|---------------|----------|----------------|------|
| a | LEND RAM+fw, fw=真 pvmfw 1 MiB | 成功 (auth→PVM) | **失败 EINVAL** | `RM rejected message 5600000b. Error: 10`（VM_INIT, MEM_INVALID 0xA） | 未解决 |
| b | 同 a，fw 内容全 0 | 成功 | **失败 EINVAL** | 同上 | 未解决 |
| a2 | fw=真 pvmfw 2 MiB | 成功 | **失败 EINVAL** | 同上 | 未解决 |
| c1 | a + guest-v2.dtb（/gunyah-vm-config+GIC） | 成功 | **失败 EINVAL** | 同上 | 未解决 |
| c2 | a + guest-v4.dtb | 成功 | **失败 EINVAL** | 同上 | 未解决 |
| a3 | **LEND 但不调 SET_FW_CONFIG**（auth=NONE） | 跳过 | **失败 EINVAL** | 同上（VM_INIT 0xA） | 未解决 |
| d | **SHARE**(NOLEND) + SET_FW_CONFIG | 成功 | **失败 EPERM** | `RM rejected message 56000009. Error: 3`（VM_CONFIGURE, DENIED）+ `56000002 Error: 20`（dealloc vmid） | 未解决 |
| — | 旧基线（SHARE, 无 fw, auth=NONE，上一轮） | — | 失败 | `RM rejected ... Error: 10`(0x10=IRQ_INUSE) | 未解决 |

**关键新信息：RM 错误码变化。**
- 老错误：VM_INIT 被拒，RM 错误 **0x10 = GUNYAH_RM_ERROR_IRQ_INUSE**。
- 本轮 LEND 路径：VM_INIT 被拒，RM 错误 **0xA（十进制 10）= GUNYAH_RM_ERROR_MEM_INVALID** —— 这是新错误码，说明 **LEND 语义本身改变了 RM 的拒绝理由**，不再卡 IRQ_INUSE。
- SHARE+SET_FW_CONFIG 路径：死得更早，**VM_CONFIGURE（msg 0x09）即被 DENIED(0x3)** —— RM 明确拒绝「SHARE 内存 + PVM auth」组合。

## 命令原文与原始输出

### 1. pvmfw 只读取证

```
$ ssh root@192.168.7.1 'ls -l /dev/disk/by-partlabel/pvmfw_a /dev/disk/by-partlabel/pvmfw_b; blockdev --getsize64 ...'
lrwxrwxrwx ... pvmfw_a -> ../../sde29
lrwxrwxrwx ... pvmfw_b -> ../../sde61
1048576
1048576

$ dd if=/dev/disk/by-partlabel/pvmfw_a bs=1M count=2 | xxd | head
00000000: 414e 4452 4f49 4421 80be 0b00 ...  "ANDROID!"...
00000010: a501 0020 2c06 0000 ...
（gzip -t → "not in gzip format"，即原始 Android bootimg）
md5: 73a3d6e6af89dc62f91994fc7278ac2a  /tmp/pvmfw.img
file: Android bootimg, kernel, ramdisk (0x62c)
```

结论：pvmfw_a/b 各 **1 MiB**，内容是**未压缩的 Android bootimg**（含 kernel+ramdisk），直接整块 1 MiB 作 fw 镜像。

### 2. 代码改动

`tools/gunyah-modules/vmmtest/vmmtest.c` 新增 `PVM2=1` 模式（默认行为未动）：
- `GH_VM_ANDROID_LEND_USER_MEM` (0x11, struct gunyah_userspace_memory_region 同布局) 注册 guest RAM（label 1, RWX）与独立 fw 区（label 2, gpa = gpa+8 MiB 取 2 MiB 对齐 = 0x80800000）；
- env：`PVMFW=<file>`（fw 内容）、`FWSZ`（默认 0x100000）、`FWZERO=1`（全 0）、`NOLEND=1`（退回 SHARE 0x1）、`NOFWCFG=1`（跳过 SET_FW_CONFIG）；
- `SET_FW_CONFIG(fw_gpa, fw_size)` 失败即打印 errno 停止；每次跑前设备端 `dmesg -C`。

**过程中修的一个 bug**：fw 区最初放 gpa+0x200000，落在 8 MiB guest RAM 区间内 → 驱动 `mtree_insert_range` 返回 **EEXIST**（binding 区间重叠）。改到 0x80800000 后通过。

### 3. 变体 a（LEND + 真 pvmfw 1 MiB）

```
$ dmesg -C; timeout 20 env PVM2=1 PVMFW=/tmp/pvmfw.img FWSZ=0x100000 ./vmmtest ./stub.bin ./guest.dtb
payload: stub 20 B, dtb 353 B
vm fd = 4
dtb config: gpa 0x80001000 size 0x1000
pvmfw: loaded 1048576 B into fw region
guest RAM registered (ioctl 0x4111): gpa 0x80000000 size 0x800000
fw region registered: gpa 0x80800000 size 0x100000
fw config: gpa 0x80800000 size 0x100000 (pVM2 auth)
VM_START: Invalid argument
exit=1
[  832.363553] ... RM rejected message 5600000b. Error: 10
[  832.363566] misc gunyah: Failed to initialize VM: -22
```

注意：**没有**出现 `Failed to configure VM` / `Failed to configure pVM firmware` / `Failed to set location of DTB mem parcel` —— 即 vm_start 里的 `vm_configure(auth=PVM)`、`set_firmware_mem`、`set_address_layout` 全部成功，死在最后一步 `vm_init`（msg 0x5600000b 的低字节 0x0b）。错误 10 是**十进制**，对照驱动枚举 = **0xA = MEM_INVALID**。

### 4. 变体 b（fw 全 0）

```
env PVM2=1 FWZERO=1 FWSZ=0x100000 →
VM_START: Invalid argument
[  911.827318] RM rejected message 5600000b. Error: 10
[  911.827331] Failed to initialize VM: -22
```

### 5. 变体 a2（fw 2 MiB）

```
env PVM2=1 PVMFW=/tmp/pvmfw.img FWSZ=0x200000 →
fw region registered: gpa 0x80800000 size 0x200000
VM_START: Invalid argument
[  911.948504] RM rejected message 5600000b. Error: 10
```

### 6. 变体 d（SHARE + SET_FW_CONFIG，对照）

```
env PVM2=1 NOLEND=1 PVMFW=/tmp/pvmfw.img FWSZ=0x100000 →
guest RAM registered (ioctl 0x4701)
VM_START: Operation not permitted
[  912.074931] RM rejected message 56000009. Error: 3      ← VM_CONFIGURE, DENIED
[  912.074941] Failed to configure VM: -1
[  912.089280] RM rejected message 56000002. Error: 20     ← 清理路径 dealloc vmid
[  912.089292] Failed to deallocate vmid: -74
```

### 7. 变体 c1/c2（换 DTB）

```
env PVM2=1 PVMFW=/tmp/pvmfw.img FWSZ=0x100000 ./vmmtest ./stub.bin ./guest-v2.dtb →
VM_START: Invalid argument
[  922.242938] RM rejected message 5600000b. Error: 10
./guest-v4.dtb → 完全相同
```

### 8. 变体 a3（LEND 内存、auth=NONE 对照）

```
env PVM2=1 NOFWCFG=1 →
NOFWCFG: skipping SET_FW_CONFIG
VM_START: Invalid argument
[  931.481013] RM rejected message 5600000b. Error: 10
[  931.481025] Failed to initialize VM: -22
```

### 连续失败计数

变体 a→a3 连续 6 次 VM_START 失败（错误码稳定一致，非资源耗尽形态），按任务规则（>5 连续失败停，怀疑 RM 泄漏）停止，未再跑更多变量。

## 错误码对照表（驱动 rsc_mgr.c 枚举）

| RM 原始值 | 驱动 errno | 含义 | 出现位置 |
|-----------|-----------|------|----------|
| 0x10 | -22 EINVAL | IRQ_INUSE | 老基线：SHARE+auth=NONE 的 VM_INIT |
| 0xA | -22 EINVAL | MEM_INVALID | 本轮：LEND 路径的 VM_INIT（msg 0x0b） |
| 0x3 | -1 EPERM | DENIED | SHARE+SET_FW_CONFIG 的 VM_CONFIGURE（msg 0x09） |
| 0x14 (20) | -74 | （dealloc vmid 阶段） | 变体 d 清理路径 |

## 下一步该改什么

1. **LEND 路径已把问题推到 VM_INIT 的 MEM_INVALID**，而 configure/set_firmware_mem/set_address_layout 都过了 → 怀疑点集中在 **mem parcel 的 lend/share 状态与 VM_INIT 期望不一致**。主线驱动在 PVM auth 下对 fw 区**仍走 `gunyah_gup_share_parcel`**（vm_mgr.c:708），而我们先用 0x11 LEND 过同一批页 —— 同一物理页先 lend 给 RM 再 share，RM 侧很可能记为 MEM_INVALID。**下一步：pVM 模式下 fw 区不要 LEND**（只 SHARE 注册 fw 区 + LEND guest RAM），或反过来完全按 crosvm fork 的顺序：**全部用 LEND 0x11 注册，且 fw 区不额外 share** —— 这需要给主线驱动打补丁，让 auth=PVM 时 fw parcel 复用已 LEND 的 binding 而不是再 share_parcel。
2. **对照实验只需一行**：`PVM2=1 NOLEND=0` + 改代码让 fw 区用 SHARE、RAM 用 LEND（新 env `FWSHARE=1`），确认 MEM_INVALID 是否消失/变成别的码 —— 这是区分「页状态冲突」与「DTB/pvmfw 内容问题」的最小实验。
3. pvmfw 是完整 **Android bootimg**（含 header）。若 MEM_INVALID 解决后仍被拒，考虑 RM 期望的是 bootimg 里 **kernel 段**（pvmfw.bin）而非整块 bootimg：把 bootimg 按 header (kernel_size=0xba5, kernel_addr=0x20ba501? 实测 kernel size 0xba5… 需解析 header) 拆出 kernel 载荷再喂。
4. VM_CONFIGURE 对 SHARE+PVM 的 DENIED 说明 **auth=PVM 与内存 lend 语义绑定**：RM 端 pVM 只接受 LEND 过来的内存。所有 pVM 内存区都应走 0x11 LEND。
5. 遗留问题不变：auth=NONE 基线的 IRQ_INUSE 仍在（本 firmware 对普通 VM 的另一重拒绝），pVM 是绕开它的正确方向，本轮已把拒绝点从 VM_INIT(IRQ_INUSE) 推进到 VM_INIT(MEM_INVALID)。

## DTB 矩阵（第二轮）

日期：2026-10-25（设备刚重启，kernel `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`，RM 状态全新）。
环境：`/tmp/vmmtest`（本轮加了 FWSHARE env，fw 区可走 SHARE）、`/tmp/pvmfw.img`（从 `/dev/disk/by-partlabel/pvmfw_a` dd 1 MiB，md5 `73a3d6e6af89dc62f91994fc7278ac2a` = 上轮同源）。
fw_gpa = 0x80800000（vmmtest 内 2 MiB 对齐，紧随 8 MiB guest RAM）。

### DTB 变体

| 变体 | DTB 关键差异 | VM_START | RM 错误码 | 判定 |
|------|-------------|----------|-----------|------|
| v5 | v2 + `firmware-address = <0 0x80800000>` | EINVAL | `0xA` MEM_INVALID (msg 0x5600000b) | 无变化，H1 否定 |
| v6 | v2 + `size-max = <0x1 0x0>` (4 GiB，两 cell) | EINVAL | `0xA` | 无变化，H2 否定 |
| v7 | v5+v6 | EINVAL | `0xA` | 无变化 |
| v8 | v7 + doorbell vdevice（label 0x14=20，SPI 20 level high，peer-default，source-can-clear） | EINVAL | `0xA` | 无变化 |
| v2 复现 | （NOFWCFG=1，隔离 fw parcel） | EINVAL | `0xA` | 上轮 a3 结论在全新 RM 状态下复现 |
| v7+NOFWCFG | v7 且不调 SET_FW_CONFIG | EINVAL | `0xA` | **fw parcel/SET_FW_CONFIG 不是触发条件** |
| v7+FWSHARE | fw 区改 SHARE 0x4701、RAM 仍 LEND | EINVAL | `0xA` | 「同页先 lend 再 share」假设（上轮下一步 #1/#2）否定 |

连续 7 次 VM_START 失败，错误码与消息完全一致（非资源泄漏形态），按规则停手。

### 原始命令与输出（节选）

```
# 每变体：
dmesg -C
env PVM2=1 PVMFW=/tmp/pvmfw.img FWSZ=0x100000 ./vmmtest ./stub.bin ./guest-vN.dtb
# 例（v7）：
guest RAM registered (ioctl 0x4111): gpa 0x80000000 size 0x800000
fw region registered: gpa 0x80800000 size 0x100000
fw config: gpa 0x80800000 size 0x100000 (pVM2 auth)
VM_START: Invalid argument
[  219.419232] RM rejected message 5600000b. Error: 10
[  219.419246] misc gunyah: Failed to initialize VM: -22
# FWSHARE 追加行：fw region ioctl 0x4701
```

### 本轮最重要的新信息（非穷举结论）

**VM_INIT 消息不含 DTB/内存参数。** 查 `build/gunyah-port/drivers/virt/gunyah/rsc_mgr_rpc.c:464`：

```c
int gunyah_rm_vm_init(struct gunyah_rm *rm, u16 vmid)
{
	return gunyah_rm_common_vmid_call(rm, GUNYAH_RM_RPC_VM_INIT, vmid);
}
```

VM_INIT 请求体只有 vmid ⇒ 0xA MEM_INVALID 与 guest DTB 内容**完全无关**（H1–H3 从协议层就不可能成立），也与 SET_FW_CONFIG、fw 区 share/lend 状态无关。RM 是按 **vmid 侧已登记的内存状态**（此前 LEND 进来的 memparcel 集合）在 VM_INIT 时做整体校验拒绝的。

### 下一步建议（按成本排序）

1. **零成本：查 RM 侧 API 版本/特性协商**。该固件的 RM 可能根本不支持 Android pVM 扩展（0x4701 LEND / 0x12 SET_FW_CONFIG 虽返回成功，但 VM_INIT 校验按另一套语义）。跑 `rmtest`/hypprobe 读 RM API 版本（RM_INFO / feature 协商），确认这颗 RM 是否为 Gunyah 主线（非 Qualcomm Android 分支）固件——若是主线固件，pVM 路线在固件层就被封死，0xA 是它的表达方式。
2. **低成本：对照主线驱动的 memparcel lend 参数**。比对 Qualcomm Android 分支（reference/gunyah-android15-6.6）`vm_mgr.c` LEND 请求里的 flags/label/nr_entries 与我们 0x4701 路径的差异（尤其 label=1/2 是否合法、GUNYAH_MEM_ALLOW_RWX flag 翻译）。若有差异，改 vmmtest userspace 参数即可再试（仍零内核改动）。
3. **中成本：抓 VM_INIT 前 RM 眼中的 parcel 清单**。设备端 dmesg 加 debug 打印（现 kernel 为 `-debug` 版，应有动态 debug）列出 0x11 每次登记的 gpa/size/label，对照 RM 拒绝点，确认是否 fw 区(0x80800000)落在 VM_CONFIGURE 声明的 address layout 之外导致整体 MEM_INVALID（把 fw_gpa 挪进 layout 内测试需改 vmmtest 的 fw_gpa 计算，userspace-only）。
