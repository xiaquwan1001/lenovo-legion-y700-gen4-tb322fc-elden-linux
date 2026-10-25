# 87 · `build-manifest.sh` 把「树里的内核」记成「打进镜像的内核」（#398）

**日期**：2026-10-25 · **pi 会话 id**：宿主会话 · **主题**：只换 ramdisk 的 A/B 打包时，manifest 的 kernel 身份字段会指向错误的文件
**证据**：`out/boot-elden-vk162-fstype.manifest`（修前/修后）、`scripts/build-manifest.sh:75-79`（修前）、`reports/g0-fstype-zero-write-20261025.md`

## 症状（差点误导一次 A/B）

要验证 `/init` 的 fstype 自动探测，正确做法 = **内核逐字沿用 vk152、只换 ramdisk**（单变量）。
于是 `KERNEL_IMG=<从 vk152.img 解出的 kernel>` 打包，镜像里的内核 sha256 = `b6a074ff…`（= vk152，✅ 正确），
但 manifest 写出：

```
kernel=/home/…/build/vk151/arch/arm64/boot/Image.gz
kernel_sha256=ddaa5c38…            ← 树里当前那份（vk153–161 实验重编过）
kernel_image_sha256=03dceb94…      ← 树里的 build/vk151/…/Image
kernel_payload_sha256=c0b39ccb…    ← 这个才是真的（从镜像里算的）
```

⇒ 如果只看 `kernel_sha256`，会误判「内核不是我想要的那份」，进而怀疑「换了内核导致结果不可比」，
或者相反——把「其实换了内核」的实验记成「同内核 A/B」。**`CONFIG_MODVERSIONS` 未开的手工模块树
（本机）对内核身份最敏感，一旦记错就是 `PITFALLS #367` 的翻版。**

## 根因

`build-manifest.sh` 的 kernel 字段写死 `$KDIR/arch/arm64/boot/Image{,.gz}`，
只有 `kernel_packed_*` 尊重 `MKBOOTIMG_ARGS` 里的 `--kernel`。
即「树默认产物」与「实际打包的输入」被混为一谈。

## 修法（已落地）

`kernel` / `kernel_sha256` 改为 `PK_KERNEL`（从 `MKBOOTIMG_ARGS` 解析出的真·打包输入）优先，
`kernel_image_sha256` 直接复用已从镜像算出的 `kernel_payload_sha256`，
并新增 `kernel_identity_source=packed|tree` 明确来源。
判据：重打一次 vk162-fstype 后 `kernel_sha256=b6a074ff…`（=vk152）+ `kernel_identity_source=packed`，且镜像 sha 与上一发逐字相同（`a0ef3381…`，可复现成立）。

## 教训

> 「记录构建输入」的脚本，所有输入都必须来自**实际的打包参数**，不能来自工作树的默认路径。
> 只要有一个字段来自默认路径，A/B 实验的身份就有一个静默的错源。
