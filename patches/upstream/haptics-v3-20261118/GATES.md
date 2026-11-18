# haptics v3 门禁账（2026-11-18，主机侧，**重启后独立复跑**）

> 基线 = mainline **v7.4-rc3 final `aebb727447`**（`build/m3v2-7.3rc7` 的
> `refs/remotes/gh/master`）；门禁全部跑在**从本目录 6 枚 patch 文件 `git am`
> 出来的 pristine 树**上，不用作者工作树。

```sh
git -C build/m3v2-7.3rc7 worktree add --detach /tmp/hap-v3-verify aebb727447
cd /tmp/hap-v3-verify
git am patches/upstream/haptics-v3-20261118/000[1-6]-*.patch
```

| 门 | 命令 | 结果（2026-11-18 10:05–10:15 CST 实跑） |
|---|---|---|
| G1 `git am` | 6 枚按序 | **6/6 干净**（无 offset/fuzz），`HEAD a96979adf5`，树哈希 `c918d45472` 与被打断前 `/tmp/hap-amtest` 的 `90c66a9210` **逐字节同树** |
| G2 checkpatch | `perl scripts/checkpatch.pl --strict --no-signoff --no-tree <patch>` ×6 | 0001/0002：**0E/1W/0C**，W 恒为 `Unknown commit id 'df53055c540f'`；0003–0006：**0E/0W/0C** |
| G2' 同上 + `--ignore UNKNOWN_COMMIT_ID` | 同上 | **6/6 = 0E/0W/0C** |
| G3 编译 `W=1` | 全新 `O=/tmp/kbuild-hap-v3`，`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 -j14 drivers/input/misc/`，`CONFIG_INPUT_AW86927=m` | **rc=0，0 warning / 0 error**；产物 `aw86927.o` 103 560 B |
| G4 dt_binding_check | `make -j14 O=/tmp/kbuild-hap-v3 dt_binding_check DT_SCHEMA_FILES=.../awinic,aw86927.yaml` | **rc=0**（SCHEMA/CHKDT/LINT/STYLE/DTEX/DTC 全部无诊断） |

## G2 的 1 个 W 是环境假阳性（与 v2 同源，判据已复核）

`df53055c540f`（"Input: aw86927 - add support for Awinic AW86938"）是上游真实提交，
**本机内核仓是浅克隆**（`build/m3v2-7.3rc7/.git/shallow` 315 个根，该文件历史截断在
`7.4-rc1`），`git cat-file -t df53055c540f` = 无此对象 ⇒ checkpatch 的
`UNKNOWN_COMMIT_ID` 检查必然命中。全 sha 曾在 `reports/aw86927-series-v2-20261027.md:51`
（kernel.org cgit log 页）核过；v2 的 `README.md` 也把这条登记为已知假阳性。
⇒ 结论取 **内容级 0E/0W/0C**，不把这 1 个 W 当作补丁缺陷。

## 未验（如实）

- **无硬件**：AW86937/AW86938 实件都不在手上，寄存器语义来自厂商驱动 + datasheet；
  High 那条竞态是**按输入核心 + devres 释放顺序推理**的，未上机跑 unbind/suspend 压力。
- 只编 `drivers/input/misc/`，未做全 `make modules`（未验 modpost/链接阶段）。
- G1 的树哈希与 `git am` 结果只证明「本目录 6 枚能干净落到该基线」，不证明 v7.4-rc4/next 上同样干净。
