## #452 `IFS=$'\t'` 读 TSV 会**折叠空字段**，列整体左移 —— 门禁「跑过了但只查了半行」

> 2026-10-27。给 `rootfs/debian/stage.sh` §G 写「单元启用状态」门禁时踩到。

### 一、现象

把写死清单（7 个服务、`multi-user.target` 硬编码）改成「读 `services.tsv` 逐行核」的门禁，
代码结构看着没问题，跑出来却只打印了 **3–4 个服务**的结果，其余静默消失，且 `FAIL` 也不报。

### 二、根因

`services.tsv` 有一个**真空字段**（`before` 列），而 tab 属于 POSIX IFS 空白：

```bash
# 行: name<TAB>init<TAB>class<TAB>desc<TAB>...<TAB>before(空)<TAB>wantedby<TAB>enabled
while IFS=$'\t' read -r f1 f2 … f14; do …; done < services.tsv
```

bash 对 **IFS 内的空白字符（空格/tab/换行）** 会合并连续分隔符，于是 `…<TAB><TAB>…`
按**一个**分隔符处理 ⇒ 后面的字段全部左移一列：

```
backlight-floor|init=ours|by=1|en=        ← wantedby 读到了 enabled 的 "1"
```

`_wantedby=1` ⇒ 循环里 `[ -L ".../1.wants/..." ]` 为假 ⇒ 该行本应报 FAIL，但更早的
`[ -z "${_wantedby:-}" ]` 之类的守卫把它 `continue` 掉了（不同行偏一列不同），最后只剩少数几行
恰好字段数正确、才打印出来。**门禁因此"绿"得像通过，实际大部分行从未被检查。**

### 三、修法

用 awk 按 `-F'\t'` 取列（awk 保留空字段），只输出需要的三列，再按 `|` 读：

```bash
while IFS='|' read -r _name _init _wantedby; do …; done \
  < <(awk -F'\t' 'NR>1 && $1 !~ /^#/ && $14==1 {print $1"|"$2"|"$13}' "$SVC_TSV")
```

顺带把门禁做通用（这才是原始动机）：
- `init=package` 的行由发行版自己启用 ⇒ 只登记一行 ok，不要求我们放 `.wants` 链接；
- `wantedby` 可以是多个 target（`elden-powerlog` = `poweroff.target reboot.target halt.target`）⇒ 逐个查。

### 四、为什么值得记

① **同一类坑在仓库里已出现过一次**：`MANIFEST.tsv` 用 `-` 当空占位（`repo_src` 列），
   现在回头看，很可能就是被这个折叠行为"教育"出来的 —— 修法选择「不留真空字段」。
   `services.tsv` 是**唯一**还留真空字段的 TSV，读它一律走 awk。
② **它伪装成"门禁通过"**：不报错、不报缺、只是少检查了几行。这比报错危险得多。
③ 通用判据：**写 TSV 门禁前先 `awk -F'\t' '{print NF}' | sort -u`** 看字段数是否一致；
   用 `read` 解析必须确认「无空字段」或改用 awk/python。

### 五、附带发现（同一轮）

- 门禁改成通用后立刻抓到一个真回归：`iio-sensor-proxy` 曾被渲染成 `WantedBy=multi-user.target`，
  而它 `After=hexagonrpcd-adsp-sensorspd`（= `hexagonrpcd.service`，包自带 `After=multi-user.target`）
  ⇒ **ordering cycle**，冷起时该服务根本不启动，`systemctl status` 只有一行 cycle 警告、
  `is-active` = `inactive`。用户手工 `restart` 一次就能"修好"，所以长期被当成"偶发"。
  修法 = 挂 `graphical.target`（见 `PITFALLS #453`）。
