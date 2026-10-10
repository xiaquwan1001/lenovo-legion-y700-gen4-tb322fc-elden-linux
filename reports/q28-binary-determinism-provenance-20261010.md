# Q28「按内核二进制确定性」逆转说法 — 溯源审计（2026-10-10）

> 起因：用户令「调查上一次 clean 分界线以后的逆转说法——nocard 和 good 的区别不是冷/温，而是内核二进制，需要溯源」。
> 本文只做**溯源与证据复核**，不碰设备、不改内核。结论：该说法**只能降级**，不能作为定案。

## 0. 一句话

「按内核二进制确定性」的原始台账 21 发里**只有 7 发有仓库内原始日志**；其"内核二进制差 5,040,884 B"
经复核**主要是版本串长度导致的 4 字节 `.rodata` 平移假象**，功能代码实质相同；且**同一 `vk64.img` 在冷 POR 路径 3/3 = STORM**，
故「不是冷/暖」不成立。降级为：**在 `reboot2` 暖路径上 vk64 亮、vk89/vk64c 不亮；真因未定。**

## 1. 说法出处（chain of custody）

| 环节 | 产物 | 时间 |
|---|---|---|
| 触发 | 用户质疑「冷/暖无法定性，怀疑该说法本身」 | 10-10 夜 |
| 过程稿 | `reports/q28-binary-determinism-20261010.md` | 提交 22:32 |
| git | `801a4e7`（记录 A/B）；分界线本身 = `d1c096b`/`56f8446`/`8867012`（21:25/21:29/21:50） | — |
| 经验条目 | `PITFALLS #171` | 同上 |
| SSOT 扩散 | `reports/q28-DOSSIER.md §k`、`INDEX.md §3 ①`、`TASKS.md §5 Q28` | 提交 `8a1455e` |

## 2. 原始证据盘点（决定可信度的关键）

报告声称：固定路径 `Linux → reboot2 bootloader → fastboot boot`，连测 **21 发**，判据 = SSH 读 `card0`。

仓库内**实际存在的原始日志**：

| 日志目录 | 镜像 | 次数 | 结果 |
|---|---|---|---|
| `logs/q28-vk89-loop-20261010-220217/` | vk89 | 3 | NOCARD |
| `logs/q28-path-iso-vk64-220502/` | vk64 | 2 | GOOD |
| `logs/q28-vk89plain-220722/` | vk89-plain | 2 | NOCARD |

⇒ **有原始证据 = 7 发（GOOD×2 / NOCARD×5）**。报告台账里的另外 **14 发**（vk64 GOOD×5、vk89 NOCARD×2、
vk64c/vk64c-oldrd/vk64c-clean NOCARD×7）**无任何 per-run 记录**；`vk64c*` `.img` 已在 `56f8446` 删除，
无 `trials/` 记录，无驱动脚本。它们是"口头观测"。

## 3. 变量复核（4 项"钉死"逐条验真）

| 声称 | 复核方法 | 结果 |
|---|---|---|
| 镜像身份 | `sha256sum out/boot-elden-vk64.img` | ✅ `15964160bed0…`，与 `reports/trials/20261010T130452Z-coldfb-vk64.json` 及 `vk64.manifest` 三者一致 |
| 内核载荷 | `zcat out/Image-vk64.gz \| sha256sum` | ✅ `8efb2731…`，与 manifest `kernel_image_sha256` 一致 |
| config 相同 | Oct-8 内核 `linux/scripts/extract-ikconfig` vs 当前 `.config` | ✅ **diff = 0 行**，两者皆 `a383cdb9…` |
| 源码提交 | `linux` HEAD / manifest | ✅ 皆 `d02658e63`、clean、无 `-dirty` |
| 工具链 | 两 banner | ✅ 皆 `gcc 15.2.0-16ubuntu1 / ld 2.46` |
| vk64c 载荷 | 当前 `linux/arch/arm64/boot/Image` | ✅ `ccc0a284…`（#92, 10-10 22:20:37），与报告 `ccc0a284` 一致 |

## 4. ★核心复核：那 5,040,884 B 差异是什么

用 `zcat Image-vk64.gz`（a）与当前 `Image`（b）逐字节比对：

- 两 Image **同大小** 62,540,288 B；总差 **5,040,884 B**。
- 差异**高度集中在 35.2–41.1 MiB 区间**（6.01 MB）。该区间内：
  - `b[i]==a[i]`：**16.18%**
  - `b[i]==a[i-4]`：**94.72%**  ← 整段 `.rodata` 被平移 **4 字节**
  - 区间之后：`b[i]==a[i]` 回到 **99.98%**（重新对齐）
- **`.text`（<26 MiB）只有 26 个 word 不同**，全部是 ADD/LDR 的立即数地址偏移（Δ+1/+4/+12 B），
  XOR 掩码只落在 imm12 位；**没有一条指令的操作码/语义改变**。
- 平移源头可定位：区间首个差异就是 UTS 串 `-gd02658e63cf6` → `c-gd02658e63cf6`
  （`LOCALVERSION` `-vk64` → `-vk64c` 多 1 字符，按对齐放大成 +4 字节）。

⇒ 结论：**这是"版本串长度不同 → `.rodata` 布局平移 → 引用它的 26 条指令立即数微调"**，
不是"5 MB 的功能代码/数据分歧"。任何两次 LOCALVERSION/构建号不同的构建都会产生同型结果。
以字节数（8%）衡量"二进制差多少"会严重高估。

## 5. 反证与混淆项

1. **同一镜像跨路径翻转**：`vk64.img`（sha `15964160bed0`，与 A/B 逐字节同）
   - 冷 POR 盘启 2/2 = STORM（`trials/*-realpor-run{1,2}`，20:52/20:55）
   - POR→fastboot→`fastboot boot` 1/1 = STORM（`trials/*-coldfb-vk64`，21:04）
   - `reboot2` 暖路径 2/2 = GOOD（`logs/q28-path-iso-vk64-220502`，22:05）
   ⇒ 同一二进制**不是恒 GOOD**，复位路径仍是变量；报告只排除了"RAM 起 vs 回退 boot_b"（token 测试），
   未排除复位深度。
2. **固定路径正是被否定的机制**：`reboot2` 暖复位 = `#166` 判定的「NOCARD 粘态」来源；报告自己也
   在 §h 把 NOCARD 称作暖复位伪影。用它做"二进制"自变量有系统性风险。
3. **vk89 ≠ vk64 的干净对照**：vk89 config（`2a940612` 模块化）与 vk64 config（`a383cdb9`）差 **58 行**
   （TOUCHSCREEN/SND_SOC_WCD*/QDSP6 等），是**功能/配置差**，不能作为"布局"证据；唯一干净对是
   vk64 vs vk64c（同 config、同源，仅 LOCALVERSION+构建号不同）。
4. **伪 GOOD 干扰**：`logs/q28-cycle-20261010-1307xx/1312xx/190343` 的 `VERDICT=GOOD` 早于 card0 硬门、
   `UTS=` 为空，是已知 NOCARD 误判 GOOD（`PITFALLS #167`），不得计入任何台账。

## 6. 审计判定（建议口径）

> **Q28 在 `reboot2` 暖路径上呈现：`out/boot-elden-vk64.img` 亮（GOOD×2 有日志），
> vk89/vk89-plain/vk64c 系不亮（NOCARD×5 有日志）。真因未定**：候选含
> (a) 4 字节 `.rodata` 布局平移（功能代码实质相同，机制存疑）、(b) `reboot2` 暖复位粘态、
> (c) vk89 配置差。**原「按内核二进制确定性」不足以定案**；原台账 21 发仅 7 发有原始证据。

## 7. 修复与决定性实验（修复溯源）

1. **口径回填**：`PITFALLS #171` / `DOSSIER §k` / `INDEX §3 ①` / `TASKS §5 Q28` 加降级批注（本提交）。
2. **决定性 A/B（修溯源）**：
   - 先验"构建可复现"：同 config、同 `KBUILD_BUILD_TIMESTAMP`、同 `LOCALVERSION` 连编两次 → 期望 bit 相同。
   - 再造**只差 LOCALVERSION 字符串长度**的一对镜像（如 `-vkQ` vs `-vkQQ`），在**真 POR** 路径各 A/B ≥3 发。
     若仍翻转 ⇒ 布局敏感成立；若同结果 ⇒ 归因复位态。
3. **台账纪律**：此后每发必须落 `reports/trials/`（`scripts/trial.sh`），禁止把终端口头观测写成台账。

## 8. 复核命令（可复现）

```sh
cd /home/xuqianhui1001/y700-elden
sha256sum out/boot-elden-vk64.img                      # 15964160bed0…
zcat out/Image-vk64.gz | sha256sum                     # 8efb2731…
sha256sum linux/arch/arm64/boot/Image                  # ccc0a284…
./linux/scripts/extract-ikconfig out/Image-vk64.gz | diff - linux/.config   # 无输出
python3 - <<'EOF'
import subprocess
a=subprocess.run(['zcat','out/Image-vk64.gz'],capture_output=True).stdout
b=open('linux/arch/arm64/boot/Image','rb').read()
lo,hi=0x2336576,0x28f2764
n=hi-lo
print("b[i]==a[i]  ", sum(1 for i in range(lo,hi) if a[i]==b[i])/n)
print("b[i]==a[i-4]", sum(1 for i in range(lo,hi) if a[i-4]==b[i])/n)
EOF
```
