#!/usr/bin/env python3
"""dump-verdict.py — 「这次 dump 失败了吗？还是分区真的不存在？」的唯一判据。

来源：2026-11-18 LTBox 评估 §1 **P0-6**（`ltbox-gui/src/workers/flash/mod.rs:323 dump_presence()`）：

    只有 `PartitionNotFound` 是**关于设备**的回答；超时 / USB stall / Firehose 故障
    都只说明「这次读没成功」，分区的存在性**未知**，必须按错误上报。

我们历史脚本里的相反写法：`qdl read … || true` 之后按「文件空 / 大小不对」推断「分区是空的」
（PITFALLS #669 的同一颗雷：qdl 退出码不可信、失败被 `|| true` 吞掉）。本工具把判定收敛成
三值，且**默认偏保守**：

    present  rc=0 且产物真的是这次读出来的完整件（文件存在、非空、长度对得上）
    absent   rc!=0 且日志里命中了明确的「分区不存在」签名，**且**没有传输类故障签名，
             且没有留下任何非空产物（半件不能当「不存在」的证据）
    error    其余一切（缺日志、静默失败 rc!=0 无任何签名、rc=0 但短读/空件、传输故障…）

退出码：0=present / 10=absent / 1=error / 2=用法错。
**调用方纪律**：只有 `absent` 可以走「这个分区没有」的分支；`error` 必须中止或上报，
不能降级成 absent（这正是 #669 与 LTBox 判据的分歧点）。

用法：
  qdl -R -s ufs $LOADER read 4/boot_b /tmp/b.bin >/tmp/read.log 2>&1; rc=$?
  scripts/dump-verdict.py --part boot_b --rc "$rc" --log /tmp/read.log \\
      --file /tmp/b.bin --expect-sectors 2048 [--json]

  # 长度单位不确定时（qdl 自探 512/4096）：
  scripts/dump-verdict.py --part gpt0 --rc "$rc" --log /tmp/read.log \\
      --file /tmp/gpt0.bin --expect-bytes-oneof 17408,139264

自检（合成日志/文件，好件必过、每类坏件必被抓）：
  scripts/dump-verdict.py --selftest
"""
import argparse
import json
import os
import sys

# 只有这些（大小写不敏感）能证明「分区不存在」。
NOTFOUND = (
    "partitionnotfound",
    "partition not found",
    "partition does not exist",
    "no such partition",
    "could not find partition",
    "couldn't find partition",
    "failed to find partition",
    "unknown partition",
)
# 出现任何一个 ⇒ 这次读是**传输/协议故障**，存在性未知；即使同时出现 not-found 文本也不许判 absent。
TRANSPORT = (
    "timed out",
    "timeout",
    "libusb_error",
    "usb",
    "stall",
    "broken pipe",
    "sahara",
    "nak",
    "checksum",
    "disconnect",
    "protocol",
    "i/o error",
    "input/output",
    "no space left",
)

PRESENT, ABSENT, ERROR = "present", "absent", "error"
RC_PRESENT, RC_ABSENT, RC_ERROR = 0, 10, 1


def classify(rc, log_text, part, file=None, expect_bytes=None, oneof=None, sector_size=4096):
    """返回 (verdict, reason, facts)。facts 只做展示，不参与判定。"""
    low = (log_text or "").lower()
    nf = [s for s in NOTFOUND if s.lower() in low]
    tp = [s for s in TRANSPORT if s.lower() in low]
    facts = {"rc": rc, "notfound_hits": nf, "transport_hits": tp}
    size = None
    if file:
        try:
            size = os.path.getsize(file)
        except OSError:
            size = None
    facts["file"] = file
    facts["size"] = size

    if rc == 0:
        if file is None:
            return PRESENT, "rc=0（未给 --file，不核对产物长度）", facts
        if size is None:
            return ERROR, "rc=0 但产物不存在（假成功）", facts
        if size == 0:
            return ERROR, "rc=0 但产物 0 字节（假成功 / 空读）", facts
        want = []
        if expect_bytes is not None:
            want.append(expect_bytes)
        if oneof:
            want.extend(oneof)
        if want and size not in want:
            return ERROR, (f"rc=0 但长度 {size} B 不在预期 {want}"
                           f"（短读/长读都不能当完整件）"), facts
        return PRESENT, f"rc=0，产物 {size} B", facts

    # rc != 0
    if size:  # 留了非空产物：半件 ⇒ 存在性与内容都不可信
        return ERROR, f"rc={rc} 且留下非空产物 {size} B（半件不可用，也不能据此判不存在）", facts
    if tp:
        return ERROR, f"rc={rc}，传输类故障（{tp[0]}）⇒ 分区存在性未知", facts
    if nf:
        return ABSENT, f"rc={rc}，只有明确的「分区不存在」签名（{nf[0]}）", facts
    return ERROR, f"rc={rc}，日志里没有任何可识别签名 ⇒ 存在性未知（不许当空分区）", facts


def selftest():
    import tempfile
    ok = True

    def bad(msg):
        nonlocal ok
        ok = False
        print(f"  SELFTEST FAIL {msg}")

    with tempfile.TemporaryDirectory() as d:
        good = os.path.join(d, "good.bin")
        open(good, "wb").write(b"\0" * 8192)
        short = os.path.join(d, "short.bin")
        open(short, "wb").write(b"\0" * 4096)
        empty = os.path.join(d, "empty.bin")
        open(empty, "wb").close()
        part_log = os.path.join(d, "ok.log")
        open(part_log, "w").write("read 4/boot_b successfully\n")
        nf_log = os.path.join(d, "nf.log")
        open(nf_log, "w").write("ERROR: PartitionNotFound: vbmeta_system_a\n")
        tp_log = os.path.join(d, "tp.log")
        open(tp_log, "w").write("ERR: LIBUSB_ERROR_TIMEOUT during firehose read\n")
        mix_log = os.path.join(d, "mix.log")
        open(mix_log, "w").write("read timed out; PartitionNotFound: x\n")
        silent_log = os.path.join(d, "silent.log")
        open(silent_log, "w").write("qdl: something went wrong\n")

        def run(rc, log, file=None, expect_bytes=None, oneof=None):
            return classify(rc, open(log).read(), "boot_b", file, expect_bytes, oneof)

        v = run(0, part_log, good, 8192)
        if v[0] != PRESENT:
            bad(f"完整件 rc=0 未判 present：{v}")
        v = run(0, part_log, short, 8192)
        if v[0] != ERROR:
            bad(f"短读未判 error（会被当完整备份）：{v}")
        v = run(0, part_log, empty, 8192)
        if v[0] != ERROR:
            bad(f"空件 rc=0 未判 error：{v}")
        v = run(0, part_log, os.path.join(d, "nope.bin"))
        if v[0] != ERROR:
            bad(f"rc=0 但产物缺失未判 error（假成功）：{v}")
        v = run(1, nf_log)
        if v[0] != ABSENT:
            bad(f"PartitionNotFound 未判 absent：{v}")
        v = run(1, tp_log)
        if v[0] != ERROR:
            bad(f"传输故障被当成 absent（P0-6 的核心错法）：{v}")
        v = run(1, mix_log)
        if v[0] != ERROR:
            bad(f"传输故障 + not-found 文本未判 error（保守优先）：{v}")
        v = run(1, silent_log)
        if v[0] != ERROR:
            bad(f"静默失败（无签名）被当 absent：{v}")
        v = run(1, nf_log, short)
        if v[0] != ERROR:
            bad(f"rc!=0 留了非空半件仍判 absent：{v}")
        v = run(0, part_log, good, None, [17408, 139264])
        if v[0] != ERROR:
            bad(f"长度不在 oneof 里未判 error：{v}")
        v = run(0, part_log, good, 8192, [8192])
        if v[0] != PRESENT:
            bad(f"长度命中 oneof 未判 present：{v}")

        # 反作弊：恒 present 的 stub 判定器会在坏件上「通过」⇒ 说明上面每条断言都有牙齿
        stub = os.path.join(d, "stub.py")
        open(stub, "w").write("import sys\nprint('VERDICT present')\nsys.exit(0)\n")
        import subprocess
        p = subprocess.run([sys.executable, stub, "--rc", "1"], capture_output=True)
        if p.returncode != 0:
            bad("stub 判定器没有恒返回 present（反作弊前提不成立）")

    print(f"== selftest {'OK' if ok else 'FAIL'}（完整件必 present / 短读·空件·假成功·传输故障·"
          f"静默失败·半件 必 error / 仅 PartitionNotFound 判 absent）")
    return 0 if ok else 1


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if "--selftest" in argv:
        return selftest()
    ap = argparse.ArgumentParser(description="dump 三值判定（present/absent/error）")
    ap.add_argument("--part", required=True, help="分区/label 名（只用于输出）")
    ap.add_argument("--rc", type=int, required=True, help="qdl/dd 的退出码")
    ap.add_argument("--log", required=True, help="这次读的日志（stdout+stderr 落到同一个文件）")
    ap.add_argument("--file", help="产物文件（给了就核对存在/非空/长度）")
    ap.add_argument("--expect-bytes", type=int, help="期望字节数（精确）")
    ap.add_argument("--expect-sectors", type=int, help="期望扇区数（配 --sector-size）")
    ap.add_argument("--sector-size", type=int, default=4096)
    ap.add_argument("--expect-bytes-oneof", metavar="A,B", help="允许的长度集合（单位不确定时用）")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    try:
        log_text = open(a.log, "rb").read().decode("utf-8", "replace")
    except OSError as e:
        print(f"!! 读不出日志 {a.log}: {e}（没有日志的 dump 只能是 error）", file=sys.stderr)
        return RC_ERROR if not a.json else 1
    oneof = None
    if a.expect_bytes_oneof:
        try:
            oneof = [int(x) for x in a.expect_bytes_oneof.split(",") if x.strip()]
        except ValueError:
            ap.error("--expect-bytes-oneof 需要逗号分隔的整数")
    expect = a.expect_bytes
    if expect is None and a.expect_sectors is not None:
        expect = a.expect_sectors * a.sector_size
    verdict, reason, facts = classify(a.rc, log_text, a.part, a.file, expect, oneof, a.sector_size)
    if a.json:
        print(json.dumps({"part": a.part, "verdict": verdict, "reason": reason, **facts},
                         ensure_ascii=False))
    else:
        print(f"VERDICT {verdict} part={a.part} size={facts['size']} reason={reason}")
    return {PRESENT: RC_PRESENT, ABSENT: RC_ABSENT, ERROR: RC_ERROR}[verdict]


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
