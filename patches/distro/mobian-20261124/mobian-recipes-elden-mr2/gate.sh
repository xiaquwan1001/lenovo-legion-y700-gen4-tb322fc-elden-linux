#!/usr/bin/env bash
# 静态门：mobian-recipes elden MR-2 备料包 —— 全部本地、只读、零设备。
# 用法：bash gate.sh   （或 ./gate.sh）。任何一步失败 rc=1。
set -u
cd "$(dirname "$0")"
fail=0
ok()   { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fail=1; }

# G1: 片段本身可被 tomllib 解析，且 [[device]] 字段符合 11-22 报告结论 #3/#4
python3 - <<'EOF' || fail=1
import tomllib, sys
d = tomllib.load(open("wip.toml.append", "rb"))
devs = d.get("device", [])
assert len(devs) == 1, devs
v = devs[0]
assert v["vendor"] == "lenovo" and v["model"] == "elden", v
assert v["chipset"] == "sm8750", v          # 11-22 结论 #3：jq 空串真值坑
forbidden = {"version", "dtb", "append", "bootimg", "variant"}
assert not (set(v) & forbidden), set(v) & forbidden  # 11-22 结论 #4：都不写
print("PASS: wip.toml.append tomllib + 字段判据")
EOF

# G2: 合并预览（上游 wip.toml @20261124 + 片段）可解析，且上游模板未被污染
python3 - <<'EOF' || fail=1
import tomllib
m = tomllib.load(open("wip.toml.merged.preview", "rb"))
assert m["chipset"] == "", m["chipset"]     # 顶层保持空（坑只在 jq 消费侧，模板不改）
assert m["bootimg"]["pagesize"] == 0
assert len(m["device"]) == 2
ours = m["device"][1]
assert ours == {"vendor": "lenovo", "model": "elden", "chipset": "sm8750"}, ours
print("PASS: wip.toml.merged.preview tomllib（2 个 [[device]]，末位=elden）")
EOF

# G3: droid-juicer config：schema、条目数、ADSP/CDSP 排除、与 !46 定稿一致
python3 - <<'EOF' || fail=1
import tomllib
d = tomllib.load(open("droid-juicer/lenovo,elden.toml", "rb"))
assert set(d) == {"juicer"}, set(d)
j = d["juicer"]
assert set(j) <= {"dynpart", "firmware", "folders", "partdump"}, set(j)
assert j["dynpart"] == "super"
fw = j["firmware"]
assert len(fw) == 8, len(fw)
# TZ 拒单文件 .mbn（11-22 结论 #6）：只查结构化条目，不查注释（注释合法解释排除原因）
for grp in fw:
    assert "adsp" not in grp["destination"].lower() and "cdsp" not in grp["destination"].lower()
    for f in grp["files"]:
        for key in ("name", "rename"):
            assert not f.get(key, "").endswith(".mdt"), f   # .mdt 会被 squash 成单 .mbn，本板 TZ 拒
dests = {f["destination"] for f in fw}
assert "/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors" in dests
assert len(j["folders"]) == 2, j["folders"]
print("PASS: lenovo,elden.toml schema/8 条 firmware/ADSP-CDSP 排除/传感器树")
EOF

# G4: 与 11-23 成品目录字节一致（单一事实源）
if cmp -s "droid-juicer/lenovo,elden.toml" "../../mobian-20261123/droid-juicer/lenovo,elden.toml"; then
  ok "与 patches/distro/mobian-20261123/droid-juicer 定稿字节一致"
else bad "与 11-23 定稿出现分叉"; fi

# G5: 门脚本自身语法
bash -n "$0" && ok "gate.sh bash -n" || bad "gate.sh 语法"

exit $fail
