# D14③ 反向接法上机（数据线插短边 + PD 插长边）：PD 供电成立，顺手修掉 `charge-watch` 两处误动作（2026-11-28）

- **一句话结论**：反向接法**可行**——数据口在短边（`usb0` NCM + ssh 正常、`udc state=configured`），长边接 PD ⇒ **ADSP 选 PD 口供电**，实测 **9 V 契约 / `input_current_limit=5 000 000` / 电池 +1.679 A**（同一台 PC、同一负载，SDP-only 时是 −770 mA 净放电，PITFALLS #734）。顺手发现并修掉 `charge-watch.sh` 两处误动作（**假 `v_bus` 样本触发降档空转**、**PD 态被按 SDP 口径压档**），另记一条新事实（**电池充满后 ICL 写返回 EINVAL**）。
- **性质**：真机上机（U2，`ssh elden` = `192.168.7.1` over `usb0`），内核 `7.3.1-debug-vk189-suspend-g4da9a8b69fc8-dirty`；接线由用户完成（本项一直是「需插拔」）。
- **关闭项**：`TASKS/dim/D14.md` 的 **③ 反向接法**（此前是 D14 唯一剩余开放项）。

---

## 1. 现场（接好后只读采样）

| 项 | 值 | 说明 |
|---|---|---|
| 数据口 | 短边：`usb0` 192.168.7.1/24、`/sys/class/udc/*/state = configured`、`ssh elden` 通 | 数据链在短边正常（这条也是「反向」的判据之一） |
| typec 端口 | `port0` / `port1` 都是 `host [device]` + `source [sink]` | 两口都在，供电口 = PD 那口 |
| PD 契约 | 08:44–08:45：`voltage_now=8.83 V`、`voltage_max=9 000 000`、`current_max=5 000 000` | 9 V 档 = PD 供电成立（SDP 只能 5 V） |
| 实际取电 | `usb/current_now ≈ 1.28–1.34 A`、`bat/current_now = +1 679 000 µA`、`status=Charging` | 与 SDP 档的 −770 mA 相比是质变 |
| ⚠ `usb_type` | **仍是 `Unknown [SDP] DCP CDP ACA C PD PD_DRP PD_PPS BrickID`**（方括号值 = SDP） | ADSP 报的是**短边数据口**的类型，不是供电口 ⇒ **不能用 `usb_type` 判有没有 PD**，只能认 `voltage_now`/`voltage_max` |
| 充满后 | 电池 100%/`status=Full`、`bat/current_now=0`、契约自动降到 5.4 V（`voltage_max=5 500 000`） | 正常收尾行为；此时 ICL 写被拒（见 §3-B） |

## 2. 修掉的误动作 A：假 `v_bus` 样本把 ICL 打到 500 mA 并空转 70 s

08:42:14 的 `/run/charge-watch.log`：

```
08:42:14 SAG v_bus=80000 uV < 4400000 x3 -> drop ICL to 500000 uA (protect host port)
08:42:16 input_current_limit 3000000 -> 500000 uA
…（每 2 s 一条，持续到 08:43:22，共 34 行）
```

- **80 mV 是物理不可能的读数**（USB 供电源不可能低于 3 V），来源 = 插拔/PD 重谈期间的瞬态样本。原实现「连续 3 次 < 4.4 V 就降档」把它当真塌陷。
- 降档后 ADSP 每次把 ICL 顶回 3 A ⇒ 脚本每 2 s 再写一次 500 mA ⇒ **日志空转**，而这一路本来该跑在 PD 5 A 上。

## 3. 修掉的误动作 B + 新事实：PD 态不该按 SDP 口径压档；充满后写 ICL 返回 EINVAL

- **B**：`charge-watch` 的设计目的是「ADSP 把 SDP 判 100 mA ⇒ 顶回 `current_max` + 洼地保护」。PD 供电源的电流契约由 ADSP 谈定，按 SDP 口径把 ICL 压到 500 mA 无意义（这正是 A 的后果）。
- **新事实**：电池 `status=Full` 后，对 `input_current_limit` 的写入**返回 EINVAL**（`echo 3000000/900000 > …` 三条全失败，读回仍是 5 000 000）；原实现只在写成功时记日志 ⇒ 「写不动」完全静默，正是 A 里最后一段日志消失的原因。

## 4. 处置（已落盘并上机部署）

`scripts/charge-watch.sh`（与 `packaging/elden-userland/files/usr/local/sbin/charge-watch.sh` **逐字节同步**，镜像门 35 对/0 漂移）：

| 改动 | 判据 |
|---|---|
| ① `PD_UV=5500000`：`v_bus ≥ 5.5 V` ⇒ **PD 高压源豁免**，只跟随 `current_max` 一次、不跑洼地状态机 | 9 V 契约下 ICL 稳定 5 000 000、日志只写一行 `PD source … follow current_max` |
| ② `V_VALID_MIN=3000000`：`v_bus < 3 V` 的样本**既不计塌陷也不计恢复** | 连打 6 次 80 mV ⇒ ICL 不动（旧实现第 3 次就降档） |
| ③ 写失败有界记账（首次 + 每 30 次） | 充满后能看到 `write … rejected (EINVAL?)`，不再静默 |
| ④ `battery-care` 抽成 `do_battery_care()`（PD 分支也要跑） | 行为不变 |

- **自测**：`charge-watch.sh --selftest` **13/13 PASS**（原 10 条 + 新增「无效电压不触发降档」「PD 源跟随 current_max」「PD 源不被 SDP 口径压档」）。
- **阴性控制（证明新判据真会红）**：去掉 ② 的过滤 ⇒ `FAIL(1/13)`（正是「无效电压不触发降档」）；去掉 ① 的 PD 分支 ⇒ `FAIL(2/13)`（两条 PD 断言）。
- **部署**：`scp` → `install -m 755` → `systemctl restart charge-watch`；设备 sha `59efd23b6f6c1ce3…` == 仓内；`systemctl is-active` = active；`charge-watch.sh --check` = `verdict: OK`。

## 5. 门禁（父代理自跑）

| 门 | 结果 |
|---|---|
| `deploy-desktop-shell.sh --check` §17 | 5/5 ok（脚本 sha 一致 / `charge-icl-fix.sh` 一致 / udev 规则在位 / unit enabled+active / `ICL=5000000=max`） |
| `check-userland-mirror.sh --check` | 同 sha 配对 **35**｜漂移 WARN **0**｜白名单外 **0**｜设备专有件 80，rc=0 |
| 设备 `/usr/local/sbin/charge-watch.sh --check` | `verdict: OK（ICL=5000000 ≥500 mA…）` |

## 6. 结论与遗留

- **D14 ③ 结项**：反向接法成立且**优于**原接线（PD 9 V/1.3 A，而非 SDP 100 mA 净放电）；代价 = 需要 PD 源（原接线只靠 PC 口）。原「本机规避 = 接 PD 主机/PD hub」从建议升级为**实测可用方案**。
- **遗留（不阻塞）**：① 电池已满，**带负载的净充电量**没在本次取到（+1.679 A 那次采样是充电末期，capacity 报 100 但仍在充）；要量化需把电量放到 ~60% 再测一次（需人值守观察）。② `usb_type` 在本接线下恒报 SDP，任何脚本都不得据此判 PD（已写进 PITFALLS #752）。
