#!/usr/bin/env python3
"""sim-0003.py - replay the real device lux trace through the 3 report policies.

Input  : trace-before-device-20261128.txt (real journal, 1507 samples / 301 s, 5 Hz,
         16 lux quantum, single static environment => pure sensor noise)
Policies
  3.9    : report on every value change (upstream)
  0002   : deadband max(20 lux, 5%) + 1 s hold for >=10 lux + >=10 s spacing
           (fast path >=100 lux after 2 s) + hard budget 6/60 s
  0003   : median-of-5 -> EMA(a) -> hysteresis max(60 lux, 30% of last reported)
           or ("changed > 25 lux for > 3 s"); hard reserves: >=150 lux jump of the
           *median* snaps immediately; first reading always reported;
           same 6/60 s hard budget.

Outputs per policy: reports/60 s (worst sliding window over the whole trace),
distinct reported values, and - on synthetic step traces built *on top of* the
real noise - the delay from a genuine light change to the report.

Run: python3 sim-0003.py [trace]      (no pip deps)
"""
import collections
import datetime
import sys

TRACE = sys.argv[1] if len(sys.argv) > 1 else "trace-before-device-20261128.txt"

# ---------------------------------------------------------------- trace loading
def load(path):
    raw = []
    for line in open(path):
        if "Light level sent by driver" not in line:
            continue
        ts = line.split()[0]
        lvl = float(line.split("quirk applied): ")[1].split()[0])
        raw.append((ts, lvl))
    base = datetime.datetime.fromisoformat(raw[0][0])
    out, last = [], -1.0
    for ts, v in raw:
        t = (datetime.datetime.fromisoformat(ts) - base).total_seconds()
        # journal has 1 s resolution: spread the samples of one second evenly
        if t <= last:
            t = last + 1e-6
        out.append((t, v))
        last = t
    # proper even spread inside each second (fix the +1e-6 staircase)
    i = 0
    while i < len(out):
        j = i
        while j + 1 < len(out) and abs(out[j + 1][0] - out[i][0]) < 1.0:
            j += 1
        n = j - i + 1
        if n > 1:
            for k in range(n):
                out[i + k] = (out[i][0] + k * (1.0 / n), out[i + k][1])
        i = j + 1
    return out


# ---------------------------------------------------------------- 0002 policy
LIGHT_DEADBAND_MIN_LUX = 20.0
LIGHT_SMALL_STEP_LUX = 10.0
LIGHT_HOLD_TIME = 1.0
LIGHT_EMIT_MIN_INTERVAL = 10.0      # <= 6 reports/min
LIGHT_FAST_STEP_LUX = 100.0
LIGHT_FAST_STEP_INTERVAL = 2.0
LIGHT_MAX_EMITS_PER_MINUTE = 6


def budget_available(slots, now):
    return sum(1 for s in slots if now - s < 60.0) < LIGHT_MAX_EMITS_PER_MINUTE


def budget_record(slots, now):
    slots[slots.index(min(slots))] = now


class V0002:
    name = "0002"

    def __init__(self):
        self.prev = 0.0
        self.emitted = False
        self.last = 0.0
        self.slots = [-1e9] * LIGHT_MAX_EMITS_PER_MINUTE

    def feed(self, t, lux):
        emit = False
        if not self.emitted:
            emit = True
        else:
            d = abs(lux - self.prev)
            thr = max(LIGHT_DEADBAND_MIN_LUX, abs(self.prev) * 0.05)
            el = t - self.last
            if (d >= thr or (d >= LIGHT_SMALL_STEP_LUX and el > LIGHT_HOLD_TIME)) and \
               (el >= LIGHT_EMIT_MIN_INTERVAL or
                    (d >= LIGHT_FAST_STEP_LUX and el >= LIGHT_FAST_STEP_INTERVAL)) and \
               budget_available(self.slots, t):
                emit = True
        if emit:
            self.prev = lux
            self.emitted = True
            self.last = t
            budget_record(self.slots, t)
        return emit, lux


class V39:
    name = "3.9"

    def __init__(self):
        self.prev = None

    def feed(self, t, lux):
        emit = self.prev is None or lux != self.prev
        self.prev = lux
        return emit, lux


# ---------------------------------------------------------------- 0003 policy
MEDIAN_WINDOW = 5
LIGHT_SMOOTH_DEADBAND_MIN = 60.0      # max(60 lux, 30% of last reported)
LIGHT_SMOOTH_DEADBAND_REL = 0.30
LIGHT_SLOW_STEP_LUX = 25.0            # a sustained small change still counts
LIGHT_SLOW_STEP_TIME = 3.0
LIGHT_BIG_JUMP_LUX = 150.0            # genuine light change -> snap immediately


class V0003:
    def __init__(self, alpha=0.20, median_window=MEDIAN_WINDOW):
        self.alpha = alpha
        self.win = collections.deque(maxlen=median_window)
        self.ema = None
        self.prev = 0.0          # last reported value
        self.emitted = False
        self.last = 0.0
        self.slots = [-1e9] * LIGHT_MAX_EMITS_PER_MINUTE
        self.slow_since = None   # monotonic time the "> 25 lux" condition started
        self.name = "0003 a=%.2f" % alpha

    def feed(self, t, lux):
        self.win.append(lux)
        med = sorted(self.win)[len(self.win) // 2]
        self.ema = med if self.ema is None else self.ema + self.alpha * (med - self.ema)
        smooth = self.ema

        emit = False
        if not self.emitted:
            emit = True
        elif abs(med - self.prev) >= LIGHT_BIG_JUMP_LUX:
            # real light change: do not wait for a 5-sample median + EMA ramp,
            # snap the filter so the reported value is the new plateau at once
            emit = True
            self.ema = med
            self.win.clear()
            self.win.append(med)
            smooth = med
        else:
            delta = abs(smooth - self.prev)
            thr = max(LIGHT_SMOOTH_DEADBAND_MIN,
                      abs(self.prev) * LIGHT_SMOOTH_DEADBAND_REL)
            if delta > thr:
                emit = True
            elif delta > LIGHT_SLOW_STEP_LUX:
                if self.slow_since is None:
                    self.slow_since = t
                elif t - self.slow_since > LIGHT_SLOW_STEP_TIME:
                    emit = True
            else:
                self.slow_since = None
        if emit and not budget_available(self.slots, t):
            emit = False
        if emit:
            self.prev = smooth
            self.emitted = True
            self.last = t
            self.slow_since = None
            budget_record(self.slots, t)
        return emit, smooth


# ---------------------------------------------------------------- measurement
def run(policy, seq):
    """Return (emit times, reported values)."""
    ts, vals = [], []
    for t, lux in seq:
        emit, v = policy.feed(t, lux)
        if emit:
            ts.append(t)
            vals.append(v)
    return ts, vals


def worst_window(ts, win=60.0):
    """Max number of reports in any 'win'-second sliding window."""
    best, j = 0, 0
    for i in range(len(ts)):
        while ts[i] - ts[j] >= win:
            j += 1
        best = max(best, i - j + 1)
    return best


def counts(ts, span):
    return len(ts), (len(ts) / span * 60.0 if span else 0.0)


def backlight_writes(vals):
    """gsd maps lux -> percent; count actual backlight changes for a monotone
    curve. 1:1 with reports is the observed device behaviour, so the number of
    reports is an upper bound; the mapped count is the realistic one."""
    def pct(lux):
        # gsd-power's stepless-ish curve: log2(lux) style, saturating
        import math
        return max(1, min(100, int(round(2.5 * math.log2(max(lux, 1.0) + 1.0)))))
    n, prev = 0, None
    for v in vals:
        p = pct(v)
        if p != prev:
            n += 1
            prev = p
    return n


def report(policy, seq, span, label):
    ts, vals = run(policy, seq)
    total, per_min = counts(ts, span)
    print("| %-12s | %6d | %8.1f | %7d | %7d | %6d |"
          % (label, total, per_min, worst_window(ts), backlight_writes(vals),
             len(set(round(v, 1) for v in vals))))
    return ts, vals


def step_trace(seq, at, delta):
    """Real noise + a genuine light change of 'delta' lux at t='at'."""
    return [(t, max(0.0, v + delta if t >= at else v)) for t, v in seq]


def latency(policy_factory, base_seq, at, delta):
    """Seconds from the genuine change to the first report that carries a value
    within 25% of the post-change plateau (median of the last second)."""
    seq = step_trace(base_seq, at, delta)
    pol = policy_factory()
    plateau = sorted(v for t, v in seq if t >= at)[: max(5, int(len(seq) / 20))]
    plateau = sorted(plateau)[len(plateau) // 2]
    total_shift = delta
    for t, lux in seq:
        emit, v = pol.feed(t, lux)
        if emit and t >= at and abs(v - (plateau - delta)) > 0.25 * abs(total_shift):
            return t - at, v
    return None, None


def main():
    seq = load(TRACE)
    span = seq[-1][0]
    print("# real device trace: %d samples / %.0f s (5 Hz, 16 lux quantum)" % (len(seq), span))
    print()
    print("| policy       | reports | per 60s | worst60 | BL writes | uniq vals |")
    print("|--------------|---------|---------|---------|-----------|-----------|")
    report(V39(), seq, span, "3.9 passthru")
    report(V0002(), seq, span, "0002")
    best = None
    for a in (0.15, 0.20, 0.25):
        ts, vals = report(V0003(alpha=a), seq, span, "0003 a=%.2f" % a)
        w = worst_window(ts)
        if best is None or w < best[1]:
            best = (a, w)
    print()
    print("# alpha sweep: worst 60 s window per alpha")
    for a in (0.15, 0.20, 0.25):
        ts, vals = run(V0003(alpha=a), seq)
        print("  alpha=%.2f worst60=%d total=%d distinct=%d (reported min/median/max: %.0f/%.0f/%.0f)"
              % (a, worst_window(ts), len(ts), len(set(round(v, 1) for v in vals)),
                 min(vals), sorted(vals)[len(vals) // 2], max(vals)))
    print()
    print("# genuine light change latency (real noise + a step; must stay small)")
    print("| step            | 3.9    | 0002   | 0003 a=0.20 |")
    print("|-----------------|--------|--------|-------------|")
    cases = [("+300 lux (light on) @60 s", 60.0, +300.0),
             ("-300 lux (light off) @120 s", 120.0, -300.0),
             ("+150 lux (dimmer) @180 s", 180.0, +150.0),
             ("+60 lux @240 s", 240.0, +60.0)]
    worst = {}
    for label, at, delta in cases:
        row = []
        for fac in (V39, V0002, lambda: V0003(alpha=0.20)):
            d, _ = latency(fac, seq, at, delta)
            row.append("n/a" if d is None else "%.2f s" % d)
            if fac is not V39:
                worst[label] = worst.get(label, 0)
        print("| %-15s | %6s | %6s | %11s |" % (label, row[0], row[1], row[2]))
    print()
    print("# first report is unconditional in every policy (claim handshake unaffected)")


if __name__ == "__main__":
    main()
