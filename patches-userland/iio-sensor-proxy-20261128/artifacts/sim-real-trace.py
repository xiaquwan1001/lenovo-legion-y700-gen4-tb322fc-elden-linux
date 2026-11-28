import sys, datetime
lines=[l for l in open('trace-before.txt') if 'Light level' in l]
raw=[]
for l in lines:
    ts=l.split()[0]; lvl=float(l.split("quirk applied): ")[1].split()[0])
    raw.append((ts,lvl))
print("raw samples:", len(raw), "span:", raw[0][0], "->", raw[-1][0])
# duplicate-timestamp journals are 1s resolution: spread samples evenly inside each second
def to_t(raw):
    base=datetime.datetime.fromisoformat(raw[0][0])
    out=[]
    for ts,v in raw:
        dt=(datetime.datetime.fromisoformat(ts)-base).total_seconds()
        out.append((dt,v))
    # monotonic fix: within equal dt, spread
    fixed=[]; last=-1.0
    for dt,v in out:
        if dt<=last: dt=last+1e-6
        fixed.append((dt,v)); last=dt
    return fixed
def patched(seq, MIN=10.0, FAST=2.0, FASTLUX=100.0, SMALL=10.0, HOLD=1.0, BUDGET=6, WIN=60.0):
    prev=0.0; emitted=False; last=0.0; slots=[-1e9]*BUDGET; n=0
    for t,lvl in seq:
        emit=False
        if not emitted: emit=True
        else:
            d=abs(lvl-prev); thr=max(20.0, abs(prev)*0.05); el=t-last
            if (d>=thr or (d>=SMALL and el>HOLD)) and \
               ((el>=MIN) or (el>=FAST and d>=FASTLUX)) and \
               sum(1 for s in slots if t-s < WIN) < BUDGET:
                emit=True
        if emit:
            n+=1; prev=lvl; emitted=True; last=t
            slots[slots.index(min(slots))]=t
    return n
def passthrough(seq):
    p=None;n=0
    for t,v in seq:
        if p is None or v!=p: n+=1; p=v
    return n
seq=to_t(raw)
# 60 s windows
span=seq[-1][0]
print(f"window 0-60s : passthrough={passthrough([s for s in seq if s[0]<=60])}  patched={patched([s for s in seq if s[0]<=60])}")
last60=[s for s in seq if s[0]>=span-60]
print(f"last 60 s    : passthrough={passthrough([(s[0]-(span-60),s[1]) for s in last60])}  patched={patched([(s[0]-(span-60),s[1]) for s in last60])}")
print(f"whole {span:.0f}s : passthrough={passthrough(seq)}  patched={patched(seq)}  -> per 60 s: {patched(seq)/span*60:.1f}")
vals=sorted(set(v for _,v in seq)); print("distinct levels:", len(vals), "min/max:", vals[0], vals[-1])
