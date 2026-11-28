import random
MIN_US=10.0; FAST_US=2.0; FAST_LUX=100.0; SMALL=10.0; HOLD=1.0; BUDGET=6; WIN=60.0

def run(trace):
    prev=0.0; emitted=False; last=0.0; out=[]; slots=[-1e9]*BUDGET
    n=len(trace); dt=60.0/n
    for i,lvl in enumerate(trace):
        t=i*dt; emit=False
        if not emitted: emit=True
        else:
            d=abs(lvl-prev); thr=max(20.0, abs(prev)*0.05); el=t-last
            eligible = d>=thr or (d>=SMALL and el>HOLD)
            gate = (el>=MIN_US) or (el>=FAST_US and d>=FAST_LUX)
            budget_ok = sum(1 for s in slots if t-s < WIN) < BUDGET
            if eligible and gate and budget_ok: emit=True
        if emit:
            prev=lvl; emitted=True; last=t; out.append(lvl)
            j=slots.index(min(slots)); slots[j]=t
    return out
def old(trace):
    p=None;n=0
    for x in trace:
        if p is None or x!=p: n+=1; p=x
    return n
def emitcount(trace):
    prev=0.0; emitted=False; last=0.0; c=0
    n=len(trace); dt=60.0/n
    for i,lvl in enumerate(trace):
        t=i*dt
        if not emitted: c+=1; prev=lvl; emitted=True; last=t; continue
        d=abs(lvl-prev); thr=max(20.0, abs(prev)*0.05); el=t-last
        if (d>=thr or (d>=SMALL and el>HOLD)):
            c+=1; prev=lvl; last=t
    return c
random.seed(11); N=303; vals26=[16*k for k in range(32) if 16*k<=496]
models={}
models['A iid over 26 observed values']=[random.choice(vals26) for _ in range(N)]
random.seed(3); v=random.choice(vals26); tr=[]
for _ in range(N): v=max(0,min(496,v+random.choice([-16,-16,0,16,16]))); tr.append(v)
models['B random walk +-16']=tr
random.seed(5); tr=[]; v=496
for i in range(N):
    if i in (100,200): v=0
    if i==250: v=496
    tr.append(max(0,min(496,v+random.choice([-16,0,16]))))
models['C real steps off/on + dither']=tr
models['D constant 320 lux']=[320]*N
for k,t in models.items():
    o=run(t)
    print(f"{k}: patch={len(o)}/60s values={o[:10]} | deadband-only={emitcount(t)} | 3.9={old(t)}")
