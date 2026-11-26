# y700-elden — 内核/引导类失败与洞察：UEFI / EDK2-Mu / BDS / ESP / LinuxLoader（间接引导链）

> 2026-11-26 从 `failures-kernel.md`（199 KB / 346 条）按主题机械拆分：**每条逐字搬移，未改一字**。
> 检索口径不变：`mem -t project <关键词>`（= `~/.pi/agent/projects-memory/<repo>/` 软链到本目录，`find -name '*.md'`），拆分不需改工具。
> 入口与本表 = `failures-kernel.md`（索引件）。

---

安卓端运行 Linux 时，/dev/ttyACM0 是设备侧 USB gadget（ttyGS0）提供的，只在 Linux 运行时存在；UEFI/早期引导阶段没有串口可取证，只能靠屏幕现象判断（如 EDK2 DxeCore 的 Synchronous Exception 刷屏）。
---
LZMA 解压出的 FFS type 0xb section 报告 "suspicious header" 属于正常现象（EDK2 卷常见），不要当构建错误排查。
---
Mu/EDK2 的 stuart 依赖来自 Azure DevOps 内网 feed（pkgs.dev.azure.com/projectmu/*），不是 nuget.org。mono 的 nuget.exe 直接解析该 feed 会 TLS/证书失败；可靠做法：现查代理端口（`curl -s 127.0.0.1:9090/configs | jq -r '.mixed-port'`，旧记录里的 7897 已退役）后 `curl -q --noproxy '' -x http://127.0.0.1:$MP` 直接抓 nupkg，再用 nuget 本地目录源（Feeds used: <本地目录>）喂给 stuart。 — Failed: 在本机配置 mu_wide_platforms 本地编译链时，mono+TLS 无法访问 Azure feed，且直连 flatcontainer 的 URL 返回 404（需从 service index 解析出真实 flat2 GUID URL）
---
EDK2/Mu 本地构建时若出现大量 'Compiler #7000 from : Failed to execute command'，通常是 toolchain 环境变量（CLANGPDB_BIN / CLANGPDB_AARCH64_PREFIX）没导出到 stuart_build 的环境里，而非编译器缺失；确认 /usr/lib/llvm-21/bin 下有 clang/clang++/ld.lld/lld-link/llvm-ar/llvm-lib/llvm-nm/llvm-objcopy/llvm-rc 后带 env 再跑即可。同一平台本地全量构建 DEBUG 约 237s。 — Failed: 本地 stuart_build 首轮失败，日志只有无信息的 Compiler #7000
---
EDK2 stuart/Mu 构建排障：`ext_dep.yaml` 里 nuget 依赖的 `source` 可指向本地目录（把 .nupkg 放进去，绕开 feed 与 mono TLS）；`stuart_update` 报 "We failed to install version X" 时要先 `unzip -t` 校验 nupkg 是否残包（残包不报下载错、file 仍显示 Zip）。CI（ubuntu-latest）与本地编译器版本不同（clang-18 vs clang-21）会导致产物字节不一致（FD 内容 ~64% 不同）但结构等价（同为 4 MiB FD + arm64 壳 + _FVH）。 — Failed: feed/下载/工具链变量的非显性失败模式
---
Mu/EDK2 的 ClangPdbToolChain 插件读 CLANG_BIN：自动探测时才会在路径末尾补 os.sep，用户自设时原样拼接——缺结尾斜杠会得到 `/usr/lib/llvm-21/binclang: not found`，表现为满屏 "Compiler #7000 Failed to execute command"。必须 `export CLANG_BIN=/usr/lib/llvm-21/bin/`（结尾斜杠不可省）；CLANGPDB_BIN 不被该插件读取，设了无效。 — Failed: 本地首次 stuart_build 因缺斜杠导致全部 clang 调用失败，误判为工具链缺失。
---
Mu/EDK2 本地构建依赖从 Azure DevOps 内网 feed 拉 nupkg：flatcontainer 直接路径（.../nuget/v3/flatcontainer/<id>/<ver>/<id>.<ver>.nupkg）会 404；必须先 GET index.json 拿带 GUID 的真实路径（.../_packaging/<guid>/nuget/v3/flat2/<id>/<ver>/...），该路径返回 303 重定向到 blob.core.windows.net。curl -L 直连可行（校内可直连 pkgs.dev.azure.com / nuget.org）。mono 的 nuget.exe 过不去 feed 的 TLS（证书校验失败）。
---
DSI PLL(0) lock failed status=0x00000000 是**开机 probe 期既存噪声**（t≈0.88s ×4），在好发(vk64/vk84)和坏发中**完全相同出现**（各 8 次）。它不是 Q28 判据、不是 Q28 触发点、不随好/坏变化。Q28 的真实判据仍是首次 bonded 命令的 `command DMA timeout: status=0x2200200` + `panel init attempt failed`。未来分析 DSI 日志时不要把 PLL(0) lock failed 当新信号。**2026-11-10 复核（UEFI/ESP 引导路径，`elden_bootloader=esp`）**：同 4 条 `DSI PLL(0) lock failed status=0x00000000` + 4 条 `disp_cc_mdss_{pclk0,pclk1,byte0,byte1}_clk_src: orphan reparent failed: -110` 照旧在 t≈0.87 s 出现，而同一次启动 `dsi_isr`=41、`card0-DSI-1`=connected、`fb0` 正常 ⇒ 该噪声**跨引导路径一致、与好坏发无关**；同批还有 `msm_dsi … Failed to create device link (0x180) with supplier ae96000.dsi for panel@0`（bonded 第二路 DSI 的 device link 未建），好发里同样出现，仅当 bonded 双 DSI 真出问题（Q28/M6）时才能当线索。成因口径 = `clk_ignore_unused` 在无 panel mode 时提前 enable DSI PLL（`archive/topics/复盘.md` 2026-09-30）。
---
## 2026-11-12 · UEFI/GRUB 线三条取证通道结论（细节 `PITFALLS #621/#622/#623`，报告 `reports/uefi-vk188-fbcon-20261112.md`）

- **屏上有内核字 = `earlycon=efifb keep_bootcon`**（光开 `CONFIG_SYSFB_SIMPLEFB` **无字**：fbcon 接管太晚 + msm 接管 DPU 后 GOP buffer 不再被扫描）。取证时同时写 `panic=0`，否则 `panic=15` 十几秒后自动重启，看起来和掉电一模一样。
- **「十多秒掉电」不是掉电**：`panic=15` 的重启。判据 = 设 `panic=0` 后不再重启、屏上停在最后一行。
- **GRUB 阶段没有串口**（ttyGS0 是 Linux gadget、物理 UART 未接）⇒ 需要机器可读时用 `save_env -f ($root)/boot/grub/grubenv` 每步留痕，Linux 起来 `cat /boot/grub/grubenv`。实测有效。
- **`scripts/serial-logger.sh` 在本机会 open/close 狂抖**（`cat &` 拿 EOF 立即退出，日志只有 opened/closed 标记，真数据 0 行）。改用 `scripts/serial-tap.py`（一次 open 长期持有 + select + 断线重开一次；pty 冒烟已过）。
- **initrd 判据**：`head -c4` 必须是 `1f8b0800`（gzip）或 `070701`（newc cpio）。`out/ramdisk-vk181-daily.cpio.gz` 前 **602 字节全 0**（boot.img 里也一样）⇒ `Initramfs unpacking failed: no cpio magic` ⇒ 没 `/init`/没 gadget/没 SSH **且不 panic**，极易误判「内核死了」。b 槽能启动不证明该 ramdisk 可用（b 用的是 boot_b 里的另一份）。
