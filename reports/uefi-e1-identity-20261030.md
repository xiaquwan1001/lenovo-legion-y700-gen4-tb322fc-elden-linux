# UEFI E1 内 UFSDxe 二进制身份澄清（2026-10-30，lane：代码边界检查）

> **问题**：E1 所用的 UFSDxe 到底是哪一件？E1 的成败能不能被解释成「dodge 三补丁」的成败？
> **性质**：纯主机、**只读**。未接触设备（无 fastboot/adb/ssh）、未刷机、未构建、未改任何既有文件与领域层 SSOT。
> 本 lane 只新建本文件 + `TASKS/sessions/2026-10-30-UEFI-E1二进制身份.md`。
> **编排**：2 个只读二级（`.pi/agents/verify-worker`，model `custom.ustc-pool/ustc-worker`）在一次 `fabric_exec`
> 里 `Promise.allSettled` 并发派发；下表所有关键数字**由本层亲自重跑复核**（§7），未只汇总自报。
> 接续（不重推）：`reports/uefi-recovery-20261030.md` §2.1/§4/§6、`reports/uefi-visibility-rebuild-20261028.md` §3/§4.1、
> `reports/uefi-consolidated-20261030.md` F11/F12/B3、`reports/uefi-n2-v0b-onboard-20261030.md` §1。

## §0 三问三答（数字先行）

| # | 问题 | 答案 |
|---|---|---|
| **①** | E1 内 UFSDxe 是哪一件？ | **= dodge 那枚**：`/home/xuqianhui/ext-repos/mu-dodge/UFSDxe.patched.efi`，155 648 B，sha256 `e76b555f7c855784…3c85ef`；上游原件 = `Project-Silicium/Device-Binaries/dodge/QcomPkg/Drivers/UFSDxe/UFSDxe.patched.efi`（**OnePlus dodge 平台**，非本机平台）。E1 FD 内实抽件 `E1-UFSDxe-in-FV-SEC2.pe32`（`bc336c04…`，155 652 B）= 4 B `EFI_SECTION_PE32` 段头（`04 60 02 10` → size 0x026004 + type 0x10）+ 该文件，**逐字节相等（本层实测 `G[4:]==E → True`）**。它**既不是**厂商件 `fa561bf1`，**也不是**树内 `PatchedBinaries` 的 `00ae059f`。 |
| **②** | 与仓库 `PatchedBinaries` 的补丁集是否等价？ | **不等价（逐命中点证否）**。`PatchedBinaries`（`00ae059f`）的补丁 = 3 个代码点 32 B（`0x0a998` 8 B、`0x114c4` 16 B、`0x1b080` 8 B）+ 6 B build 路径串；E1 件的补丁 = **只有 2 个代码点 12 B**（`0x0a998` 8 B、`0x1191c` 4 B）+ 16 B PE 头 + 新增 `.extra` 节 4 KiB。**第三点（`0x1b080` = UFS IOMMU/`UFSSmmuConfig` 整函数 stub 成恒成功）在 E1 件里完全不存在**（本层反汇编：`mov w0,#-0x80000000; add x1,x1,#0xa3b; bl 0x7508`＝真函数体；`00ae059f` 同址 = `mov w0,#0; ret`＝stub）。而且两者**基座都不同代**（厂商件 vs dodge 件差 **45 277 B**、build 工作区串完全不同源），谈不上「同一补丁集」。 |
| **③** | E1 上机结果能否解释「dodge 三补丁」？ | **不能 → 未证实**，两条各自独立的理由：<br>**(a) 载荷根本没执行**：E1-v0b（10-30 15:04，img `2ff27bf0…`）`Booting OKAY [10.110 s]` 后 `usb-watch` **30/30 秒全为 `18d1:d00d`**（本层 `awk|uniq -c` 复核），按 `PITFALLS` #387/#418 判据 = **未交棒、从未离开 ABL** ⇒ 该发结果与 UFSDxe 内容**无因果关系**。<br>**(b) 变量对不上**：就算交棒，E1 测的是 dodge 的「sleep→wakeup + gear 前唤醒」两补丁，**不含**「三补丁」里最关键的 IOMMU/SMMU stub。 |

**一句话**：E1 = **dodge（OnePlus）那枚 12 B 两补丁件**，不是仓库 `PatchedBinaries` 的 38 B 三补丁件；而且这一发根本没跑起来。
所以 **E1 既不能证实也不能证伪「dodge 三补丁」**，`reports/uefi-consolidated-20261030.md` §3 B3 的「未证实」结论**成立并被本层加强**（新增：上机未交棒这一独立理由）。

## §1 七件二进制身份表（本层实测 sha/尺寸/PE；构建串本层 `strings -t x` 实测）

| 代号 | 路径 | 尺寸 | sha256(16) | PE：节数 / SizeOfImage | build 工作区串 @0x23cfc |
|---|---|---|---|---|---|
| **A** 厂商件 | `reports/artifacts/uefi-dxe-20261024/vendor-UFSDxe.efi` | 151 552 | `fa561bf11eb18f14` | 3 / 0x25000 | `/home/buildslave/jenkins_build/**elden_w_prc_wifi_mp251201**/…` |
| **B** 树内未打补丁 | `build/…/lenovo-y700g4/Binaries/QcomPkg/Drivers/UFSDxe/UFSDxe.efi` | 151 552 | `dac620aca276e735` | 3 / 0x25000 | `…/jenkins_build/**elden_v_prc_wifi_mp250526**/…` |
| **C** 树内「三补丁」 | `build/…/lenovo-y700g4/PatchedBinaries/UFSDxe.efi` | 151 552 | `00ae059f5b4a95fb` | 3 / 0x25000 | 同 B（`elden_v_mp250526`；A↔C 的 6 B 差异正是这串） |
| **C2** | 同目录 `UFSDxe.efi.orig-mu`（**未跟踪**） | 151 552 | `00ae059f5b4a95fb` | — | 同 C（**名字骗人**：它是 C 的副本，不是未打补丁原版 B；见 §5-3） |
| **D** dodge 原版 | `/home/xuqianhui/ext-repos/mu-dodge/UFSDxe.efi` | 151 552 | `0b32d9244c945d8c` | 3 / 0x25000 | `/work/0011/workspace/Build_S_BP/8120/code/source/msm_amss/**BOOT.MXF.2.5.1**/…` |
| **E** dodge 补丁版（= **E1 输入件**） | `/home/xuqianhui/ext-repos/mu-dodge/UFSDxe.patched.efi`；副本 `reports/artifacts/uefi-e0e1-20261028/UFSDxe.patched.efi` | 155 648 | `e76b555f7c855784` | **4** / **0x26000**，多 `.extra@0x25000`（vsz 0x1000） | 同 D |
| **G** E1 FD 实抽段 | `reports/artifacts/uefi-e0e1-20261028/E1-UFSDxe-in-FV-SEC2.pe32` | 155 652 | `bc336c04a85748fc` | 剥 4 B 段头后 = E（逐字节） | 同 E |

- 七件 **TimeDateStamp 全为 0**、`ImageBase=0`、`EntryPoint=0x1000`、`CheckSum=0` ⇒ **PE 时间戳无鉴别力**，代次只能靠 build 路径串 + 节布局（本层实测）。
- `.text` 的 `VirtualAddress == PointerToRawData == 0x1000` ⇒ **RVA == 文件偏移**（本层 pefile 复核；总账 §2 的约定成立）。

## §2 补丁点逐命中矩阵（核心证据）

| 站点 | A 厂商 `fa561bf1` | C 三补丁 `00ae059f` | D dodge 原版 `0b32d924` | E/G E1 实装 `e76b555f` | 语义 |
|---|---|---|---|---|---|
| `0x0a998` | `bl 0xbfa4` | **`mov x1,#0x1` + `bl 0xc0d0`** ✔改 | `bl 0xbfa4` | **`mov w1,#0x1` + `bl 0xc0d0`** ✔改 | 两侧都改此点，但**指令不同**（C 用 `x1`、E 用 `w1`），且基座不同代 |
| `0x114c4` | `cbz w0,…` | **`mov x0,x19`+`mov w1,#0`+`bl`+`b`** ✔改（丢弃返回码强制继续） | 原始 | **原始** ✘未改 | PHY/UIC 层；**E1 件完全没有** |
| `0x1191c` | 原始 | **原始** ✘未改 | `bl 0x11284` | **`b 0x25000`**（跳进新增 `.extra`）✔改 | dodge 独有：gear check 之前强制拉 link |
| `0x1b080` | `sub sp,sp,#0x40`（真函数体） | **`mov w0,#0` + `ret`＝整函数 stub** ✔改 | 真函数体（不同代序言） | **真函数体（`52b00000 9128ec21 20b1ff97…`）＝未 stub** ✘未改 | **UFS IOMMU/SMMU 域 create/configure/attach（=`UFSSmmuConfig`）被恒成功** ——「三补丁」里与 10-05 崩溃面 `UFS.c+2326` 同层的那一点，**E1 里没有** |
| build 串 `0x23d21/0x23d30/0x23d3b` | `elden_w_mp251201` | `elden_v_mp250526`（6 B，非语义） | `Build_S_BP/8120` | 同 D | 代次指纹，不是补丁 |

**差异字节（本层 python 内存比对）**

| 对 | 差异字节 | 分段（偏移,长度） | 解读 |
|---|---|---|---|
| A ↔ B | 6 | `0x23d21`(1) `0x23d30`(4) `0x23d3b`(1) | 纯 build 路径串 |
| **A ↔ C** | **38** | `0x0a998`(8) `0x114c4`(16) `0x1b080`(8) + 串 6 | **三补丁 = 32 B 代码 + 6 B 串** |
| B ↔ C | 32 | 去掉串后同上 | 与 recovery §2 一致 |
| **D ↔ E** | **28** | **`.text`：`0x0a998`(8)、`0x1191c`(4) = 12 B**；其余 16 B 全在 PE 头区（`0xe5e` 节计数、`0xea9` SizeOfImage、`0xfd8..0xfff` 节表位移） | **dodge 两补丁 = 12 B 代码 + 新增 `.extra` 4 KiB** |
| **A ↔ D** | **45 277**（区间 `0x1165..0x240cb`） | 遍布全镜像 | **不是同一代原版二进制**（重编译级差异） |
| A ↔ E | 45 305 | 首 `0xe5e` 末 `0x240cb` | ≈ 代次差 45 277 + 补丁差 28（偏移有重叠，不可算术相加） |

⇒ **判定：差异性质是「代次差 + 补丁集差」两者都有**，且 **A 与 D 属不同构建工作区**：
A = 联想 `elden_w_prc_wifi_mp251201`、B/C = 联想 `elden_v_prc_wifi_mp250526`（都是本机平台），
D/E = `/work/0011/workspace/Build_S_BP/8120/…BOOT.MXF.2.5.1`（**不是 elden 工作区**，是 dodge/OnePlus 侧的内部构建）。
这为总账 §6.3「dodge 那两枚是另一个 PHY/供电体系」补上了**二进制级**证据。

## §3 镜像链核对（E1 img → payload → FD → FFS → PE32）

| 环节 | 实测 | 判定 |
|---|---|---|
| `sha256sum -c manifest.sha256`（`uefi-e0e1-20261028/`，7 条） | 本层重跑，全 OK | ✅ |
| `sha256sum -c SHA256SUMS`（`uefi-onboard-20261030/`，4 条） | 二级实测 4/4 OK（**须在仓库根执行**，清单内是根相对路径） | ✅ |
| E1 header v0 字段（正确偏移 `kernel_size@8`…`page_size@36`） | `ksize=2 437 723`、`pagesize=4096`；`E1-v0.img` `ka=0x8000`；`E1-v0b.img` **`ka=0x10008000`** | v0b 满足 `PITFALLS` #418 |
| payload 偏移 | `img[0x1000 : 0x1000+ksize] == e1-bootpayload.bin` **True**（二级实测；与 recovery §4.2 一致） | ✅ |
| v0 → v0b | payload **同一份**（`2a40bc9e…`），仅 header 4 个地址字段变化（`ka/ra/sa/ta`） | 重打包只动 header |
| `gunzip(e1-bootpayload)[112:]` | sha `bde4831b…` = `SM8750_EFI-E1.fd`（本层 `sha256sum -c` 复核 FD；解压链由二级实测） | ✅ |
| FD 内 FFS `0D35CD8E-97EA-4F9A-96AF-0F0D89F76567` | 二级：inner FV 偏移 `0x1e5600`、FFS size 155 718、PE32 段头 `04 60 02 10` | 其 PE32 body sha = **`e76b555f`** |
| 归档段 `G` | 本层实测 `G[4:] == E` **True**、`sha(G)=bc336c04` | ✅ **E1 内即 dodge 件** |
| **并发那发的独立验证**（本层自建路径） | 未压缩的 `Build/PakalaPkg/RELEASE_CLANGPDB/FV/FVMAIN.Fv`（mtime 10-30 **16:36:35**，sha `da42aaac…`）在 `0x1e561c` 明文含 UFSDxe PE32 **151 552 B / sha `dac620ac`（= B 未打补丁）**，段头 `04 50 02 10`（size 0x25004/type 0x10） | 16:36 那次构建装的是 **B**，不是 E 也不是 C |

## §4 E1 上机结果（收口一条孤儿事实）

`reports/artifacts/uefi-e1v0b-20261030/`（10-30 15:04–15:08）此前**从未写进任何报告**（`uefi-text-console-archaeology-plan-20261030.md` A21 已登记为孤儿）：

- `boot-attempt.txt`：`img=2ff27bf0d992f988…`（= `uefi-onboard-20261030/E1-v0b.img`，本层 `sha256sum` 复核）；`Sending 'boot.img' (2388 KB) OKAY [0.055s]` / **`Booting OKAY [10.110s]`**。
- `usb-watch.txt`：`wc -l` = **30**；`awk '{print $2}' | uniq -c` = **30 × `18d1:d00d`**（15:05:22→15:05:51，一秒不掉）。
- `post.txt`：`current-slot: b`、`slot-unbootable:b: no`、`fastboot reboot OKAY`、回 Linux（`#2 SMP PREEMPT Fri Oct 30 13:06:36 CST 2026`，根 `/dev/sda17 ext4`）⇒ 零写盘、无残留。

⇒ 按 `PITFALLS` #387/#418 判据（**真交棒 = USB 掉线**）：**E1-v0b 未交棒，载荷从未执行**。
四发对照（`uefi-n2-v0b-onboard-20261030.md` §1 + 本发）：E0 ❌ / N2 ❌ / **E1 ❌** / A2 ✅ ⇒
**「载荷里有 UFSDxe 就会交棒」的假设被 E1 证伪**（A2 与 E1 都含 UFSDxe，一个交棒一个不交）。判别量仍 unidentified（B10 未解）。

## §5 顺带纠正的三条既有口径（**只建议，不改 SSOT**）

1. **术语**：`uefi-recovery-20261030.md` §2 / 总账 F7–F10 的「**dodge 三补丁**」，对象其实是**树内 `PatchedBinaries`（`00ae059f`）**，
   而 `PatchedBinaries` 与 dodge 仓库件（`0b32d924`/`e76b555f`）**基座不同代、补丁集不同**（§2）。
   建议改称「**Mu 树内 `PatchedBinaries` 三补丁**」，与「dodge 两补丁」分开记录；否则「dodge 三补丁」这个短语会继续误导归因。
2. **`uefi-visibility-rebuild-20261028.md` §4.1 的分支目标低 `0x1000`**（该节把 objdump 的 `<.text+…>` 标注当成了目标地址）。真值（本层反汇编）：
   `0x0a998: bl 0xbfa4 → mov w1,#1; bl 0xc0d0`（非 `0xafa4`/`0xb0d0`）；`0x1191c: bl 0x11284 → b 0x25000`（非 `bl 0x10284`/`b 0x24000`）；
   **`.extra` 节 VA = `0x25000`**（非 `0x24000`）。**站点地址与「.text 仅差 12 B」两处结论不受影响**（本层复算 = 12 B ✔）。
3. **`PatchedBinaries/UFSDxe.efi.orig-mu` 名字骗人**：实测 sha = `00ae059f` = **C（已打补丁件）的副本**，不是未打补丁原版 B（`dac620ac`）；
   且它在 git 里是 **untracked**（`?? …UFSDxe.efi.orig-mu`）。用它当"还原基准"会把补丁件当原版还原。

## §6 写者边界 / 并发观察（边界检查项，**未干预**）

- `build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries/UFSDxe.efi`
  **被当作"交换槽"反复覆盖/还原**：10-28 换入 `e76b555f` 建 E1 后还原；10-30 **16:36** 构建时槽内是 `dac620ac`（§3 明文取证），
  **16:39:37** 又被写回（当前 mtime），内容 = `git cat-file HEAD:…` = `00ae059f`（本层实测），`git status` 对该文件干净。
  ⇒ **该路径的文件身份不稳定**：任何以「PatchedBinaries 当前内容」为锚的结论，必须同时记 **sha + mtime**（本次就是这么识破的）。
- 边界建议（不改主线/不改上游工作树）：换二进制做实验时**别覆盖上游仓库工作树里的 blob 路径**，
  改为「独立 overlay 目录 + `--conftarget`/副本 INF」，避免并发 lane 互相踩、也避免 `git status` 出现 `??` 残留（本例 `UFSDxe.efi.orig-mu`）。
- `APRIORI.inc:76` / `DXE.inc:58` / `DXE.dsc.inc:83` 三处都指 `PatchedBinaries/UFSDxe.inf`（**不是** `Binaries/` 那份 INF）
  ⇒ E1/E0/16:36 三次的 UFSDxe 全部来自这一个槽位，所以「槽位当前内容」= 「该次构建的输入」，**只在构建瞬间成立**。

## §7 复现命令（本层亲自跑过的 3+1 组）

```bash
cd /home/xuqianhui/y700-elden && git rev-parse --show-toplevel        # → /home/xuqianhui/y700-elden

# 1) 身份/manifest
sha256sum reports/artifacts/uefi-dxe-20261024/vendor-UFSDxe.efi \
  build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/{Binaries/QcomPkg/Drivers/UFSDxe,PatchedBinaries}/UFSDxe.efi \
  build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries/UFSDxe.efi.orig-mu \
  /home/xuqianhui/ext-repos/mu-dodge/UFSDxe{,.patched}.efi \
  reports/artifacts/uefi-e0e1-20261028/E1-UFSDxe-in-FV-SEC2.pe32 \
  reports/artifacts/uefi-onboard-20261030/E1-v0b.img
(cd reports/artifacts/uefi-e0e1-20261028 && sha256sum -c manifest.sha256)      # 7/7 OK

# 2) PE 字段（TimeDateStamp / 节表 / .extra）
python3 -c 'import pefile;pe=pefile.PE("/home/xuqianhui/ext-repos/mu-dodge/UFSDxe.patched.efi",fast_load=True); \
fh=pe.NT_HEADERS.FILE_HEADER;o=pe.NT_HEADERS.OPTIONAL_HEADER;print(hex(fh.TimeDateStamp),fh.NumberOfSections,hex(o.SizeOfImage)); \
print([ (s.Name.split(b"\x00")[0].decode(),hex(s.VirtualAddress),hex(s.PointerToRawData)) for s in pe.sections])'   # 4 节，.extra@0x25000，SizeOfImage 0x26000

# 3) 补丁点（RVA == 文件偏移；ImageBase=0）
for f in reports/artifacts/uefi-dxe-20261024/vendor-UFSDxe.efi \
         build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries/UFSDxe.efi \
         /home/xuqianhui/ext-repos/mu-dodge/UFSDxe.patched.efi; do
  llvm-objdump -d --triple=aarch64 --start-address=0x1b080 --stop-address=0x1b090 "$f" | sed -n '/1b080/p'
done     # A: sub sp,sp,#0x40 / C: mov w0,#0 + ret / E: mov w0,#-0x80000000 …（未 stub）
llvm-objdump -d --triple=aarch64 --start-address=0x1191c --stop-address=0x11924 /home/xuqianhui/ext-repos/mu-dodge/UFSDxe.efi
llvm-objdump -d --triple=aarch64 --start-address=0x1191c --stop-address=0x11924 /home/xuqianhui/ext-repos/mu-dodge/UFSDxe.patched.efi   # bl 0x11284 → b 0x25000

# 4) 差异字节 + 段内明文取证（并发那发）+ 上机判据
python3 - <<'PY'   # A↔C runs、D↔E runs、G[4:]==E
A=open("reports/artifacts/uefi-dxe-20261024/vendor-UFSDxe.efi","rb").read(); C=open("build/uefi-woa-prep/repos/7-mu-lenovo/Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries/UFSDxe.efi","rb").read()
D=open("/home/xuqianhui/ext-repos/mu-dodge/UFSDxe.efi","rb").read(); E=open("/home/xuqianhui/ext-repos/mu-dodge/UFSDxe.patched.efi","rb").read()
G=open("reports/artifacts/uefi-e0e1-20261028/E1-UFSDxe-in-FV-SEC2.pe32","rb").read()
f=lambda x,y:[i for i in range(min(len(x),len(y))) if x[i]!=y[i]]
print(len(f(A,C)), len(f(D,E)), len(f(A,D)), G[4:]==E)
PY
python3 -c 'import re,hashlib;d=open("build/uefi-woa-prep/repos/7-mu-lenovo/Build/PakalaPkg/RELEASE_CLANGPDB/FV/FVMAIN.Fv","rb").read(); \
print([ (hex(0x1e5000+m.start()), hashlib.sha256(d[0x1e5000+m.start():0x1e5000+m.start()+151552]).hexdigest()[:16]) for m in re.finditer(b"MZ", d[0x1e5000:0x210000]) if hashlib.sha256(d[0x1e5000+m.start():0x1e5000+m.start()+151552]).hexdigest()[:16]=="dac620aca276e735"])'
wc -l reports/artifacts/uefi-e1v0b-20261030/usb-watch.txt; awk "{print \$2}" reports/artifacts/uefi-e1v0b-20261030/usb-watch.txt | sort | uniq -c
```

## §8 未证实 / 缺口（明确）

1. **`00ae059f` 自身的最初来源未证实**：只能证到「= git `HEAD:…/PatchedBinaries/UFSDxe.efi`（随 10-05 上游 clone 落盘，`git log` 唯一 commit `6b6ac42a`）」，
   **不是**本机任何一次构建的产物；它的生成记录（谁在哪个工作区把 32 B 补丁打上去）缺证据。
2. **10-30 16:36 构建当时的槽内瞬时内容**无快照；由 `FVMAIN.Fv` 明文 = `dac620ac` **强推断**（本层实测），非直接文件证据。
3. **E1 的 LZMA/FV 抽取**：本层未能独立重跑 LZMA 抽取（自写 raw-LZMA 解码未命中该镜像的段格式）；
   改由「归档段 `G` 逐字节 == E」+「同一槽位在未压缩 `FVMAIN.Fv` 里的明文取证」两条侧路闭合。二级那条 LZMA 路径的本层未复现 ⇒ 记**待确认**，不影响结论。
4. **B10（同 header/base 下交棒与否不稳定）仍未解**：E1 落在 ❌ 侧，判别量未知（本 lane 无设备权限，不推进）。
5. **E1 从未真正测试过任何 UFSDxe 补丁**：要判「dodge 两补丁」或「三补丁」的效力，**先决条件是先拿到一发真交棒**（#418 base 已满足仍不交 ⇒ 卡在 B10）。

## §9 回执四段

- **0E/0W/0C（本 lane 门禁）**：不适用 checkpatch/DTC（无代码改动）；本层只读、**0 改动**，`git status --porcelain` 除本 lane 新建两文件外为空。
- **FAIL 数**：**0**（manifest 7/7、SHA256SUMS 4/4、`G[4:]==E` True、`img[0x1000:0x1000+ksize]==payload` True（`ksize=2 437 723`，E1 镜像尾部余 3 493 B 不属 payload；E0 余 439 B）、补丁点反汇编 3/3 与判定一致）。
- **关键行号/数字**：`0x1b080` A=`sub sp,sp,#0x40` / C=`mov w0,#0;ret` / E=真函数体；A↔C **38 B**（32 代码 + 6 串）、D↔E **28 B**（**12 B 代码** + 16 B PE 头）、A↔D **45 277 B**；E1 件 = `e76b555f`，E1 FD 实抽 = `bc336c04`；E1-v0b usb **30/30 `18d1:d00d`** = 未交棒。
- **产物**：本文件 + `TASKS/sessions/2026-10-30-UEFI-E1二进制身份.md`。
