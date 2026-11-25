// 2026-11-26 晨批 cohort：4 lane 并行（gunyah / sensor-claim / comm-triage / apss-wdt）
return await subagent({
  workflow: 'parallel',
  args: {
    tasks: [
      {
        agent: 'upstream-m',
        model: 'custom.ustc-pool/ustc-dsf2',
        cwd: '/home/xuqianhui/y700-elden',
        task: `【lane G · gunyah 静态推进（主机侧，零设备写）】cwd=/home/xuqianhui/y700-elden

背景：用户要求本项目至少一个 lane 负责 gunyah 线。当前口径：TASKS §5 N2「本 firmware 下不做」= 2026-10-25 终局裁决，后于 2026-11-11 改为「有条件重启」；D19 已判 gunyah_wdt 方案否（reports/d19-gunyah-wdt-20261125.md），候选上机件 out/gunyah-wdt-20261125/ 待核。

任务（只做静态/主机侧，不碰设备写、不发邮件、不改 TASKS 正文）：
1) 读 reports/gunyah-612-samebuild-20261025.md、reports/gunyah-decision-20261025.md、reports/gunyah-restart-assessment-20261111.md、reports/d19-gunyah-wdt-20261125.md、TASKS/README.md §4/§5 的 N2 与 §7 M9 行。
2) 现查事实（命令 + 原始输出为准）：
   - out/gunyah-wdt-20261125/ 是否存在、manifest 里的 sha / 内核串；与在机内核（只读 ssh root@192.168.7.1 'uname -r'）是否同源。
   - 上游主线 drivers/virt/gunyah 与 gunyah watchdog 现状：web_fetch/web_search 查 lore.kernel.org 与 kernel.org（关键词 drivers/virt/gunyah、gunyah-wdt、gunyah watchdog），只认内容级证据，给 URL + 日期。
   - 本地仓内 gunyah 相关补丁/DT/驱动素材清单（rg -n gunyah patches/ rootfs/ reports/ .pi/）。
3) 产出 reports/gunyah-lane-20261126.md（唯一写入路径；中文）：
   - §1 一页结论：gunyah 线「现在能做 / 不能做 / 下一步最小动作」，区分「已结项」与「有条件后续」。
   - §2 事实表（每条 = 命令或 URL + 原始输出摘录 + 时间）。
   - §3 三个候选动作的代价/判据/风险：A 上游化素材（§7 M9：gunyah 驱动集作 G1 补丁素材）B 上机读回 C 归档结项不再投入。
   - §4 给父代理的台账改动建议（TASKS §4.0 D 系列 / §7 M9 行，只出建议文本，不改文件）。
纪律：外部命令全部套 timeout -k；不写其它文件；不 git commit；结论贴原始输出，不许无证据自报成功。`,
      },
      {
        agent: 'physical-exec',
        model: 'custom.ustc-pool/ustc-dsf',
        cwd: '/home/xuqianhui/y700-elden',
        task: `【lane S · 核实「传感器驱动有问题」这个说法（设备在线，严格只读）】cwd=/home/xuqianhui/y700-elden

目标：用实测证据判定该说法成立/不成立/部分成立，并指名在哪一层（内核驱动 / ADSP SSC 服务 / Debian 用户态 / unit 时序）。

设备：ssh -o ConnectTimeout=5 -o BatchMode=yes root@192.168.7.1（在机 7.3.1-debug-vk189-suspend，串口 /dev/ttyACM0 可用）。设备是共享资源，本 lane 是唯一设备使用者，但**只准只读**：禁止 enable/start/stop/mask 任何 unit、禁止 modprobe/rmmod、禁止写 /sys、禁止复现 #692（hexagonrpcd attach ADSP sensor PD 会硬崩整机，见 PITFALLS/README.md #325）。

已知起点（父代理只读抽样，需你独立复核并扩展）：
- hexagonrpcd-adsp-sensorspd: is-enabled=not-found、inactive（该 unit 在机上不存在）
- iio-sensor-proxy: static/inactive
- /dev/fastrpc-adsp 存在，属主 fastrpc:fastrpc（#692 的 owner 前置问题已消失）
- /sys/bus/iio/devices/ 只有 iio:device0

必做检查（每条留原始输出）：
1) 内核层：dmesg | grep -iE 'fastrpc|qcom_q6v5_pas|adsp|ssc|qrtr|glink'；ls /sys/class/remoteproc/*/state 与 name；ls /proc/device-tree/soc@0/remoteproc@6800000/glink-edge/fastrpc/（判 qcom,non-secure-domain 是否真在在机 DTB；PITFALLS 判据：不能只用 strings 计数）；lsmod | grep -E 'fastrpc|qcom_q6v5'。
2) QRTR/服务层：systemctl list-unit-files | grep -iE 'hexagon|sensor|iio|qmi|qrtr'；ls -l /etc/systemd/system/ 看相关 unit 是否被 mask（/dev/null 链接）；/sys/bus/qrtr* 或 ss -l 的 QRTR 侧证据。
3) 用户态：dpkg -l | grep -iE 'libssc|iio-sensor-proxy|hexagon'；ldd /usr/sbin/iio-sensor-proxy | grep -i ssc；timeout -k 3 12 monitor-sensor 抓到的内容；cat /sys/bus/iio/devices/iio:device0/name 与 iio_info 输出。
4) 证据边界：journalctl 最近一次启动里相关 unit 的记录（只读）。
5) 文档侧对账：读 TASKS G1-34 行、PITFALLS/README.md #325/#327、rg -n 'hexagonrpcd|libssc|SSC' TASKS/ PITFALLS/ .pi/memory/，判断「传感器驱动有问题」这句话在历史上具体指哪件事。

产出：reports/sensor-claim-verify-20261126.md（唯一写入路径；中文）
- §1 一页结论 + 判定表：说法 → 成立/不成立/部分成立 → 归因层 → 关键证据（命令 + 输出摘录）。
- §2 逐层证据（内核 / SSC 服务 / 用户态 / unit 时序）。
- §3 最小闭环路径：做通加速度计 + 自动旋转需要哪几步、每步代价与风险（明确哪些步骤会触发 #692 风险，需父代理/用户放行）。
- §4 需用户干预项（如有）。
纪律：每条 ssh 也套 timeout -k；不改设备、不改仓内其它文件、不 git commit；不许把「未测」写成「已测」。`,
      },
      {
        agent: 'mail-io',
        model: 'custom.ustc-pool/ustc-glm',
        cwd: '/home/xuqianhui/y700-elden',
        task: `【lane M · B4/D10 常设通信复扫（只读）】cwd=/home/xuqianhui/y700-elden

任务：沿用昨日中断的 B4 工单（.pi/plans/2026-11-26-next-batch.md §1 B4），做增量复扫，产出 reports/comm-triage-20261126.md。基线 = reports/comm-triage-20261125.md（覆盖到 2026-11-25 01:45Z 左右），增量窗口 = 基线之后到现在。

范围：
1) IMAP（mail.ustc.edu.cn:993，凭据运行时从 keyring 取，BODY.PEEK 保持未读态）INBOX + Junk 增量，只留与我们线程相关的（Greg KH / Dmitry Torokhov / sashiko / guidog / dwc3 / aw86927 / M8 / M10 / M11 / fastrpc / mdss / wl2868c / phosh / droid-juicer / elden / DSN 退信）。
2) lore + patchwork 内容级判定：dwc3 v16（patches/upstream/dwc3-v16-20261125/SENT.md 记的 4×250）、M8 mdss、M10、M11 ping、aw86927 v4、wl2868c（进 regulator for-7.5 后有无 follow-up）。
3) GitLab/GitHub MR/PR 状态现查：phosh !2005、Mobian droid-juicer !46 及昨日新增项。
4) 昨日遗留两件事必须给结论：① dmitry.baryshkov@linaro.org / srinivas.kandagatla@linaro.org 两个死地址（M8 / fastrpc）是否已换址补发并被读到；② IMAP 存储层冻结（11-25T03:44Z 起 INBOX/Junk/Sent 无新件）是否仍成立，若仍冻结给判据（最后一次成功取到的时间戳 + 服务端返回码）。

产出 reports/comm-triage-20261126.md：沿用 20261125 版结构（① 一页结论表 ② 逐条证据 ③ 需用户动作）。
纪律：只读、不发信、不推 MR、不改其它文件、不 git commit；外部命令全部 timeout -k；凭据不落盘；拿不到就写清错误码，不许编状态。`,
      },
      {
        agent: 'impl-worker',
        model: 'custom.ustc-pool/ustc-qwen',
        cwd: '/home/xuqianhui/y700-elden',
        task: `【lane W · B5 APSS watchdog 备料静态复核（主机侧，零设备）】cwd=/home/xuqianhui/y700-elden

工单原文（.pi/plans/2026-11-26-next-batch.md §1 B5）：patches/local/apss-wdt-20261125/ 双推基址 0x16410000 的静态复核（同族 SoC dtsi 对表 + vendor DTB 保护区核对），为上机读回做准备。产出 = 复核备忘 + 上机判据清单。

必做：
1) 读 reports/d19-apss-wdt-prep-20261125.md、reports/d19-gunyah-wdt-20261125.md、patches/local/apss-wdt-20261125/ 全部内容，抽出补丁改了什么、基址/长度/中断/时钟/复位各自依据。
2) 同族 SoC 对表：在本机可得 dtsi 源（arch/arm64/boot/dts/qcom/ 下 sm8750/sm8650/sm8550/x1e 等；内核树已清理则到 ~/src/ 或本地内核仓找）查 watchdog@ 节点、compatible（qcom,kpss-wdt / apss-wdt 等）、reg 基址、clocks、interrupts，列出与 0x16410000 是否一致；给文件路径 + 行号。
3) vendor DTB 侧核对：backup/ 或 out/ 下现存 stock dtb/dtb 镜像（ls/rg 找），dtc -I dtb -O dts 解 watchdog 节点，确认基址与 reserved-memory 是否与补丁冲突（别把 watchdog 写进别人保留区）。
4) 上机判据清单：写内存→读回→KEEPALIVE→真复位路径，逐条给命令与期望输出（零写盘 fastboot boot 前提；本轮不上机）。

产出：reports/b5-apss-wdt-static-review-20261126.md（唯一写入路径；中文）：§1 结论（基址可信/存疑/证伪 + 依据强度）§2 对表证据（文件:行 + 摘录）§3 vendor DTB 核对 §4 上机判据清单 §5 剩余风险与需用户放行项。
纪律：只在 reports/ 下写这一个文件；不 git commit；不碰设备；外部命令全部 timeout -k；每条论断都要能给行号/命令，不许「应该是」。`,
      },
    ],
  },
});
