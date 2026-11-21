# #708 判断「某个 EFI 程序是否被执行」只能用**它自己 cfg 里的 token**；`elden_bootpath=uefi` 与 logfs 信标都不够

- 日期：2026-11-21 晚（零写盘一发 `fastboot boot` p69，设备 U2）
- 状态：已复核（token 判据 + 载荷自检 + logfs 前后 diff 三重）

## 三个 token / 通道的语义边界（本轮踩到的核心）

| 通道 | 谁写 | 证明到哪一步 | **不能**证明 |
|---|---|---|---|
| `/proc/cmdline` 含 `elden_bootpath=uefi` | R43 补丁，Mu 的 `UpdateCmdLineParams()` 在跳转前追加 | Mu 的 **LinuxLoader 跑到了跳转** | BDS 跑过、ESP 被枚举、`BOOTAA64.EFI` 被执行 |
| `/proc/cmdline` 含 `elden_bootloader=esp` | R55+ 路线 B（ESP 侧 `boot.img` 被读起） | ESP 里的 `boot.img` 被读到了 | ESP 里的 `.efi` 被 BDS 执行 |
| ESP `grub.cfg` 里的自定义 token（如 `elden_esp_grub=…`） | **那份 cfg 本身** | **BOOTAA64.EFI 真被执行**（唯一硬判据） | — |
| logfs `R68LOG s<n>:…` | R66/R68 补丁的 BDS 阶段信标（走 UFS 写 logfs） | 那些阶段走到**且** UFS 写得出 | 只到跳转、没进 BDS 的场合不会写；**UFS 不通也写不出** |

⇒ 2026-11-21 实测：`eden_bootpath=uefi` 有、ESP token **无**、`R68LOG` 计数 0
⇒ 本次是 Mu 的 LinuxLoader 直接把内核交出去，**没走 BDS→ESP→BOOTAA64.EFI**。
所以「没有完整 GRUB 菜单」不是显示/菜单配置问题，是那条路没走。

## 两条容易把人带偏的读数

- **「logfs 里没有信标 ⇒ 固件没跑」是错的**，除非先证明**喂进去的件里有信标代码**。
  本轮第一次就是被这个坑了一下：直接 `strings` boot.img 看不到（FD 在 gz 段里、内层 FV 还套 LZMA）⇒
  正确做法 = 解 gz 拿 FD（`zlib.decompressobj(16+MAX_WBITS)`）→ `scripts/uefi-fv-strings.py <fd> R68LOG`。
  本轮实际件 `45553a4a…` 里有 `R68LOG`×3，却仍然一条没写 ⇒ 这才是「没跑到/UFS 写不出」的有效证据。
- **ESP 里原来只有 `/grub/grub.cfg`**，而 GRUB（本机 = `2.14-2ubuntu1`，`strings` 里模板是 `%s/grub.cfg`）
  默认 prefix 多在 `($root)/EFI/BOOT` ⇒ 原来那份菜单**可能从来读不到**。做法：`/grub/grub.cfg` 与
  `/EFI/BOOT/grub.cfg` 各放一份同内容（本轮 md5 均 `0750f9e5…`），等于同时测「是否执行」与「prefix 是否对」。

## 判据（可复跑）

```
# 设备侧（ESP = vendor_boot_b，FAT32）
mount /dev/disk/by-partlabel/vendor_boot_b /mnt/esp
grep -c elden_esp_grub /mnt/esp/grub/grub.cfg /mnt/esp/EFI/BOOT/grub.cfg     # 各 ≥1
# 起核后
ssh root@192.168.7.1 'grep -o elden_esp_grub=[0-9T]* /proc/cmdline'          # 有 ⇒ GRUB 被执行
# 载荷自检（先证明件里有信标，再看 logfs）
```
