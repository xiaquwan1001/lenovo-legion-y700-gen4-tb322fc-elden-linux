# camss 线程回信草稿（2026-10-29，**未发送**）

> 依据 `reports/mail-triage-20261029.md`：krzk 三封明确反感长解释文风（"That's LLM output" / "LLM-generated slop"），
> Bryan + krzk 都指向**上游已有 v6**；另有 FRAME_SYNC 方向的预告。
> 口径：**≤10 行、只答被问的那句、不解释动机、不做辩护**。下面 `~~~` 之间即待发送正文（纯 ASCII）。

~~~
Answering the open points in one message, short:

1. v2 vs upstream v6: v6 came first and overlaps 5 of our 9 patches (binding,
   CSIPHY, csid-980, vfe-gen4, dts). We will not push those in parallel; treat
   our series as dropping 0001/0004/0008 unless you say otherwise.

2. Frame start reporting: agreed, CSID should not be the reporter. We will drop
   0005 and look at V4L2_EVENT_FRAME_SYNC on our side first.

3. What we still think is worth sending on its own, because it is not
   SM8750-specific and does not touch files v6 touches:
   - 0007 media: camss: video: stop already-started subdevices when start fails
     (ups: reproducing on 7.3-rc7 with a forced failure)
   - 0003 media: camss: csid: unwind power-on on failure
   - 0006 media: camss: video: require DMA-contiguous buffers (will add the
     citation you asked for, or drop it if we cannot)

No dates promised; we will post them as a small series after the next rebase.
~~~

## 发送前检查
- [ ] 收件人：Bryan O'Donoghue、Krzysztof Kozlowski（按 v2 线程原 Cc 列表），`In-Reply-To` 指向他们最近一封
- [ ] 不附补丁（本条只是定调）；补丁另起小系列
- [ ] 全文 ≤ 10 行、零"设计动机"叙述、零 LLM 句式
- [ ] **等用户点头**
