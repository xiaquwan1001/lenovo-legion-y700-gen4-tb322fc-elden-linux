# 上游动向观察 2026-10-01 → 2026-11-13

调研口径：lore.kernel.org 本体被 Anubis 反爬挡住（curl 200 但返回 "Making sure you're not a bot"，`/.within.website/` 页），
改用 **patchwork.kernel.org REST API**（同源数据、含 review 评论与状态），辅以 GitHub/GitLab API。
每条均有可点开 URL；无证据的传言不录。

数据面：patchwork 项目 92(linux-arm-msm)、21(dri-devel)、121(alsa-devel)、4(linux-media)、15(linux-wireless)、
17(linux-input)、429(devicetree)、379(linux-soc)、62(linux-arm-kernel)。

---

## §A 与我们有直接交集的补丁线程

| 日期 | 主题 | URL | 状态 | 对我们的动作建议 |
|---|---|---|---|---|
| 2026-11-11 | `[v10,1/2] regulator: dt-bindings: willsemi,wl2868c` — **Rob Herring 给 Reviewed-by** | https://patchwork.kernel.org/patch/14972055/ · 评论 https://patchwork.kernel.org/comment/27361802/ | new（无 blocker） | bindings 侧已过；等驱动侧意见后整串重发 |
| 2026-11-11 | `[v10,2/2] regulator: willsemi,wl2868c: add driver` — **Mark Brown 提问**：LDOx_SEQ 预置非零时，是否要覆盖 SEQ 寄存器，或干脆在非零时隐藏 enable/disable ops | https://patchwork.kernel.org/patch/14972056/ · 评论 https://patchwork.kernel.org/comment/27362144/ | new（等我们回） | 必须回：给出 SEQ 语义/默认值读数，二选一（覆盖 SEQ 或隐藏 ops），改完再发 v11 |
| 2026-11-04 | `[v6,3/5] dt-bindings: arm: qcom: document Lenovo Legion Y700 Gen4` — **Krzysztof**：板子不能带「首次出现的这种 compatible」，措辞要写成 "Add Lenovo Legion Y700 Gen4, a Qualcomm SM8750-based tablet" | https://patchwork.kernel.org/patch/14942834/ | superseded | 改 commit message 后随 dts 串重发 |
| 2026-11-04 | `[v6,5/5] ...elden: describe the WL2868C regulators` — **Krzysztof**：为什么是独立补丁？"One logical action, one commit" | https://patchwork.kernel.org/patch/14942836/ | superseded | elden dts 必须合并成单个「add new hardware」提交（v6 之后我们只重发了 regulator 串，dts 串至今未再发） |
| 2026-11-11 | `drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable` — **Dmitry**：那段解释性注释应进 commit message，不要留在代码里 | https://patchwork.kernel.org/patch/14901898/ · 评论 https://patchwork.kernel.org/comment/27362009/ | new | 改成 v2：注释搬到 commit message，代码只留 `writel(0xc0, ...)` + 一行理由 |
| 2026-11-11 | `[v3,2/3] drm/msm/mdss: reset all block resets described in DT` — **Dmitry 三问**：它是不是中断控制器？副作用是什么？怎么测的？ | https://patchwork.kernel.org/patch/14931324/ | handled-elsewhere（未收） | 先答这三问（寄存器级证据 + 抓 log），否则 dts 侧 R-b 也进不去 |
| 2026-11-11 | `[v3,3/3] arm64: dts: qcom: sm8750: describe all MDSS block resets` — **Abel(11-02) + Dmitry(11-11) 双双 R-b** | https://patchwork.kernel.org/patch/14931325/ | new（有 R-b） | dts 半边可独立推进，拆开单独投 |
| 2026-11-09 | `sm8750: mark the ADSP fastrpc node as non-secure domain` — **Konrad**：这是「nuanced case」，拉 Ekansh/Dmitry/Srini 进线程；另指出 `---` 下方内容不该进 commit log | https://patchwork.kernel.org/patch/14959877/ | v3（11-11）仍 new、无回信 | 等四位定性；同时准备「为什么不能简单写 non-secure」的寄存器/固件证据 |
| 2026-10-31 | `[1/5..5/5] drm/msm/dsi bonded command path` — **Dmitry**：锁若已无保护对象就该删；块注释格式；"what is your base kernel? I don't see these definitions"；"IDs are not assigned by probe order, master is assigned via DT"；"sm8650 struct 的字段就该是 sm8650 的值" | https://patchwork.kernel.org/patch/14929539/ · https://patchwork.kernel.org/patch/14929542/ · https://patchwork.kernel.org/patch/14929543/ | 全串 handled-elsewhere（等于未收） | 需重做：明确 base（7.3-rc7→新基线）、主从关系按 DT 推导、per-SoC cfg 收敛到 sm8650 字段、删多余锁 |
| 2026-10-28 | `[v2,1/9] dt-bindings: media: add Qualcomm SM8750 camera subsystem` — **Krzysztof**：问「7 月 Qualcomm 那版 v6（oss.qualcomm.com）怎么了」 | https://patchwork.kernel.org/patch/14920896/ | superseded | 不能另起一套；要么说明与 v6 的差异并 rebase 到 v6 之后，要么直接接 v6 |
| 2026-10-28 | `[v2,5/9] camss: csid: report frame starts` — **Bryan O'Donoghue**：SOF 与 buf-done 不必同一中断、进/出 idle 会破这套逻辑；他会另发 V4L2_EVENT_FRAME_SYNC 系列作为正解 | https://patchwork.kernel.org/patch/14920895/ | superseded | 丢掉 qtime 锁存方案，改走 FRAME_SYNC 事件（截至 11-13 该系列尚未见投递） |
| 2026-10-28 | `[v2,6/9] camss: video: 只接受物理连续 buffer` — **Bryan**：sm8750 只能物理连续？"gigantic step backwards"，要出处 | https://patchwork.kernel.org/patch/14920894/ | superseded | 要么给出 IOMMU/CSID 侧证据，要么撤掉该限制 |
| 2026-10-27 | `[2/5] dt-bindings: input: awinic,aw86927: document AW86937` — **Krzysztof Acked-by**；同串 [1/5][4/5][5/5] 仅收到自动化 review 意见（E_MASK 位宽、devm 复位动作、suspend 期 stop） | https://patchwork.kernel.org/patch/14918448/ | new | 采纳 bot 提的 `GENMASK(6,5)` 与 devm_add_action_or_reset 两点成本很低，可一并进 v2 |
| 2026-10-22 | `[RFC] clk: qcom: dispcc-sm8750: reset MDSS blocks at probe` — 我们连发两轮追问答疑，**无维护者回信** | https://patchwork.kernel.org/patch/14909706/ | new（无回应） | 按上轮自己承诺的做：v2 挪到 display 侧、用 reset_control_*、补 simple-framebuffer 在场对照；否则直接撤 |

附：`usb: dwc3 双 connector 共 HS 总线` 三串（11-04/11-06）均为 handled-elsewhere，先不投入。

---

## §B 上游待观察（我们补丁可能被接受/被要求改的点）

1. **camss SM8750 的正统序列是 Qualcomm v6（2026-07-21，7 补丁）**，我们的 v2（10-28，9 补丁）被 Krzysztof 直接问「v6 怎么了」→ 我们的相机路线有被并线的风险。
   https://patchwork.kernel.org/series/1131656/
2. **kaanapali(VFE 1080/CSID 1080/camss) v25 于 2026-11-13 重投**，同一批 reviewer（Bryan/Allan Siriani）正在推 gen4 VFE 之外的新代际 → 我们的 vfe gen4 补丁需要与这套新 API（addr_update hooks、CSID reg_update 保护）对齐。
   https://patchwork.kernel.org/patch/14978285/
3. **FastRPC 正在被重构**：`accel/qda: Qualcomm DSP Accelerator driver` v4（25 补丁，2026-11-01，change-id 反复被 Krzysztof NAK 之后才定稿）+ `misc: fastrpc: fix ADSP duplicate session creation` v7（含 `deprecate qcom,nsessions`，2026-11-02，Tyler Baker Tested-by）→ 我们那条「ADSP fastrpc 标 non-secure」dts 补丁会与 nsessions 废弃、CB 手工遍历正面相撞。
   https://patchwork.kernel.org/series/1198307/ · https://patchwork.kernel.org/series/1198581/
4. `arm64: dts: qcom: lemans: Remove secure FastRPC context bank`（2026-11-11，Abel + Bartosz 双 R-b）说明「去 secure CB」这种改法在 Qualcomm 侧是走「删节点」而非「改 domain 属性」——与 Konrad 说的 nuanced case 同源，我们的写法要参考它。
   https://patchwork.kernel.org/patch/14973058/
5. Ard Biesheuvel `fastrpc shared DMA pool 32MB for 16k pages`（2026-11-11，7 补丁串）在动 fastrpc 内存池大小 → 与我们 4K 页假设相关。
   https://patchwork.kernel.org/patch/14972135/
6. **haptics 赛道拥挤**：AW8695（Griffin v3，2026-10-22，bindings 有 Rob Acked-by）与 AW8697（armandas v3，2026-10-13，bindings 用同一个 `awinic,aw86927` 文件）同时在 linux-input → 我们的 AW86937 绑定与 MAINTAINERS 有冲突风险。
   https://patchwork.kernel.org/series/1191158/ · https://patchwork.kernel.org/patch/14885599/
7. **Gunyah 主线驱动无进展**：patchwork 里 Gunyah 主串停在 2023-03 的 v11，2026-10/11 只有两处小补丁（`gunyah_wdt` resume、scm 通过 Qualcomm hypervisor UID 识别 Gunyah）→ 拓展项维持「无上游可依赖」判断。
   https://patchwork.kernel.org/patch/14963763/ · https://patchwork.kernel.org/patch/14962871/
8. **基线过旧**：mainline 已到 **7.4-rc2（2026-11-09）**，stable **7.3.4（2026-11-10）**；我们 M 线仍是 7.3-rc7（Dmitry 已在 dsi 串里问过 base kernel）。
   https://www.kernel.org/releases.json

无证据项（如实记录）：**WCN7861** 在 patchwork 全部相关项目（linux-wireless/ath12k/linux-arm-msm/bluetooth）检索 0 命中，上游只有 WCN7850 侧工作；`TB322FC`、`elden`、`Y700` 的其它（非我们）提交 0 命中。
https://patchwork.kernel.org/projects/

---

## §C 其它仓库版本动向

| 仓库 | 变化（2026-10→11-13） | 影响线 |
|---|---|---|
| GEEKiDoS/linux `v7.2-elden` | **窗口内 0 提交**，tip 停在 2026-09-14（`power: supply: qcom_battmgr: omit SM8750 maximum-load power reading`）；`master` 停在 7.3-rc1（2026-08-30） | G1（下游树无新输入，我们的差分补丁仍是唯一来源） |
| kernel.org 主线/stable | mainline 7.4-rc2（11-09）、stable 7.3.4（11-10）、linux-next next-20261112 | G1（重放目标基线） |
| waydroid/waydroid | 最新 release 仍 **1.6.3（2026-05-28）**；窗口内仅 1 个提交：`dbus: Drop -w from the container service's Exec`（2026-10-16）。Play Integrity/GMS 无新上游讨论（仅有 2026-08-02 的 #2375 游戏风控 issue，属窗口外） | G2（容器侧仍是自维护路径） |
| phoc / wlroots | wlroots 最新 tag **0.20.2（2026-07-07）**；phoc 上游仓库在 gitlab.com/postMarketOS/phoc 与 gitlab.postmarketos.org 均 404，跳转到 gitlab.nura.eco 需鉴权 → **无法核实 phoc 0.55.1 之后的版本** | G2（我们 fork 的 phoc 无上游可比对，需人工作业确认） |
| postmarketOS/pmaports | 主干活跃（linux-postmarketos-stable 升到 **7.3.4**，2026-11-10）；但 qcom 平台包最高只到 sm8250，**无 sm8750 设备/kernel aport** | G1（无外部 sm8750 平台进度可借力） |
| linux-msm/hexagonrpc | 最后功能提交 `rpcd: Map -h to help`（2026-09-15），repo pushed_at 2026-10-01 → **窗口内无功能变更** | G1/G2（ADSP SSC 桥无上游新版本） |
| ptitSeb/box64 | 窗口内 **12 条 BOX64EC 提交**，11-05 集中落地 ARM64EC dynarec（dynarec 内存按 ARM64EC 分配、进 EC 目标走 entry thunk、JIT 内 fault/suspend 处理） | **G3** |
| wine（wine-mirror） | `cscript: Build as ARM64X`（11-12）、`msi: Run msiexec under emulation for x86_64 custom action dlls if the host CPU doesn't match`（11-12） | **G3** |
| ValveSoftware/Proton | 实质只有 `update wine`（2026-10-08），11-10/11-11 为 issue 模板整理 | G3 |

---

## §D 行动建议 Top 5（按对主线阻塞程度）

1. **回 Mark Brown 的 WL2868C 驱动问题（LDOx_SEQ）并出 v11**——这是 elden 相机供电入上游的唯一硬阻塞；bindings 侧 Rob 已 R-b。
   https://patchwork.kernel.org/comment/27362144/
2. **按 Krzysztof 意见把 elden dts 收成单个 "add new hardware" 提交并重发**（v6 之后 dts 串一直没再投，v10 只剩 regulator 两补丁）。
   https://patchwork.kernel.org/patch/14942836/
3. **回答 Dmitry 对 mdss 块复位驱动的三问**，把 dts 半边（已有双 R-b）单独推上去，别让驱动侧拖住。
   https://patchwork.kernel.org/patch/14931324/ · https://patchwork.kernel.org/patch/14931325/
4. **相机线改路线**：放弃自建 9 补丁串，接 Qualcomm v6 并对齐 kaanapali v25 的 VFE/CSID 新 API，SOF 改走 V4L2_EVENT_FRAME_SYNC、撤掉「必须物理连续」限制。
   https://patchwork.kernel.org/series/1131656/ · https://patchwork.kernel.org/patch/14920894/
5. **fastrpc 上会前先定调**：在 Konrad 线程里给寄存器/固件证据，并同时跟踪 accel/qda v4 与 nsessions 废弃，避免 dts 补丁被两份重构夹死。
   https://patchwork.kernel.org/patch/14959877/ · https://patchwork.kernel.org/series/1198581/

（次优先：dsi phy 注释搬家 → v2；haptics v2 顺手采纳 bot 两点；dispcc reset RFC 按承诺补测量或撤回。）

---

### 方法学备注（供下次复用）

- lore.kernel.org 全站 Anubis 拦截（`/?q=` 返回 200 但是挑战页，`?x=A` JSON 403），**不要**直接 curl 抓 mbox。
- 可用替代：`https://patchwork.kernel.org/api/1.2/patches/?project=<id>&q=<kw>&since=YYYY-MM-DD&order=-date`，
  评论在 `/patches/<id>/comments/`，系列在 `/api/1.2/series/?project=<id>&q=<kw>`（series 搜索必须带 project）。
- `marc.info` 对应查询路径已 404；`git.kernel.org` 同样被 Anubis 拦。
