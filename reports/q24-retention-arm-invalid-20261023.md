# Q24 · vk149（retention 臂）实测：**未取得有效 Q24 样本**（2026-10-23）

> 目的：验证 `reports/q24-retention-rootcause-20261023.md` §5 的假设——7.2 血统缺
> `skip retention by default` 是 Q24 致死条件。
> **结论：没能验证。5 发全部因 Q28 显示栈问题作废，0 发进入有效 Q24 判据。**
> **不得把本文件读成「retention 假设被否证」** —— 我们从未拿到一发真实的 `dpms On→Off`。

---

## 0. 数字结论

| 项 | 结果 |
|---|---|
| 尝试发数 | **5**（18:32 R2；18:40 R1/R2/R3；19:0x R1/R2） |
| **有效 Q24 样本** | **0** |
| 作废原因 | 4 发 = Q28 显示栈（`dpu vblank timeout` / `drm_crtc_wait_one_vblank` WARNING + 硬复位）；2 发 = `SETUP-FAIL-BOOT`（设备掉出 USB） |
| **是否到达真熄屏** | **一次都没有**（全部 `dpms On → unknown`，从未出现 `Off`） |
| 补丁变量是否生效 | **是**（见 §2，反汇编级证据） |
| 对假设的判定 | **未检验**（既非证实也非否证） |

---

## 1. 每发详情

| # | 时间 | boot_id | dpms | 死前签名 | 判定 |
|---|---|---|---|---|---|
| 1 | 18:32 R2 | `c4ab58d9` → `44c81a9e` | On → **unknown** | 死前 `early_dead`，未到 Off | **INVALID（Q28）** |
| 2 | 18:40 R2 | `27c98cc5` → `a17f0d11` | On → **unknown** | `dpu vblank timeout: 400000` + `wait for commit done -110` ×4 | **INVALID（Q28）** |
| 3 | 18:40 R3 | `fe15e351` → `1181081b` | On → **unknown** | 同上 ×2 | **INVALID（Q28）** |
| 4–5 | 19:0x | — | — | `SETUP-FAIL-BOOT`（设备不在 fastboot、SSH 不通） | **未计入** |

**三条判据全部指向 Q28 而非 Q24**：

1. **`dpms` 从未到 `Off`** —— Q24 的定义前提（"真实熄屏"）根本没发生；
2. **死前末帧是 `dpu vblank timeout` / `wait for commit done -110`**，而 Q24 的签名是
   `sys_m_smsm.c:322:err fatal notification received from TZ` + `adsp watchdog`
   （对比 `logs/n5b-vk64-20261023-133658.log.round2.serial`：TZ fatal=2、DPU vblank=**0**）；
3. **对照臂 vk148 同协议 4 发 `vblank timeout` = 0**（`162415.log.round*.serial`），
   本臂三发全部命中 ⇒ **是台架/boot 质量变坏，不是补丁效果**。

---

## 2. 补丁变量确实生效（反汇编级，避免"补丁没编进去"的假阴性）

`rpmhpd_update_level_mapping()` 被内联进 `rpmhpd_probe`。直接对比两臂 `.o` 的反汇编：

**vk148（sync 臂 = 未改 retention 的 7.2 原始语义）**：

```asm
128:  78627b64    ldrh  w4, [x27, x2, lsl #1]     ; buf[i]
12c:  36000063    tbz   w3, #0, 138                ; ← ★ skip_retention_level 门
130:  7100409f    cmp   w4, #0x10                  ; compare with RETENTION
134:  54000160    b.eq  160                        ; skip
```

**vk149（ret 臂 = 补丁后）**：

```asm
128:  7100409f    cmp   w4, #0x10                  ; ← 无 tbz 门，无条件判 retention
12c:  54000160    b.eq  158
```

⇒ **`tbz w3, #0` 这条"只在 `skip_retention_level` 为真时才跳"的分支在 vk149 里消失了**，
与上游 `Skip retention by default` 的语义完全一致。**变量生效已从机器码层面证实**，
所以本轮失败不是"补丁没进去"。

另一条独立确认：`rpmhpd_sync_state` 符号在 vk149 中存在（`ffff800080c90338 t rpmhpd_sync_state`）、
在 vk148 中不存在 —— 两臂各自改的东西都到位了。

---

## 3. 为什么这一轮台架坏了（诚实归因）

- 设备此前已连续跑了多轮 vk64 + 完整相机栈 + 强制重启（`PITFALLS #368` 族）；
- 最后一次尝试时串口显示 `drm_vblank.c:1329` WARNING **刷屏 7470 次**、
  `Call trace: drm_crtc_wait_one_vblank ← drm_client_modeset_wait_for_vblank ← drm_fb_helper_damage_work`，
  但 **`uptime` 跑到 610 s 仍未 panic** ⇒ 不是 Q24 硬复位，是**显示栈卡死导致 USB/SSH 全断**（`PITFALLS #369`）；
- 该状态下设备既不在 fastboot 也无 SSH ⇒ 后续两发 `SETUP-FAIL-BOOT`，**需要人工断电**。

**这是台架状态耗尽，不是假设被推翻。** `TASKS/README.md` §5 Q24 已写明「停止采样」，
本轮也不改变该裁决——它只是证明「继续采样在这台设备上确实不划算」。

---

## 4. 对假设的当前状态

| 项 | 状态 |
|---|---|
| 静态证据（两树 diff + `cmd-db` 档位 + proxy_pd 交集） | **不变，仍然成立** |
| `sync_state` 臂 4/4 活（rail 钉最高档） | **不变，仍成立** |
| retention 臂能否复现"不死" | **未检验**（0 有效样本） |
| 上游 commit 语义 | **不变**（7.3 无条件跳过 retention，是既成事实） |

**⇒ 结论口径维持**：Q24 是 7.2 血统缺陷、7.3 已由上游修复、日常线不需要本地补丁。
**`vk149` 不构成对该结论的支持或反驳**——它没拿到数据。

---

## 5. 若将来要补这一发（不推荐现在做）

前置条件（缺一不可）：
1. 设备**人工彻底断电**后冷启，先在 boot_b（vk147）上跑一遍 Q28 健康门，
   要求 `dmesg | grep -cE "vblank timeout|reset failure"` = **0**，`dpms On→Off` 能成功一次；
2. 只跑 **1 发**，且必须确认 `dpms On → Off` 真的发生，否则直接记为 INVALID 不要重试耗台架；
3. 与**同日同健康度**的 vk64 基线各 1 发配对（否则又是拿坏台架对好台架）。

**但更划算的路径仍然是**：不做。7.3 线 41/41 活 + 上游 commit 已是完整解释；
`vk149` 只影响"我们能否亲手复现这个因果"，不影响任何决策。

---

## 6. 关联

- `reports/q24-retention-rootcause-20261023.md`（静态根因，本文件是其 §5 的实测尝试）
- `reports/q24-syncarm-test-20261023.md`（vk148，4/4 活的那一组）
- `logs/n5b-vk64-20261023-{183223,184045}.log*`
- `PITFALLS #368`（reboot2 早期下发打掉 USB）、`#369`（显示栈坏 ⇒ DBus/USB 全超时）、`#370`（概率性先 diff 两树）
