---
name: "kernel-downstream-replay"
description: "把下游内核树（7.2-elden 一类）重放到新上游基线（如 7.3-rc7）并重建可用镜像：下游 payload 基点对象丢失后的替代重建、用「在机 DTB 指纹」反查正确的下游 tag、16 文件冲突裁决、dtbs_check、自研 mkbootimg 打包与自校验。触发词：重放 M1 线、payload 基点丢了、cherry-pick 下游树、DTB 尺寸不对、dtbs_check、boot.img 打包、mkbootimg 丢失、build/m1-upstream 丢了。"
version: 1
created: "2026-10-17"
updated: "2026-10-17"
---
## When to Use
换机/丢分支后要重建一条「下游内核 + 上游基线」的工作树，或要判断某个历史镜像到底来自哪个下游 tag 时使用。适用于 7.2→7.3 这类大版本重放；不适用于纯主线开发（没有 payload 时直接用上游）。

## Procedure
1. 先判「下游态取哪个 tag」：把在机镜像的 DTB 抽出来（boot.img 里搜 FDT magic，或 unpack 后取 dtb），dtc 反编译，取指纹（pstore console-size、有无 audio-codec/wcd-capture-dai-link、splash_region 命名、关键节点 power-domains 数量）；再用 git show <tag>:path | grep 指纹 逐个 tag 对照，选命中最多的。
2. 建 pristine 基点：下载对应上游源码包（国内用 mirrors.ustc.edu.cn/kernel.org），解包后 git init + 全量 add + commit + 打 tag（如 v72-base），得到可三方合并的基点。
3. 把选定的下游 tree 解出来（git worktree add <dir> <tag> --detach），与 pristine 做 diff -rq -x .git 拿改动清单；把这些文件覆盖进 pristine 树（新文件建目录，构建垃圾 .o/.cmd/scripts/dtc/include-prefixes 排除），commit 成 payload；实验性改动在此手改回上游 parity。
4. 在新上游源码仓 worktree 上 git cherry-pick payload（需要先把 payload commit fetch 进来；浅克隆用 --update-shallow）；冲突逐个按上游优先/双方保留/取 elden 三分类裁决，7.x API 改名（如 bridge 非原子 enable/disable → atomic_enable/atomic_disable 两参）要顺手改。
5. 按 policy 丢弃 out-of-tree 片（vendor fscrypt/dm-default-key 等）后再 git cherry-pick --continue；然后 git am 上游件补丁（如 DSI/PLL 修复）。
6. 验证：make defconfig 或拷日常 config + merge_config 片段 → olddefconfig → 断言 CONFIG_ARCH_QCOM=y；跑 make dtbs / dtbs_check（PATH 前缀 dt-schema venv）；make Image.gz modules，比较 .ko 数量与在机模块树是否一致。
7. 把重放结果与在机 DTB 反编译逐行 diff，直到差异只剩有意的少数项；把补丁固化到 patches/replay-<date>/ 并在干净 worktree 里 git am 复验。
8. 打包：用 mkbootimg 生成 boot.img（v2 头，ramdisk 直接取自已知可用镜像以免引入变量），再 --selftest 逐字节校验结构，最后 build-manifest 记录 UTS/载荷 sha/config sha/cmdline。

## Pitfalls
- 下游「最终态」不要取 upstream fork 的 tip：它会缺我们自己分支上的运行期提交（本例差 12 个，DTB 少 12.5 KB）
- 不要在重放里带上未收口的实验性 DT（Q24 的 H2/FIX-1 电源域），否则日常镜像悄悄变实验镜像
- mkbootimg 的 sha1 id 字段：AOSP 序 = sha1(section + 十进制长度)，但被事后重打过的镜像不服从任何标准序 ⇒ 自校验要屏蔽 576..608；往 32 字节切片赋 20 字节 digest 会静默缩短 header 12 字节
- 浅克隆仓 fetch 会拒收新 root，需 --update-shallow；否则身份账 src_missing 永远 FAIL
- 打包前闸门脚本若硬编码 $ROOT/linux，重放树过不了 gate，要给 KDIR= 支持
- 确认 .config 里 CONFIG_ARCH_QCOM/DRM_MSM/DRM_MSM_DSI 仍在（olddefconfig 会静默删掉 → 死内核）
- 板 DTB 的字节数相同 ≠ 内容相同；必须 dtc 反编译后逐行 diff（phandle 重编号属噪声）

## Verification
1. make ... dtbs 返回 0 且无 warn；dtbs_check 对该板 dtb 返回 0 且 0 诊断
2. 重放板 DTB 与在机 boot_b 的 DTB 字节数相同且 dtc 反编译 diff 只剩已知有意差异
3. Image.gz 与模块编译 rc=0、0 error/warning；.ko 数量与在机模块树一致
4. out/boot-elden-vkNNN.img 的 --selftest 通过；manifest 里 kernel_release_matches_image=yes
5. scripts/check-doctor.sh 汇总 FAIL=0