# A2 备答：如果维护者问「kaanapali 也用 SM8550 属性，为什么 SM8750 要特殊？」

> 本文件**不是补丁的一部分**，也不随邮件一起发；只在 review 回包里被问到时抄用。
> 事实来源与证据指针见 `reports/m2-a2-linuxnext-compare-20261027.md` §3。

## 我方立场（三句话）

1. 本补丁的**唯一依据是本机可复现的观测**：TB322FC（SM8750P）上 QBG 固件把 `BATT_POWER_NOW`
   写在 `context + 0x6a8 + 4 * property` 指向的 max-load 槽位，`property = 22` 时读到的是最大负载而非瞬时功率
   （实测充电 <1 W 时 UPower 报 89 W，放电 ~4 W 时报 >100 W）。
2. **我没有对 kaanapali 做同类测量，因此不主张它有问题、也不主张它没问题**。`qcom,kaanapali-pmic-glink`
   目前映射到 SM8550 变体是既有事实，本补丁不改它。
3. 如果维护者认为「一个 SoC 一个变体」不划算，**可接受的替代形态**是给变体数据加一个「不报告 POWER_NOW」的标志位
   （属性表由数据决定），我可以按这个方向重做——但那是行为等价的重构，会多一个前置提交。

## 如果被反问「那是不是 kaanapali 也该去掉」

建议答：**我无法回答，需要测量**。可提供的判据（谁都可跑）：

```sh
# 用 QBG 的 GetMaxLoad 路径特征判定：读到的值是否与最大负载相关、而非瞬时 V*I
upower -d | grep -E "energy-rate|voltage|current"     # 稳态下 energy-rate ≫ voltage*current ⇒ 疑似 max-load
```

## 不要说的话（容易被打回）

- ❌「SM8750 和 kaanapali 是同一代 QBG，所以两个都有问题」——没有 kaanapali 数据，属推断。
- ❌「厂商驱动也这么干」——厂商走的是 downstream `qti_battery_charger`（依赖三个上游不收的接口族），
  这句话会引出「那你怎么不把那个驱动上游化」（`reports/m2-a2-vendor-repo-check-20261026.md` §1）。
