#!/usr/bin/env python3
# send-upstream-report.py — 发送 cambistmclkcc 上游报告 + patch 到 linux-arm-msm
# 凭据：环境变量 OUTLOOK_APP_PASSWORD（不写盘、不进 git）
import smtplib, sys, os
from email.message import EmailMessage

FROM = "xuqianhui1001@outlook.com"
NAME = "Qianhui Xu"
TO = ["linux-arm-msm@vger.kernel.org"]
CC = ["taniya.das@oss.qualcomm.com", "andersson@kernel.org",
      "konradybcio@kernel.org", "abel.vesa@linaro.org",
      "linux-clk@vger.kernel.org", "devicetree@vger.kernel.org",
      "xuqianhui1001@outlook.com"]

PATCH = "/tmp/upstream-h2/0001-arm64-dts-qcom-sm8750-bind-cambistmclkcc-to-MX-power.patch"
BODY = "/tmp/report-body.txt"

pwd = os.environ.get("OUTLOOK_APP_PASSWORD")
if not pwd:
    sys.exit("需要 OUTLOOK_APP_PASSWORD 环境变量（outlook 授权码）")

patch = open(PATCH).read()
body = open(BODY).read() + patch

m = EmailMessage()
m["From"] = f"{NAME} <{FROM}>"
m["To"] = ", ".join(TO)
m["Cc"] = ", ".join(CC)
m["Subject"] = "[Regression] SM8750 cambistmclkcc: hard reset on display blank; fix = bind to MX only"
m["Message-ID"] = "<cambist-mclkcc-mcx-collapse-20261008@outlook.com>"
m.set_content(body)

s = smtplib.SMTP("smtp-mail.outlook.com", 587, timeout=30)
s.starttls()
s.login(FROM, pwd)
s.send_message(m)
s.quit()
print("SENT OK")
