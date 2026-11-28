#!/usr/bin/env python3
"""sim-0003.py - replay the real device lux trace through the 3 report policies.

Input : trace-before-device-20261128.txt -- the real journal ("Light level sent
        by driver (quirk applied)"), 1507 samples / 301 s, 5 Hz, 16 lux quantum,
        taken 18:04:42-18:09:43 while the ALS was running in a static
        environment (raw mean 168 lux, raw std 91 lux, raw range 0-544 lux).

Policies (each mirrors light_changed_func() after the corresponding patch):
  3.9  : report on every value change (upstream)
  0002 : deadband max(20 lux, 5%) + 1 s hold for >=10 lux + >=10 s spacing
         (fast path >=100 lux after 2 s) + hard budget 6/60 s
  0003 : median-of-5 -> EMA(alpha) -> time+amplitude hysteresis
         * amplitude: |smooth - last_reported| > max(60 lux, 30% of it)
         * time     : that condition must hold for >=3 s (this is what kills a
                      random walk of this amplitude); a >25 lux deviation counts
                      under the same 3 s rule
         * fast path: |median5 - median5-of-the-last-2 s| >= 150 lux for 3
                      consecutive samples (0.6 s) -> snap the filter and report
         * hard budget 6/60 s, first reading always reported

Outputs: per-policy reports / 60 s (worst sliding window), distinct values,
backlight writes (via a gsd-like lux->percent map), and the delay from a
genuine light change to the report, measured on the real noise with a step
added on top.

Run: python3 sim-0003.py [trace]
"""
import collections
import datetime
import math
import statistics
import sys

TRACE = sys.argv[1] if len(sys.argv) > 1 else "trace-before-device-20261128.txt"

# ------------------------------------------------------------------ trace
def load(path):
    raw = []
    for line in open(path):
        if "Light level sent by driver" not in line:
            continue
        raw.append((line.split()[0],
                    float(line.split("quirk applied): ")[1].split()[0])))
    base = datetime.datetime.fromisoformat(raw[0][0])
    pts = [((datetime.datetime.fromisoformat(ts) - base).total_seconds(), v)
           for ts, v in raw]
    # journal timestamps have 1 s resolution: spread a second's samples evenly
    out, i = [], 0
    while i < len(pts):
        j = i
        while j + 1 < len(pts) and abs(pts[j + 1][0] - pts[i][0]) < 1.0:
            j += 1
        n = j - i + 1
        for k in range(n):
            out.append((pts[i][0] + k * (1.0 / n), pts[i + k][1]))
        i = j + 1
    return out


# ------------------------------------------------------------------ policies
MAX_EMITS_PER_MINUTE = 6


class Base:
    budget = MAX_EMITS_PER_MINUTE

    def __init__(self):
        self.slots = [-1e9] * self.budget
        self.emitted = False
        self.prev = 0.0
        self.last = 0.0
        self.cause = collections.Counter()

    def budget_ok(self, now):
        return sum(1 for s in self.slots if now - s < 60.0) < self.budget

    def budget_take(self, now):
        self.slots[self.slots.index(min(self.slots))] = now

    def emit(self, now, value, cause):
        self.prev = value
        self.emitted = True
        self.last = now
        self.cause[cause] += 1
        self.budget_take(now)
        return True, value


class V39(Base):
    name = "3.9 passthru"

    def __init__(self):
        Base.__init__(self)
        self.prev = None

    def feed(self, t, lux):
        if self.prev is None or lux != self.prev:
            self.prev = lux
            return True, lux
        return False, lux


class V0002(Base):
    name = "0002 deadband"

    def feed(self, t, lux):
        if not self.emitted:
            return self.emit(t, lux, "first")
        if self.uses_lux_changed(t):
            return self.emit(t, lux, "unit")
        d = abs(lux - self.prev)
        thr = max(20.0, abs(self.prev) * 0.05)
        el = t - self.last
        if (d >= thr or (d >= 10.0 and el > 1.0)) and \
           (el >= 10.0 or (d >= 100.0 and el >= 2.0)) and self.budget_ok(t):
            return self.emit(t, lux, "deadband")
        return False, lux

    def uses_lux_changed(self, t):
        return False


class V0003(Base):
    """mirrors 0003-light-smoothing-median-ema.patch 1:1 (same order, same maths)"""

    MEDIAN_WINDOW = 5
    EMA_ALPHA = 0.20
    DEADBAND_MIN = 60.0
    DEADBAND_REL = 0.30
    SLOW_STEP_LUX = 25.0
    DWELL = 3.0
    STALE = 20.0
    BIG_JUMP_LUX = 150.0
    BIG_JUMP_RUN = 3
    FAST_INTERVAL = 1.0
    MED_INTERVAL = 10.0
    HIST_REF = 2.0
    HIST_LEN = 16

    def __init__(self, alpha=None):
        Base.__init__(self)
        if alpha is not None:
            self.EMA_ALPHA = alpha
        self.name = "0003 a=%.2f" % self.EMA_ALPHA
        self.samples = collections.deque(maxlen=self.MEDIAN_WINDOW)
        self.ema = None
        self.hyst_since = None
        self.stale_since = None
        self.hist = collections.deque(maxlen=self.HIST_LEN)
        self.fast_run = 0

    def feed(self, t, lux):
        self.samples.append(lux)
        med = float(sorted(self.samples)[len(self.samples) // 2])
        self.ema = med if self.ema is None else \
            self.ema + self.EMA_ALPHA * (med - self.ema)
        smooth = self.ema

        # reference: median of the per-sample medians of the last 2 s
        self.hist.append((t, med))
        while self.hist and t - self.hist[0][0] > self.HIST_REF:
            self.hist.popleft()
        ref = float(sorted(m for _, m in self.hist)[len(self.hist) // 2])
        self.fast_run = self.fast_run + 1 if abs(med - ref) >= self.BIG_JUMP_LUX else 0

        if not self.emitted:
            return self.emit(t, smooth, "first")

        if self.fast_run >= self.BIG_JUMP_RUN:
            # genuine light change: snap median + EMA onto the new plateau
            self.samples.clear()
            self.samples.append(med)
            self.hist.clear()
            self.hist.append((t, med))
            self.ema = med
            self.hyst_since = self.stale_since = None
            self.fast_run = 0
            if self.budget_ok(t) and t - self.last >= self.FAST_INTERVAL:
                return self.emit(t, med, "fast")
            return False, med

        delta = abs(smooth - self.prev)
        thr = max(self.DEADBAND_MIN, abs(self.prev) * self.DEADBAND_REL)

        # (a) amplitude hysteresis: out of the deadband for >= 3 s
        if delta > thr:
            if self.hyst_since is None:
                self.hyst_since = t
        else:
            self.hyst_since = None

        # (b) staleness cap: a > 25 lux deviation that survived 20 s
        if delta > self.SLOW_STEP_LUX:
            if self.stale_since is None:
                self.stale_since = t
        else:
            self.stale_since = None

        cause = None
        if self.hyst_since is not None and t - self.hyst_since >= self.DWELL:
            if t - self.last >= (self.FAST_INTERVAL if delta >= self.BIG_JUMP_LUX
                                 else self.MED_INTERVAL):
                cause = "hysteresis"
        elif self.stale_since is not None and t - self.stale_since >= self.STALE:
            cause = "stale"
        if cause and self.budget_ok(t):
            self.hyst_since = self.stale_since = None
            return self.emit(t, smooth, cause)
        return False, smooth


# ------------------------------------------------------------------ measures
def run(policy, seq):
    ts, vals = [], []
    for t, lux in seq:
        ok, v = policy.feed(t, lux)
        if ok:
            ts.append(t)
            vals.append(v)
    return ts, vals


def worst_window(ts, win=60.0):
    best, j = 0, 0
    for i in range(len(ts)):
        while ts[i] - ts[j] >= win:
            j += 1
        best = max(best, i - j + 1)
    return best


def worst_bl(vals, ts, win=60.0):
    """max backlight writes inside any 60 s sliding window"""
    def pct(lux):
        return max(1, min(100, int(round(2.5 * math.log2(max(lux, 1.0) + 1.0)))))
    best, j = 0, 0
    for i in range(len(vals)):
        while ts[i] - ts[j] >= win:
            j += 1
        best = max(best, len(set(pct(v) for v in vals[j:i + 1])))
    return best


def with_step(seq, at, delta):
    return [(t, max(0.0, v + delta) if t >= at else v) for t, v in seq]


def step_latency(factory, seq, at, delta):
    """(delay, reported value) of the first report at/after the genuine change"""
    pol = factory()
    for t, lux in with_step(seq, at, delta):
        ok, v = pol.feed(t, lux)
        if ok and t >= at:
            return t - at, v
    return None, None


def main():
    seq = load(TRACE)
    span = seq[-1][0]
    raw = [v for _, v in seq]
    print("# trace: %s" % TRACE)
    print("# %d samples / %.0f s (5 Hz, 16 lux quantum); raw mean %.0f, std %.0f, "
          "range %.0f-%.0f, %d distinct values"
          % (len(seq), span, statistics.mean(raw), statistics.pstdev(raw),
             min(raw), max(raw), len(set(raw))))
    print()
    print("| policy         | reports | per 60s | worst60 | worst60 BL | uniq vals |")
    print("|----------------|---------|---------|---------|------------|-----------|")
    for fac in (V39, V0002, lambda: V0003()):
        p = fac()
        ts, vals = run(p, seq)
        print("| %-14s | %7d | %8.1f | %7d | %10d | %9d |"
              % (p.name, len(ts), len(ts) / span * 60.0, worst_window(ts),
                 worst_bl(vals, ts), len(set(round(v, 1) for v in vals))))
    print()
    print("# worst60 = reports inside the busiest 60 s sliding window,")
    print("# worst60 BL = backlight writes (gsd-like lux->percent) in the busiest window")
    print()
    print("# alpha sweep (median 5 -> EMA(alpha) per sample, dwell 3 s, stale cap 20 s)")
    for a in (0.15, 0.18, 0.20, 0.22, 0.25):
        p = V0003(alpha=a)
        ts, vals = run(p, seq)
        print("  alpha=%.2f: reports=%2d worst60=%d worst60BL=%d causes=%s"
              % (a, len(ts), worst_window(ts), worst_bl(vals, ts), dict(p.cause)))
    print()
    print("# fast-path robustness on the static trace: any 'fast' report here is a")
    print("# false trigger (this 302 s window contains no deliberate light change)")
    for thr in (100.0, 120.0, 130.0, 150.0, 180.0):
        V0003.BIG_JUMP_LUX = thr
        p = V0003()
        ts, vals = run(p, seq)
        print("  fast cutoff %3.0f lux: reports=%2d  false fast reports=%d  worst60=%d"
              % (thr, len(ts), p.cause["fast"], worst_window(ts)))
    V0003.BIG_JUMP_LUX = 150.0
    print()
    print("# genuine light change added on top of the real noise, and its latency")
    print("| step                                 | 3.9     | 0002     | 0003 a=0.20 |")
    print("|--------------------------------------|---------|----------|-------------|")
    cases = [("+300 lux (light on)   @ 60 s", 60.0, +300.0),
             ("-300 lux (light off)  @ 120 s", 120.0, -300.0),
             ("+144 lux (dim light)  @ 180 s", 180.0, +144.0),
             ("+96 lux  (lamp)       @ 240 s", 240.0, +96.0),
             ("-64 lux  (shade)      @ 30 s", 30.0, -64.0)]
    for label, at, delta in cases:
        cells = []
        for fac in (V39, V0002, lambda: V0003()):
            d, v = step_latency(fac, seq, at, delta)
            cells.append("silent  " if d is None else "%5.2f s " % d)
        # explain the 0003 number: is the new level even outside the deadband?
        base = V0003()
        reported = None
        for t, lux in seq:
            ok, val = base.feed(t, lux)
            if ok and t < at:
                reported = val
        after = sorted(v for t, v in with_step(seq, at, delta) if at + 2.0 <= t <= at + 5.0)
        plateau = after[len(after) // 2]
        note = ""
        if reported is not None and abs(plateau - reported) <= max(60.0, abs(reported) * 0.30):
            note = ("  <- new level %.0f lux stays inside the deadband of the reported "
                    "%.0f lux, so silence is the right answer" % (plateau, reported))
        print("| %-36s | %7s | %8s | %11s |%s" % (label, cells[0], cells[1], cells[2], note))
    print()
    print("# the first report is unconditional in all three policies, so the")
    print("# Claim() -> first-measurement handshake and the startup-finished")
    print("# notification are unaffected.")


if __name__ == "__main__":
    main()
