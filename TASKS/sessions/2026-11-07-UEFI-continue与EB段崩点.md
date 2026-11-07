# 2026-11-07（四）— UEFI：漏发的 `fastboot continue` + 崩点搬回 EB 段

- **日期**：2026-11-07（同日第四次会话，接 `2026-11-07-UEFI-p38-真NoBs.md`）
- **pi 会话 id**：`$PI_SESSION_ID`（`.pi/sessions/*.jsonl`，关键词「p41 / continue / fb-loop」）
- **主题**：用户「请继续任务」⇒ 把 p38 那一发跑通并继续往下推进；实际发了 6 发零写盘
- **结论**：
  1. **前四发（p38/p39/p36对照/p40）信息量≈0，原因是我漏了 `fastboot continue`**：
     本树 `BootIntoFastboot` **写死 TRUE**（`20261104R13` 眉注已写），UEFI 起来后一直在 fastboot 等命令；
     `CmdContinue` → `LoadImageAndAuth` → `BootLinux` 才是真正的引导入口。
  2. **p41 补发 `continue` 后第一次真进 `BootLinux`**，logfs `tag=preeb` 记录完整：
     `[K] BL-in vm=1` / `BL-vm=1 ok` / `dtb=…` / `gbs=D4C0B010 ap=D4BF8200 eb=D4BF3B80 fp=D4BF85BC` / `preeb-go`；
     随后屏上 `[K] FLT pc=00000000 esr=86000007 far=0`（`blr` 到 0）。
  3. **两条错判更正**：① 「崩在 preeb 转储」← `tag=preeb` 记录存在 + p43 的 `dump-tag=entry search=Success`
     证明转储**成功**（`R38` 属预防性修复）；寄存器里 `"Part"`/`"ufs "` 是 `GetBlkIOHandles` 的**残留值**，
     不是崩点代码。② 「UEFI 起来就在引导内核」错（见 1）。⇒ 崩点回到 **`ExitBootServices()` 段**，
     与 p37 结论一致（`posteb` 记录仍不出现）。
  4. **构建侧两坑**：`openssl/crypto/evp/legacy_sha.c` 被**静默改坏**（`EVP_{ha512`）而 `git status` 干净
     ⇒ `PITFALLS #544`；子模块里的补丁若含 CRLF，`git diff` 会归一化导致 `git apply` 对不上
     （「异常 dump 不清屏」补丁因此**未进配方**，下一轮给 `apply_patch` 加 `--ignore-whitespace`）。
- **证据指针**：
  - `reports/uefi-p39-p43-continue-20261107.md`（六发账 + 两条更正 + p45 方案）
  - 配方 `patches/uefi/p39..p41,p43-recipe.txt`；补丁 `patches/uefi/20261107R3{4,5,6,8}-*`
  - 镜像：`out/r21-sbstop-p3{9}/p4{0,1,3}/`（`477ff507`/`010c4ab5`/`0359a7c1`/`62f2b065`）
  - 构建归档：`reports/artifacts/uefi-20261107R3{4,5,6,8}-p4*/`（含 `obj/LinuxLoader.{efi,map}`）
  - `PITFALLS #544`、`TASKS/README.md` §5 新块、`versions/patches-uefi-status.tsv` 4 行
- **下一发（p45，未构建）**：EB 段逐步屏显（`eb-go`/`eb-ret`/`bb4`/`posteb-go`）+ 异常 dump 不清屏
  （补丁待按子模块基线重做）；设备若已回 Linux，`boot_b` 仍为 `vk185-adsp`、槽位 `retry=7 succ=1`。
- **设备当前状态**：用户手滑关机过一次；收尾时设备在 Linux（`vk184`/7.3.1 重基件），`boot_b` 未动。
