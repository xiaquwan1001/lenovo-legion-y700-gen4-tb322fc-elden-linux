# #654 给发行版同名包换二进制：只 `install` 不够，必须 divert + hold

- 日期：2026-11-13
- 现场：2026-11-13 夜 C-U7 上机前发现，设备在版 `/usr/bin/phoc` 是 **dpkg 的 0.59~rc1 原件**（`e561c4f5…`，11-09 被 apt 覆盖），而不是我们 11-11 装上去的自编件（`cbfaa59a…`）。后果：C12 L2 的 `wp_linux_drm_syncobj_manager_v1` 全局消失（`wayland-info` 56 个全局、0 个 syncobj）、G1-38 的 OSK 版本门补丁消失。**全程无任何报错**：`systemctl is-active greetd` = active、`phoc` 进程在、桌面正常，只有跑到功能判据才暴露。
- 判据（这类「静默退化」怎么发现）：
  - `dpkg --verify <pkg>` 输出 `??5?????? /usr/bin/<bin>` ⇒ 文件与包记录不符（被换过）。
  - 二进制里查**补丁特征串**（我们的：`strings /usr/bin/phoc | grep -c linux_drm_syncobj`），比查版本号可靠（版本号可能相同）。
  - 所以**每轮上机第一件事**应是核对「在版二进制 = 我们要的那个 sha」，不是看 `dpkg -l` 的版本。
- 处置（两层，缺一不可）：
  1. **`dpkg-divert --package <我们自己起的名> --divert /usr/bin/<bin>.dpkg-dist --rename /usr/bin/<bin>`** —— 这是根本。实测 `apt-get install --reinstall phoc` 之后 `/usr/bin/phoc` 仍是我们的件，发行版原件落到 `.dpkg-dist`。
  2. `apt-mark hold <pkg>` —— 防版本升级连 `.dpkg-dist` 也换掉（换掉就丢了回退基座）。
  - 落地脚本：`scripts/phoc-install.sh`（`--check` / `--install <file>` / `--uninstall`，幂等）。
- 两个实操坑：
  - **正在运行的二进制不能原地覆盖**：`cp`/`dd` 写 `.dpkg-dist` 会 `EACCES: 文本文件忙`（内核对该 inode 持写锁，因为它是运行中 phoc 的可执行文件）。解法 = 写临时名再 `mv -f`（换 inode）。
  - `--rename` 只在**首次**建立 divert 时把现有文件挪到 `.dpkg-dist`；重复跑 `--install` 时 `.dpkg-dist` 里已经是我们的件了 ⇒ 脚本必须能识别（查特征串）并从 apt 缓存 `dpkg-deb -x` 恢复真正的发行版件，否则回退基座就被污染。
- 同类待办（同一模式，还没做）：`elden-ime-focusd` 装 `/usr/local/bin/`（无包冲突，暂不需要）；将来若替换任何 Debian 包提供的可执行文件/库，一律走同一套 divert + hold。
