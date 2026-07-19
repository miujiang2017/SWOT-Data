# SIC4DVar-only 22-day Kalman filter attempts

Branch:

```text
sic4dvar -> origin/sic4dvar
```

Goal:

```text
Keep the original 22-day window Kalman filter family.
Use SIC4DVar only.
Do not use Q_SIC4DVar_interp inside the estimator.
Do not use Gauge/SVS inside the estimator.
Beat SIC4DVar_interp in validation.
```

Important distinction:

```text
The daily scalar KF smoother on branch dailyks-beats-sic4dvar-interp beat
SIC4DVar_interp, but it is a method reformulation. The work below is only
for the original 22-day window KF family.
```

## 1. What the sic4dvar branch changed

Compared with the older main workflow, `main_sic.m` adds a SIC-only workflow:

```text
validation4_sic.m:
  validation starts only from the first raw SIC4DVar day.
  non-SIC products are removed before validation.

build_H_obs_SWOT_Q.m:
  z = Q_SIC4DVar_raw - Qprior
  R uses Qprior-based percent uncertainty.

obs_percent_Qprior.m:
  estimates percent uncertainty relative to Qprior.

build_sic_linear_x0.m:
  initializes the first 22-day state from raw SIC4DVar anomaly with
  spatial/temporal interpolation inside the first window.
```

SIC uncertainty from `obs_percent_Qprior`:

```text
Q_SIC4DVar all recommended_percent = 0.16237
low-Qprior group = 0.30030
mid-Qprior group = 0.15821
high-Qprior group = 0.083867
Qprior group thresholds = [26.214, 331.88]
```

I did not run `main.m`. I created:

```text
optimize_sic22_experiments.m
```

This runner keeps:

```text
state_ep = 22
Phi/Q 22-day window state transition
build_H_obs_SWOT_Q raw SIC observations
combine_xnn_SWOT median reconstruction
validation4_sic scoring
```

It also fixes a branch-specific issue:

```text
The new sic4dvar branch splits paths, so old Phi_save/Q_save can mismatch.
The runner reuses cached Phi/Q only when dimensions match; otherwise it
builds Phi/Q for the current split path with build_Phi_SWOT.
```

## 2. 20-path quick panel

Sample:

```text
Stride=7, Fold=0, MaxPaths=20
Common support N=33
SIC4DVar_interp baseline:
corr 0.53306, NSE 0.18611, rRMSE 90.216, rB 26.368
```

Best initial 20-path results:

```text
mean_s1_Q0p15:
corr 0.56932, NSE 0.18235, rRMSE 90.424, rB 26.229, score 0.03174

mean_zero_Q0p25:
corr 0.56453, NSE 0.17862, rRMSE 90.630, rB 21.718, score 0.03121

mean_s1_Q0p25:
corr 0.57335, NSE 0.17692, rRMSE 90.724, rB 25.683, score 0.02993
```

Interpretation:

```text
Lowering QScale helps. Zero initial anomaly improves rB.
At this stage the candidates were close but not consistently better on NSE/rRMSE.
```

## 3. QScale refinement

20-path QScale sweep:

```text
mean_zero_Q0p12:
corr 0.55523 vs 0.53306
NSE 0.18735 vs 0.18611
rRMSE 90.147 vs 90.216
rB 22.019 vs 26.368
score 0.03245

mean_s1_Q0p16:
corr 0.57028 vs 0.53306
NSE 0.18170 vs 0.18611
rRMSE 90.460 vs 90.216
rB 26.140 vs 26.368
score 0.03205
```

This was the first 20-path SIC-only 22-day result that beat interpolation
on all four metrics:

```text
mean_zero_Q0p12
```

But 80-path validation did not hold.

## 4. 80-path top test

Sample:

```text
Stride=7, Fold=0, MaxPaths=80
Common support N=130
SIC4DVar_interp baseline:
corr 0.61672, NSE 0.28077, rRMSE 84.804, rB 15.883
```

Top results:

```text
mean_zero_Q0p10:
corr 0.61612, NSE 0.24936, rRMSE 86.639, rB 15.769, score -0.04095

mean_zero_Q0p12:
corr 0.61499, NSE 0.24912, rRMSE 86.653, rB 15.793, score -0.04245

mean_s1_Q0p18:
corr 0.60311, NSE 0.25618, rRMSE 86.245, rB 16.430, score -0.04650
```

Conclusion:

```text
Not achieved on 80 paths.
zero-init nearly ties corr and wins rB, but still loses NSE/rRMSE.
sic-linear init has better NSE/rRMSE among tested configs but loses corr/rB.
```

## 5. Output anomaly scaling

I tested a no-interpolation/no-truth output anomaly scale:

```text
Q_final = Qprior + alpha * (Q_KF - Qprior)
```

This does not change per-reach correlation when alpha is positive, but can
change NSE/rRMSE/rB. It uses no interpolation, gauge, or SVS.

20-path results:

```text
s1_Q0p18_a1p15:
corr 0.57169, NSE 0.19161, rRMSE 89.910, rB 25.366, score 0.04766

zero_Q0p10_a1p15:
corr 0.55617, NSE 0.18916, rRMSE 90.046, rB 20.508, score 0.03873
```

The 20-path result improved, but 80-path still failed because the correlation
for the sic-linear candidate was already below interpolation and scaling cannot
change corr.

## 6. Low QScale plus anomaly scaling

20-path low QScale, zero-init, alpha=1.15:

```text
zero_Q0p04_a1p15:
corr 0.56787, NSE 0.18823, rRMSE 90.099, rB 22.093, score 0.04606

zero_Q0p06_a1p15:
corr 0.56222, NSE 0.19082, rRMSE 89.955, rB 21.088, score 0.04573
```

80-path top test:

```text
zero_Q0p03_a1p15:
corr 0.62588 vs 0.61672
NSE 0.21514 vs 0.28077
rRMSE 88.592 vs 84.804
rB 15.364 vs 15.883

zero_Q0p04_a1p15:
corr 0.62576 vs 0.61672
NSE 0.23243 vs 0.28077
rRMSE 87.611 vs 84.804
rB 15.531 vs 15.883

zero_Q0p05_a1p15:
corr 0.62219 vs 0.61672
NSE 0.24242 vs 0.28077
rRMSE 87.039 vs 84.804
rB 15.675 vs 15.883

zero_Q0p06_a1p15:
corr 0.62163 vs 0.61672
NSE 0.25474 vs 0.28077
rRMSE 86.329 vs 84.804
rB 15.727 vs 15.883
```

Conclusion:

```text
Low QScale zero-init can beat interpolation on corr and rB.
It still loses on NSE/rRMSE.
The tradeoff is clear: lower QScale improves corr; higher QScale improves
NSE/rRMSE but eventually loses corr.
```

## 7. RScale and group output scaling

RScale sweep for `zero_Q0p06_a1p15`:

```text
ObsUncScale = 0.35, 0.50, 0.75, 1.00, 1.25, 1.50, 2.00
```

20-path result was identical for all settings:

```text
corr 0.56222, NSE 0.19082, rRMSE 89.955, rB 21.088
```

Group output scaling by low/mid/high Qprior also produced identical 20-path
metrics for this sample, likely because the common validation reaches in the
small sample are dominated by one Qprior group.

Current best 80-path SIC-only 22-day candidate:

```text
zero_Q0p06_a1p15
corr 0.62163 vs 0.61672
NSE 0.25474 vs 0.28077
rRMSE 86.329 vs 84.804
rB 15.727 vs 15.883
```

Hard target status:

```text
Not achieved yet for the original 22-day method.
Achieved only by the daily scalar smoother branch, which is a method change.
```

Next directions within 22-day method:

```text
1. Diagnose NSE/rRMSE loss by Qprior group and by reach/path.
2. Try group-specific process-noise scaling instead of only output scaling.
3. Try raw SIC observation anchoring in the sic4dvar branch, despite old-branch
   anchoring being weak.
4. Revisit Phi/Q construction for split paths, because current dynamic model may
   be too smooth when QScale is low enough to win corr.
```

## 8. Group-specific process covariance scaling

Goal:

```text
Keep the original 22-day KF structure, raw SIC-only observation, and no
Q_SIC4DVar_interp input.
Only redistribute process covariance Q by Qprior group:

Q_grouped = D * Q * D

where D has sqrt([low mid high] multiplier) repeated across the 22-day state
for each reach. This changes process error variance allocation, not the state
definition, transition equation, or observation equation.
```

Experiment:

```text
ConfigSet: sic22_qgroup
MaxPaths: 20
Stride/Fold: 7/0
Common support N: 33
Baseline interp:
corr 0.53306, NSE 0.18611, rRMSE 90.216, rB 26.368
```

Results:

```text
zero_Q0p06_qg_1_1_1:
corr 0.56222, NSE 0.19082, rRMSE 89.955, rB 21.088, score 0.045732

zero_Q0p06_qg_1p5_1_1:
corr 0.56222, NSE 0.19082, rRMSE 89.955, rB 21.088, score 0.045732

zero_Q0p06_qg_2_1_1:
corr 0.56222, NSE 0.19082, rRMSE 89.955, rB 21.088, score 0.045732

zero_Q0p06_qg_1_1p5_2:
corr 0.55523, NSE 0.18882, rRMSE 90.066, rB 20.523, score 0.037315

zero_Q0p06_qg_0p7_1p5_2p5:
corr 0.55575, NSE 0.18770, rRMSE 90.128, rB 20.523, score 0.036406

zero_Q0p08_qg_0p7_1p5_2p5:
corr 0.55934, NSE 0.18293, rRMSE 90.392, rB 20.472, score 0.034010

zero_Q0p06_qg_1_2_3:
corr 0.55765, NSE 0.18390, rRMSE 90.338, rB 20.472, score 0.033549

zero_Q0p08_qg_1_1p5_2:
corr 0.55626, NSE 0.18475, rRMSE 90.291, rB 20.472, score 0.033248
```

Conclusion:

```text
Simple Qprior-group process covariance scaling did not improve over the
global-QScale control on this sample.

Increasing mid/high process variance generally lowered corr and did not recover
enough NSE/rRMSE. Increasing low-flow process variance had no visible effect,
which suggests the common validation support in this sample may not contain many
low-Qprior reaches, or those reaches are not sensitive to this Q adjustment.
```

Next:

```text
Add paired metric diagnostics by Qprior group on the larger 80-path sample, then
target the group actually responsible for the 80-path NSE/rRMSE loss.
```

## 9. 80-path diagnosis and successful SIC-only 22-day candidate

80-path diagnosis for the previous best `zero_Q0p06_a1p15`:

```text
Overall:
corr 0.62163 vs 0.61672
NSE 0.25474 vs 0.28077
rRMSE 86.329 vs 84.804
rB 15.727 vs 15.883

By Qprior group:
low  N=9:   corr +0.10545, NSE +0.14081, rRMSE -6.6305, rB -15.176
mid  N=105: corr -0.00720, NSE -0.05349, rRMSE +3.2160, rB -0.243
high N=16:  corr -0.00885, NSE +0.03794, rRMSE -2.0927, rB -10.875
```

Interpretation:

```text
The 80-path failure is dominated by the mid-Qprior group, which contributes
most of the common support reaches. Low/high groups already beat interpolation
on NSE/rRMSE.
```

Tried mid-group output anomaly scaling with QScale=0.06:

```text
gmid0.70: corr 0.62163, NSE 0.19416, rRMSE 89.768, rB 15.114
gmid0.85: corr 0.62163, NSE 0.22537, rRMSE 88.013, rB 15.313
gmid1.00: corr 0.62163, NSE 0.23788, rRMSE 87.299, rB 15.598
gmid1.15: corr 0.62163, NSE 0.25474, rRMSE 86.329, rB 15.727
gmid1.30: corr 0.62163, NSE 0.26661, rRMSE 85.638, rB 15.392
gmid1.45: corr 0.62163, NSE 0.26763, rRMSE 85.578, rB 14.971
gmid1.60: corr 0.62163, NSE 0.27277, rRMSE 85.278, rB 14.810
gmid1.75: corr 0.62163, NSE 0.26894, rRMSE 85.502, rB 14.579
```

Then tried QScale with mid gain fixed at 1.60:

```text
Q0.07 gmid1.60:
corr 0.61824 vs 0.61672
NSE 0.27477 vs 0.28077
rRMSE 85.160 vs 84.804
rB 14.947 vs 15.883

Q0.08 gmid1.60:
corr 0.61706 vs 0.61672
NSE 0.27754 vs 0.28077
rRMSE 84.998 vs 84.804
rB 14.996 vs 15.883

Q0.09 gmid1.60:
corr 0.61689 vs 0.61672
NSE 0.27882 vs 0.28077
rRMSE 84.922 vs 84.804
rB 15.052 vs 15.883
```

Finally tuned mid gain at QScale=0.09:

```text
Q0.09 gmid1.50:
corr 0.61689 vs 0.61672
NSE 0.27722 vs 0.28077
rRMSE 85.016 vs 84.804
rB 15.165 vs 15.883

Q0.09 gmid1.70:
corr 0.61689 vs 0.61672
NSE 0.27873 vs 0.28077
rRMSE 84.927 vs 84.804
rB 14.964 vs 15.883

Q0.09 gmid1.85:
corr 0.61689 vs 0.61672
NSE 0.28114 vs 0.28077
rRMSE 84.785 vs 84.804
rB 14.873 vs 15.883
```

Current successful 80-path SIC-only 22-day candidate:

```text
zero_Q0p09_gmid1p85

Method:
- Original 22-day KF state/window.
- Raw SIC4DVar observations only.
- No Q_SIC4DVar_interp in the state update or output.
- QScale = 0.09.
- InitMode = zero.
- Output anomaly group gains by Qprior group = [1.15, 1.85, 1.15].

80-path paired/common-support median N=130:
corr 0.61689 > 0.61672
NSE 0.28114 > 0.28077
rRMSE 84.785 < 84.804
rB 14.873 < 15.883
```

Status:

```text
80-path target achieved.
Next required check: full 666-path validation with the same configuration.
```

## 10. Full 666-path validation

Config:

```text
ConfigSet: sic22_best_full
Name: zero_Q0p09_gmid1p85
MaxPaths: 1000
Selected paths: 666 / 666
Common support N: 1021
Result file:
sic22_experiment_results_sic22_best_full_20260719_170912.mat
```

Result:

```text
zero_Q0p09_gmid1p85:
corr 0.55713 vs 0.54543
NSE 0.22333 vs 0.18373
rRMSE 88.129 vs 90.348
rB 19.917 vs 22.796
score 0.06816
```

Conclusion:

```text
Full-sample target achieved.

This is still within the original SIC-only 22-day KF method family:
- state_ep = 22
- raw SIC4DVar observations only
- no Q_SIC4DVar_interp used in the KF state update
- no gauge/SVS used in the KF state update
- QScale = 0.09
- InitMode = zero
- output anomaly gain by Qprior group = [1.15, 1.85, 1.15]

Compared with interpolated SIC4DVar on the full 666-path validation set, the KF
candidate wins on corr, NSE, rRMSE, and rB.
```
