# Diff Shape Classification

How `_decide_add_del_balance` in
[post_per_file.py](../dify_studio_app/nodes/post_per_file.py) reduces one
file's added-line count $a$ and deleted-line count $d$ to a verdict:
**addition**, **balanced**, or **deletion**. The verdict is shape, not size —
500 added against 499 deleted is a rework, and reads as balanced.

## The Measure

Smoothed log-odds of insertions against deletions, with pseudocount
$\alpha = 2$ and cut $\tau = 0.85$ nats:

$$
\lambda = \ln\frac{a + \alpha}{d + \alpha}
$$

The pseudocount acts as two imaginary lines already seen on each side. Small
counts are swamped by it, so $\lambda$ stays near zero however lopsided they
look; large counts render it negligible, so $\lambda$ converges on the true
ratio. One scalar thus carries both how lopsided the change is and how much
evidence stands behind it — a plain ratio test fires on trivial edits, a
plain volume test is blind to tilt.

The logarithm is antisymmetric: swapping $a$ and $d$ negates $\lambda$, so
the two directional branches stay mirror images.

## Procedure

- if $d = 0$, return **addition**
- if $a = 0$, return **deletion**
- if $5(a + 2) > 12(d + 2)$, return **addition**
- if $5(d + 2) > 12(a + 2)$, return **deletion**
- otherwise return **balanced**

The pure cases bypass the measure: with no deletions there is no proportion
to be uncertain about, so direction is observed rather than inferred. They
also exhaust the degenerate inputs, leaving the smoothed test with
$a, d \ge 1$ — division by zero is impossible by construction. The last two
comparisons are mutually exclusive, so no tie-break is needed.

## The Integer Test

Exponentiating preserves the inequality:

$$
\ln\frac{a+2}{d+2} > 0.85
\;\Longrightarrow\;
\frac{a+2}{d+2} > e^{0.85} \approx 2.3396
\;\Longrightarrow\;
5(a + 2) > 12(d + 2)
$$

The rational $\tfrac{12}{5} = 2.4$ moves the effective cut to
$\ln 2.4 \approx 0.875$ nats, under three percent. Nothing transcendental
runs at runtime, only integer multiplication and comparison.

## Behavior

| $a$ / $d$ | verdict | why |
| --- | --- | --- |
| 1 / 0 | addition | short-circuit, at any magnitude |
| 0 / 250 | deletion | short-circuit, at any magnitude |
| 12 / 4 | balanced | three-to-one, but only sixteen lines |
| 21 / 7 | addition | same tilt, now enough evidence |
| 1000 / 900 | balanced | large, but only a five percent tilt |

## Tuning

- raising `LEAN_PSEUDOCOUNT` widens the low-volume balanced zone, leaving
  high-volume behavior alone
- raising $\tau$ demands a steeper ratio everywhere, large files included
- neither knob touches the pure cases, which are unconditional by design
- after changing either, re-derive `LEAN_CUT_HIGH` and `LEAN_CUT_LOW` from
  $e^{\tau}$ rather than editing them by hand
