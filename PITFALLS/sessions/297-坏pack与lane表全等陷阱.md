## #662 两个「看起来等价」的陷阱：坏 pack 让 worktree/archive 假失败；lane 表「逐字节全等」≠ 行为等价（settle/skew 两组根本不写）

**① `build/m3v2-7.3rc7` 的 pack 有 3 个坏 object ⇒ 派生工作树的两条正路都失败**（2026-11-15 在 CSIPHY lane 实测）：

```
$ git -C build/m3v2-7.3rc7 worktree add --detach /tmp/wt 9d66f26fef
error: failed to read delta base object a1a5720996b7... / fatal: 打包对象 92e6fca8... 已损坏
$ git -C build/m3v2-7.3rc7 archive gh/master | tar -x -C /tmp/src
tar: 归档文件中异常的 EOF          # 941 MB 后截断
```

处置 = **`rsync -a --exclude=.git build/m3v2-7.3rc7/ /tmp/<copy>/`，再把要改的文件覆盖成 `git show gh/master:<path>` 的 blob**。
判据纪律：这样得到的门禁只证明「本枚 + gh/master 的那 N 个文件干净」，**不是**「整棵 7.4-rc3 全绿」，报告里必须写明这一句。

**② CSIPHY lane 表的 `(addr,data,type)` 全等 ≠ 这 13 个值都会被写进硬件**：
上游 `phy-qcom-mipi-csi2-3ph-dphy.c` 的 `phy_qcom_mipi_csi2_gen2_config_lanes()` 里
`CSIPHY_SETTLE_CNT_LOWER_BYTE` 会被运行时算出的 `settle_cnt` **覆盖**、`CSIPHY_SKEW_CAL` 直接 `continue`
（代码里仍是 `TODO: support application of skew from dt flag`）⇒ vendor 2.4.0 与上游 2.1.2 的 13 条 data 差中，
**只有 `0x0000/0x0400/0x0800/0x0c00` 这 4 条真的生效**。
⇒ 写补丁 cover / 回信时**不得**把「表已与 vendor 全等」说成「修复了 xxx」；净行为要单独一句话讲清。

证据：`reports/camss-csiphy-24-delta-20261115.md` §1/§3、`patches/upstream/camss-csiphy-24-20261115/GATES.md` §0。
