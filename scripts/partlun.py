#!/usr/bin/env python3
"""partlun.py — TB322FC 分区名 → UFS LUN 的**静态归属表** + 「同名歧义拒绝」。

为什么要有（2026-11-19，脚本审查 P1-3）：
  * 本机是 **6 个 UFS LUN，每 LUN 一张独立 GPT**（不是「一张 GPT 多分区」）。同一个分区名
    在别的 LUN 上也可能存在，而 `lsblk`/`/dev/disk/by-partlabel/<name>` 是**全机命名空间**：
    同名时它只会给你其中一个，且不告诉你「还有另一个」。
  * 仓库里多个脚本靠 `by-partlabel` 或**硬编码 `/dev/sde`** 定位分区
    （`slot-attr.py` 默认 `/dev/sde`、`flash-b.sh` 用 by-partlabel、`uefi-flashed-trial.sh` 用 by-partlabel）
    ⇒ 一旦 (a) 换单元/换表、(b) `--lun` 给错、(c) 未来精简表把某名字挪到另一个 LUN，
    就会**静默写到错的地方**（历史上最贵的一类事故，见 `PITFALLS` #308/#672）。
  * 修法 = 写前把「标签 ∈ 哪个 LUN」变成**可判定**的：查询静态表 → 拿到唯一 LUN → 用 sysfs 的
    `target0:0:<lun>` 反查真实设备节点，**两边一致才允许写**；同名/未知一律拒绝（rc≠0）。

静态表来源（**证据**，不是记忆）：
  `backup/HA2EXB0E-16+512/edl-20261118/gpt{0..5}-primary.bin`（2026-11-17 EDL 只读 dump，
  每 LUN 主表；条目名 UTF-16LE @offset 56，128 B 条目）。表的生成方式：
      python3 scripts/partlun.py --scan backup/HA2EXB0E-16+512/edl-20261118
  另有本机长期存在但**不在原厂 dump 里**的两项（本仓手术表加的）：`linux17` / `eldenesp` ⇒ 归 LUN0。

用法（主机或设备上都能跑，纯 Python 3，无依赖）：
    python3 scripts/partlun.py resolve boot_b            # -> 4
    python3 scripts/partlun.py resolve boot_a dtbo_a     # 多个一起查
    python3 scripts/partlun.py verify-dev /dev/sde --expect-lun 4
    python3 scripts/partlun.py check-label boot_b --dev /dev/sde     # 标签+LUN+设备三者一致才算过
    python3 scripts/partlun.py --scan <dir>              # 从 gptN-primary.bin 现扫一张表（诊断用）
    python3 scripts/partlun.py --selftest                # 反作弊自证（4 类负例必拒）

退出码：0 = 唯一确定且一致；2 = 同名歧义；3 = 未知标签；4 = 设备与预期 LUN 不符 / 无法判定；
        5 = 输入非法。
"""
import argparse
import os
import re
import sys

# 静态表：(label, lun)。**顺序不影响语义**；同名多行 = 歧义（会被拒绝）。
# 来源见文件头；`linux17`/`eldenesp` 是本仓 GPT 手术表新增到 LUN0 的条目。
_STOCK = {
    0: ["proinfo", "lenovolock", "lenovocust", "lenovoraw", "ssd", "persist", "misc", "keystore",
        "frp", "super", "vbmeta_system_a", "vbmeta_system_b", "metadata", "rawdump", "pstoredump",
        "userdata", "linux17", "eldenesp"],
    1: ["xbl_a", "xbl_config_a", "multiimgqti_a", "multiimgoem_a", "apdp"],
    2: ["xbl_b", "xbl_config_b", "multiimgqti_b", "multiimgoem_b", "apdpb"],
    3: ["ALIGN_TO_128K_1", "cdt", "ddr"],
    4: ["uefi_a", "aop_a", "aop_config_a", "tz_a", "hyp_a", "modem_a", "bluetooth_a", "abl_a",
        "dsp_a", "keymaster_a", "spuservice_a", "boot_a", "devcfg_a", "qupfw_a", "vbmeta_a",
        "dtbo_a", "uefisecapp_a", "imagefv_a", "shrm_a", "cpucp_a", "featenabler_a",
        "vendor_boot_a", "qmcs", "qweslicstore_a", "recovery_a", "xbl_ramdump_a", "init_boot_a",
        "cpucp_dtb_a", "pvmfw_a", "soccp_debug_a", "soccp_dcd_a", "pdp_a", "pdp_cdb_a",
        "uefi_b", "aop_b", "aop_config_b", "tz_b", "hyp_b", "modem_b", "bluetooth_b", "abl_b",
        "dsp_b", "keymaster_b", "spuservice_b", "boot_b", "devcfg_b", "qupfw_b", "vbmeta_b",
        "dtbo_b", "uefisecapp_b", "imagefv_b", "shrm_b", "cpucp_b", "featenabler_b",
        "vendor_boot_b", "qweslicstore_b", "recovery_b", "xbl_ramdump_b", "init_boot_b",
        "cpucp_dtb_b", "pvmfw_b", "soccp_debug_b", "soccp_dcd_b", "pdp_b", "pdp_cdb_b",
        "devinfo", "toolsfv", "logfs", "storsec", "uefivarstore", "secdata", "mdcompress",
        "connsec", "tzsc", "spunvm", "xbl_sc_test_mode", "xbl_sc_logs", "dpm"],
    5: ["ALIGN_TO_128K_2", "modemst1", "modemst2", "fsg", "fsc"],
}

TARGET_RE = re.compile(r"target\d+:\d+:(\d+)")


def build_map(table):
    """(label) -> sorted list of LUNs；重复即歧义来源。"""
    m = {}
    for lun, labels in table.items():
        for lab in labels:
            m.setdefault(lab, [])
            if lun not in m[lab]:
                m[lab].append(lun)
    for k in m:
        m[k].sort()
    return m


MAP = build_map(_STOCK)


def resolve(label, map_=None):
    """返回 (luns, rc)：rc=0 唯一；2 歧义；3 未知。"""
    m = MAP if map_ is None else map_
    luns = m.get(label)
    if not luns:
        return [], 3
    if len(luns) > 1:
        return luns, 2
    return luns, 0


def lun_from_sysfs(dev, realpath=os.path.realpath):
    """从 /sys/class/block/<name> 的真实路径里取 target0:0:<lun> 的 lun。

    返回 int 或 None（无法判定）。纯字符串逻辑，便于 selftest 注入假 realpath。
    """
    name = os.path.basename(dev.rstrip("/"))
    sysdir = "/sys/class/block/%s" % name
    real = realpath(sysdir)
    m = TARGET_RE.search(real or "")
    if m:
        return int(m.group(1))
    # 兜底：/sys/block/<name>/device 里没有 target 串时（不同内核布局），看 name 的兄弟
    return None


def scan_dir(d):
    """从 gptN-primary.bin 现扫 (label -> [lun])，用于核对静态表是否与真实 dump 一致。"""
    import struct
    m = {}
    for fn in sorted(os.listdir(d)):
        mm = re.match(r"gpt(\d+)-primary\.bin$", fn)
        if not mm:
            continue
        lun = int(mm.group(1))
        data = open(os.path.join(d, fn), "rb").read()
        if data[4096:4104] != b"EFI PART":
            print("skip %s: 不是 GPT 主表（无 EFI PART）" % fn, file=sys.stderr)
            continue
        ent_lba = struct.unpack_from("<Q", data, 4096 + 72)[0]
        nent = struct.unpack_from("<I", data, 4096 + 80)[0]
        esz = struct.unpack_from("<I", data, 4096 + 84)[0]
        base = ent_lba * 4096
        for i in range(nent):
            e = data[base + i * esz: base + (i + 1) * esz]
            if len(e) < 128 or e[:16] == b"\0" * 16:
                continue
            lab = e[56:128].decode("utf-16-le").split("\0")[0]
            m.setdefault(lab, [])
            if lun not in m[lab]:
                m[lab].append(lun)
    return {k: sorted(v) for k, v in m.items()}


# ---------------------------------------------------------------- selftest
def _selftest():
    fails = []

    def ck(name, cond):
        print("  %s %s" % ("ok  " if cond else "FAIL", name))
        if not cond:
            fails.append(name)

    # 1) 唯一已知标签
    for lab, want in [("boot_b", 4), ("boot_a", 4), ("super", 0), ("linux17", 0),
                      ("eldenesp", 0), ("modemst1", 5), ("cdt", 3), ("xbl_a", 1)]:
        luns, rc = resolve(lab)
        ck("resolve %-12s -> lun %d" % (lab, want), rc == 0 and luns == [want])

    # 2) 未知标签必拒（rc=3，不能默默当成 0 号 LUN）
    luns, rc = resolve("no_such_partition")
    ck("unknown label rejected (rc=3)", rc == 3 and luns == [])

    # 3) 同名歧义必拒（rc=2）——造一张有重复的表
    dup = build_map({0: ["boot_b", "super"], 4: ["boot_b"]})
    luns, rc = resolve("boot_b", dup)
    ck("duplicate label rejected (rc=2, both LUNs listed)", rc == 2 and luns == [0, 4])
    luns, rc = resolve("super", dup)
    ck("non-duplicate still resolves next to a duplicate", rc == 0 and luns == [0])

    # 4) sysfs LUN 解析 + 不一致判据
    fake = {
        "/sys/class/block/sde": "/sys/devices/platform/soc/1d84000.ufshc/host0/target0:0:4/0:0:0:0/block/sde",
        "/sys/class/block/sda": "/sys/devices/platform/soc/1d84000.ufshc/host0/target0:0:0/0:0:0:0/block/sda",
        "/sys/class/block/nvme0n1": "/sys/devices/pci0000:00/0000:00:1d.0/nvme/nvme0/nvme0n1",
    }
    ck("sysfs lun(sde)=4", lun_from_sysfs("/dev/sde", lambda p: fake[p]) == 4)
    ck("sysfs lun(sda)=0", lun_from_sysfs("/dev/sda", lambda p: fake[p]) == 0)
    ck("sysfs 非 UFS（nvme）判不出 -> None",
       lun_from_sysfs("/dev/nvme0n1", lambda p: fake[p]) is None)

    # 5) 静态表必须与真实 dump 一致（有 dump 时才算，缺 dump 记为 skip 不算失败）
    d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                     "backup", "HA2EXB0E-16+512", "edl-20261118")
    if os.path.isdir(d):
        scanned = scan_dir(d)
        diff = []
        for lab, luns in scanned.items():
            if MAP.get(lab) is None:
                diff.append("%s 在 dump 里有、静态表没有 (lun %s)" % (lab, luns))
            elif luns != [l for l in MAP[lab] if l <= 5]:
                diff.append("%s dump=%s 静态=%s" % (lab, luns, MAP[lab]))
        ck("静态表 == dump 现扫（%d 个标签）" % len(scanned), not diff)
        for line in diff[:5]:
            print("       " + line)
    else:
        print("  skip 静态表 vs dump（缺 %s）" % d)

    print("\n== partlun selftest: %s (FAIL=%d)" % ("PASS" if not fails else "FAIL", len(fails)))
    return 0 if not fails else 1


# ---------------------------------------------------------------- CLI
def main(argv):
    ap = argparse.ArgumentParser(description="label -> UFS LUN 归属查询（TB322FC）")
    ap.add_argument("cmd", nargs="?", choices=["resolve", "verify-dev", "check-label"], help="子命令")
    ap.add_argument("args", nargs="*", help="标签或设备节点")
    ap.add_argument("--expect-lun", type=int, help="verify-dev：期望 LUN")
    ap.add_argument("--dev", help="check-label：要核对的设备节点")
    ap.add_argument("--label")
    ap.add_argument("--scan", metavar="DIR", help="从 gptN-primary.bin 现扫一张表")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args(argv)

    if a.selftest:
        return _selftest()
    if a.scan:
        for lab, luns in sorted(scan_dir(a.scan).items()):
            print("%s\t%s" % (lab, ",".join(str(l) for l in luns)))
        return 0

    if a.cmd == "resolve":
        if not a.args:
            ap.error("resolve 需要至少一个标签")
        rc = 0
        for lab in a.args:
            luns, r = resolve(lab)
            if r == 0:
                print("%s\t%d" % (lab, luns[0]))
            elif r == 2:
                print("%s\tAMBIGUOUS(luns=%s)" % (lab, ",".join(map(str, luns))), file=sys.stderr)
                rc = max(rc, 2)
            else:
                print("%s\tUNKNOWN" % lab, file=sys.stderr)
                rc = max(rc, 3)
        return rc

    if a.cmd == "verify-dev":
        if not a.args:
            ap.error("verify-dev 需要设备节点")
        rc = 0
        for dev in a.args:
            got = lun_from_sysfs(dev)
            if got is None:
                print("%s\tUNRESOLVED（不在 UFS sysfs 布局里？）" % dev, file=sys.stderr)
                rc = max(rc, 4)
                continue
            want = a.expect_lun
            if want is None:
                print("%s\tlun=%d" % (dev, got))
                continue
            if got != want:
                print("%s\tMISMATCH 实际 lun=%d ≠ 期望 %d" % (dev, got, want), file=sys.stderr)
                rc = max(rc, 4)
            else:
                print("%s\tlun=%d (ok)" % (dev, got))
        return rc

    if a.cmd == "check-label":
        if not a.label or not a.dev:
            ap.error("check-label 需要 --label 与 --dev")
        luns, r = resolve(a.label)
        if r != 0:
            print("%s\t%s" % (a.label, "AMBIGUOUS" if r == 2 else "UNKNOWN"), file=sys.stderr)
            return r
        got = lun_from_sysfs(a.dev)
        if got is None:
            print("%s\t无法从 sysfs 判定 %s 的 LUN（不在 UFS 上？）" % (a.label, a.dev), file=sys.stderr)
            return 4
        if got != luns[0]:
            print("%s\t拒绝：%s 属于 LUN%d，但 %s 是 LUN%d"
                  % (a.label, a.label, luns[0], a.dev, got), file=sys.stderr)
            return 4
        print("%s\tlun=%d 且 %s 一致（ok）" % (a.label, got, a.dev))
        return 0

    ap.print_help()
    return 5


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
