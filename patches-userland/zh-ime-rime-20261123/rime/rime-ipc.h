/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * rime-ipc.h — elden RIME pipe-completer 的进程间协议（客户端/守护共用）
 *
 * 背景（上游事实，见 reports/ime-rime-backend-20261123.md §1.2）：
 *   phosh-osk-stub 的 `pipe` completer 每按一次键就 spawn 一次
 *   `sm.puri.phosh.osk.Completers.Pipe command`，把**完整 preedit** 写到子进程
 *   stdin，从 stdout 按行读候选（pos-completer-pipe.c:340-368）。
 *   ⇒ 每键的固定成本 = 进程 spawn + 一次 RPC。要让 RIME 的 session 状态跨键存活，
 *   必须把 librime 放在常驻进程里，spawn 出来的只是几 KB 的薄客户端。
 *
 * 协议（SOCK_STREAM，unix socket；一问一答，客户端每次连接发一条、读若干行、关闭）：
 *   请求：  <preedit UTF-8>\n            （不含 '\n'；空字符串表示"词已提交/清空"）
 *   响应：  <候选1>\n<候选2>\n…\n\n     （以**空行**结束；0 个候选 = 只发一个空行）
 *
 *   用空行结束而不是 EOF，是为了让客户端在守护进程半死时也能拿到已读到的候选；
 *   0 个候选时仍必须发"\n"——上游 on_communicate_finish() 在 stdout 为空串时
 *   会取 stdout_buf[-1]（pos-completer-pipe.c:305-310），所以客户端绝不能零字节输出。
 *
 * socket 路径解析顺序（两端一致）：
 *   $ELDEN_RIME_SOCK  →  $XDG_RUNTIME_DIR/elden-rime.sock  →  /run/user/<uid>/elden-rime.sock
 */
#ifndef ELDEN_RIME_IPC_H
#define ELDEN_RIME_IPC_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#define ELDEN_RIME_SOCK_NAME "elden-rime.sock"
#define ELDEN_RIME_MAX_LINE  512   /* 单行上限：候选/preedit 都是短语，512 足够 */

static inline const char *
elden_rime_sock_path(char *buf, size_t len)
{
    const char *env = getenv("ELDEN_RIME_SOCK");
    const char *rt;

    if (env && *env) {
        snprintf(buf, len, "%s", env);
        return buf;
    }
    rt = getenv("XDG_RUNTIME_DIR");
    if (rt && *rt) {
        snprintf(buf, len, "%s/%s", rt, ELDEN_RIME_SOCK_NAME);
        return buf;
    }
    snprintf(buf, len, "/run/user/%u/%s", (unsigned)getuid(), ELDEN_RIME_SOCK_NAME);
    return buf;
}

#endif /* ELDEN_RIME_IPC_H */
