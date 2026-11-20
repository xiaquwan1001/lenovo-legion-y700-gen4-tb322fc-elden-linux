Rework of the v8 binding per Rob Herring's review of
2026-11-10 16:36Z (<20261110163640.GA85824-robh@kernel.org>):

  "ports are for separate data streams. Endpoints are for mux'ed data
   streams. This looks like the latter, so port@0 should have 2 endpoints
   and port@2 dropped."

and, for the GPIO property:

  "Use the gpio mux binding."

Two connectors sharing one High Speed D+/D- pair are two mux'ed data
streams of one port, so they become endpoint@0 and endpoint@1 of port@0
(the Super Speed lane stays port@1).  The GPIO that selects between them
is no longer described by a private "port-select-gpios" property but by a
"gpio-mux" controller referenced from "mux-controls", and the endpoint of
each connector carries the mux state that reaches it.

*** AI-assistance disclosure ***
This patch was prepared with the help of an LLM coding assistant.  The
author reviewed every line and ran the gates quoted in the series notes.

Signed-off-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
