# camss 线程回信（2026-10-29，**已发送**）

> **已发送**：`<179325717815.489400.16602455641444097904@mail.ustc.edu.cn>`，
> Sent Items [197]（14:59:38），lore `/linux-media/` 检索命中（`2026-10-29T06:59:46Z`）。
> **发送前新增事实**：上游最新 revision 是 **`[PATCH v23 00/15] media: qcom: camss: Add Kaanapali support`**
> （Hangxiang Ma，2026-10-28，series msgid `20261028-kaanapali-camss-v23-*@oss.qualcomm.com`），
> 不是 lane 对照时用的 v6；且 v23 的 changelog 明写「**Replace the CSID AUP/RUP union with separate
> reg_update/addr_update field pairs**」= 与我们 0004 同一处 ⇒ 正文改成引用 v23 并**主动放弃**该枚。

> 依据 `reports/mail-triage-20261029.md`：krzk 三封明确反感长解释文风（"That's LLM output" / "LLM-generated slop"），
> Bryan + krzk 都指向**上游已有 v6**；另有 FRAME_SYNC 方向的预告。
> 口径：**≤10 行、只答被问的那句、不解释动机、不做辩护**。下面 `~~~` 之间即待发送正文（纯 ASCII）。

~~~
(实际发送版本见文末「已发送正文」；下面是最初草稿)
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

---

## 已发送正文（逐字节，18 行 / 937 B / 纯 ASCII）

```
Answering the open points in one message, short.

1. Kaanapali camss v23 (20261028-kaanapali-camss-v23-0-95f250b18612@oss.qualcomm.com)
   covers what our series tried to do, and its CSID patch already does the
   reg_update/addr_update split. We are dropping our binding, CSIPHY, CSID 980,
   VFE gen4 and DTS patches; no parallel submission from us on those files.

2. Frame start reporting: agreed, CSID should not be the reporter. Dropping that
   patch and looking at V4L2_EVENT_FRAME_SYNC on our side first.

3. Three patches we still think stand alone, none SM8750-specific and none
   touching files v23 touches:
   - media: camss: video: stop already-started subdevices when start fails
   - media: camss: csid: unwind power-on on failure
   - media: camss: video: require DMA-contiguous buffers (with the citation you
     asked for, or dropped)

   We will post them as a small series after rebasing on v23. No dates promised.
```
