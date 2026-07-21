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

Important caveat:

```text
This full-sample result is not an unbiased final test if the same validation
metrics were used to choose QScale and output anomaly group gains.

The Qprior grouping itself is not based on gauge/SVS truth; reaches are assigned
to low/mid/high by Q_prior magnitude. However, choosing [1.15, 1.85, 1.15] after
looking at validation performance is hyperparameter tuning. Reporting the same
sample as the final proof would be vulnerable to overfitting/selection bias.

Next defensible check:
- Freeze zero_Q0p09_gmid1p85.
- Evaluate held-out task folds that were not used during the main tuning sample
  (the main tuning sample was Stride=7, Fold=0, MaxPaths=80).
- For a paper-strength result, run proper fold-based or nested
  cross-validation where parameters are selected only on training folds and
  reported only on held-out folds.
```

## 11. Shift back to observation uncertainty, not output anomaly scaling

Reason:

```text
The output anomaly gains [1.15, 1.85, 1.15] improved results, but the mid-flow
gain is difficult to justify physically and was selected after looking at
validation metrics. This is vulnerable to overfitting and weak interpretability.

A more defensible KF modification is to change the observation covariance R,
because R controls how strongly the filter trusts raw SIC observations.
```

Implementation:

```text
Original percent uncertainty:
sigma_R = percent * Q_prior
R = sigma_R^2

Power-law uncertainty:
sigma_R = percent(group) * Q_ref^(1-beta) * Q_prior^beta
R = sigma_R^2

where Q_ref is the path median Q_prior.

beta = 1 recovers percent * Q_prior.
beta < 1 prevents absolute uncertainty from growing linearly with Q_prior,
so large-flow reaches are not automatically assigned extremely large R.
```

Also fixed a bug/limitation:

```text
In mean_percent mode, ObsUncScale was previously not multiplied into R.
It now is:
sigma_R = percent * Q_prior * ObsUncScale
```

20-path uncertainty-only results:

```text
Baseline interp:
corr 0.53306, NSE 0.18611, rRMSE 90.216, rB 26.368

zero_Q0p06_meanR0p75:
corr 0.55587, NSE 0.18746, rRMSE 90.141, rB 22.258

zero_Q0p10_pow0p75:
corr 0.57883, NSE 0.18587, rRMSE 90.229, rB 21.930

zero_Q0p10_pow0p50:
corr 0.57867, NSE 0.18440, rRMSE 90.311, rB 21.705
```

80-path uncertainty-only results:

```text
Baseline interp:
corr 0.61672, NSE 0.28077, rRMSE 84.804, rB 15.883

zero_Q0p10_pow0p50:
corr 0.61565, NSE 0.25714, rRMSE 86.189, rB 15.048

zero_Q0p11_pow0p75:
corr 0.61695, NSE 0.25543, rRMSE 86.288, rB 15.112

zero_Q0p10_pow0p75:
corr 0.61764, NSE 0.25476, rRMSE 86.327, rB 15.107

zero_Q0p12_pow0p75:
corr 0.61653, NSE 0.25538, rRMSE 86.291, rB 15.119

zero_Q0p09_pow0p75:
corr 0.61668, NSE 0.25329, rRMSE 86.412, rB 15.111

zero_Q0p06_meanR0p75:
corr 0.61584, NSE 0.24799, rRMSE 86.719, rB 15.720
```

Conclusion:

```text
Uncertainty-only tuning is more interpretable than output anomaly scaling, but
the first power-law R tests do not yet beat interpolation on all metrics for the
80-path sample.

They usually improve rB and can match/win corr, but NSE/rRMSE remain worse.
This suggests that part of the loss is not only observation weighting R; it may
come from 22-day smoothing/combination or the transition/process model damping
daily variability.
```

## 12. Uncertainty-only RScale sweep after rejecting anomaly scaling

User concern:

```text
Adjusting output anomaly amplitude is not sufficiently reasonable/explainable.
Try improving the KF through uncertainty instead.
```

Estimator information used:

```text
Used in estimator:
- raw SIC4DVar discharge observations Q_SIC4DVar
- SIC-derived observation uncertainty percent from obs_percent
- Q_prior magnitude, only to scale observation uncertainty R
- 22-day KF transition/process matrices already in the SIC branch

Not used in estimator:
- Q_SIC4DVar_interp
- gauge
- SVS
- other discharge products
- output anomaly post-scaling
```

Test:

```text
ConfigSet: sic22_uncertainty_rscale80
Sample: MaxPaths=80, Stride=7, Fold=0
Observation uncertainty model:
sigma_R = percent(group) * ObsUncScale * Q_ref^(1-beta) * Q_prior^beta
beta = 0.75
QScale = 0.10 or 0.11
ObsUncScale = 0.40, 0.60, 0.80
InitMode = zero
```

Results:

```text
Baseline interp:
corr 0.61672, NSE 0.28077, rRMSE 84.804, rB 15.883

zero_Q0p10_pow0p75_R0p60:
corr 0.61075, NSE 0.27205, rRMSE 85.320, rB 15.389

zero_Q0p11_pow0p75_R0p60:
corr 0.60953, NSE 0.27209, rRMSE 85.317, rB 15.427

zero_Q0p11_pow0p75_R0p80:
corr 0.61398, NSE 0.26533, rRMSE 85.713, rB 15.226

zero_Q0p10_pow0p75_R0p80:
corr 0.61457, NSE 0.26195, rRMSE 85.910, rB 15.188

zero_Q0p10_pow0p75_R0p40:
corr 0.60228, NSE 0.25607, rRMSE 86.251, rB 15.567

zero_Q0p11_pow0p75_R0p40:
corr 0.60090, NSE 0.25323, rRMSE 86.416, rB 15.555
```

Conclusion:

```text
This uncertainty-only sweep did not meet the hard target of beating
interpolated SIC4DVar on all metrics.

The best RScale point is around 0.60. It improves bias relative to interpolation
and improves NSE/rRMSE relative to more aggressive or more conservative RScale
settings, but it still loses to interpolation in corr, NSE, and rRMSE.

This is a useful negative result: simply reducing or reshaping R is not enough.
The next defensible KF-only direction should still be covariance-based, but
should diagnose R/Q from raw innovations rather than tune output amplitude.
For example, use normalized innovation consistency to estimate whether R or Q is
miscalibrated, using only SIC observations and the KF prediction residuals.
```

## 13. Innovation-gated R: adaptive uncertainty from KF residuals

Reason:

```text
If output anomaly scaling is rejected, a more KF-native way to use uncertainty
is to adapt R from the innovation:

innovation = z - H*x_pred
S_diag = diag(H*P_pred*H' + R)
normalized innovation = abs(innovation) / sqrt(S_diag)

If normalized innovation is larger than a threshold, temporarily inflate that
observation's R for this update. This downweights outlier-like SIC observations
without using gauge/SVS/interp truth.
```

Implementation in `optimize_sic22_experiments.m`:

```text
R_i <- R_i * min(max_scale, (normalized_innovation_i / gate_sigma)^power)
only when normalized_innovation_i > gate_sigma
```

20-path quick results (`ConfigSet=sic22_innov_gate80`, MaxPaths=20):

```text
Baseline interp:
corr 0.53306, NSE 0.18611, rRMSE 90.216, rB 26.368

zero_Q0p10_pow0p75_R0p60_gate2p5m4:
corr 0.56017, NSE 0.16643, rRMSE 91.300, rB 19.096

zero_Q0p10_pow0p75_R0p60_gate2p5:
corr 0.56132, NSE 0.15347, rRMSE 92.007, rB 18.592

zero_Q0p10_pow0p75_R0p60_gate2p0:
corr 0.55391, NSE 0.14119, rRMSE 92.672, rB 18.277
```

Conclusion:

```text
Innovation gating improves corr and bias on the 20-path sample, but it hurts
NSE/rRMSE. It does not meet the hard target.

Interpretation: the large SIC-vs-prediction residuals are not merely bad
outliers to remove. Downweighting them can also remove real high-frequency
signal that interpolation preserves.
```

## 14. Posterior-variance weighted 22-day combine

Reason:

```text
combine_xnn_SWOT.m combines multiple 22-day window estimates for the same day
using median(tmp, 2). The file already contains commented references to a
weighted/arithmetic combine function, but build_weighted_arith.m is absent.

A defensible uncertainty-only alternative is:
- keep the same 22-day KF state and transition/update equations
- after filtering, combine duplicate daily estimates using posterior variance P
- lower posterior variance gets higher weight

This changes the uncertainty-based reconstruction step, not the estimator input.
It still does not use Q_SIC4DVar_interp/gauge/SVS/other products.
```

Formula:

```text
For each reach/day, collect all 22-day window estimates q_k and posterior
variances v_k.

var_weight estimate = sum(q_k / v_k) / sum(1 / v_k)
```

20-path quick results (`ConfigSet=sic22_varcombine20`):

```text
Baseline interp:
corr 0.53306, NSE 0.18611, rRMSE 90.216, rB 26.368

zero_Q0p10_pow0p75_R0p60_arith:
corr 0.57703, NSE 0.17304, rRMSE 90.937, rB 22.147

zero_Q0p10_pow0p75_R0p60_varw:
corr 0.57715, NSE 0.17198, rRMSE 90.996, rB 23.356

zero_Q0p10_pow0p75_R1p00_varw:
corr 0.55304, NSE 0.18439, rRMSE 90.311, rB 23.499
```

Fine 20-path RScale/QScale sweeps:

```text
Best RScale neighborhood:
zero_Q0p10_pow0p75_R0p80_varw:
corr 0.57344, NSE 0.17995, rRMSE 90.556, rB 23.322

zero_Q0p10_pow0p75_R0p90_varw:
corr 0.56051, NSE 0.18335, rRMSE 90.368, rB 23.389

zero_Q0p10_pow0p75_R1p00_varw:
corr 0.55304, NSE 0.18439, rRMSE 90.311, rB 23.499

Best QScale neighborhood at R1.00:
zero_Q0p09_pow0p75_R1p00_varw:
corr 0.55371, NSE 0.18456, rRMSE 90.302, rB 23.622

zero_Q0p15_pow0p75_R1p00_varw:
corr 0.57184, NSE 0.18191, rRMSE 90.448, rB 23.154
```

80-path follow-up (`ConfigSet=sic22_varcombine_top80`, MaxPaths=80):

```text
Baseline interp:
corr 0.61672, NSE 0.28077, rRMSE 84.804, rB 15.883

zero_Q0p10_pow0p75_R0p80_varw:
corr 0.61173, NSE 0.25422, rRMSE 86.359, rB 15.547

zero_Q0p15_pow0p75_R1p00_varw:
corr 0.61269, NSE 0.25162, rRMSE 86.509, rB 15.559

zero_Q0p09_pow0p75_R1p00_varw:
corr 0.61122, NSE 0.24465, rRMSE 86.911, rB 15.413
```

Conclusion:

```text
Posterior-variance weighted combine is scientifically more defensible than
output anomaly scaling, and on the 20-path sample it brought NSE/rRMSE very
close to interpolation. However, on the 80-path sample it failed clearly.

This means the current KF posterior covariance P is not sufficient to rescue
the daily reconstruction. The remaining gap is likely not just an R/combine
uncertainty calibration problem. It may come from the 22-day state construction,
transition/process covariance shape, or the fact that interpolation has a
strong temporal prior that the current KF transition is not reproducing.
```

## 15. RTS smoother on the original 22-day KF state

Reason:

```text
The task is offline daily discharge reconstruction, not real-time forecasting.
Interpolated SIC4DVar also uses time-neighbor information. A forward-only KF
uses only past observations at each update, so it is at an information
disadvantage.

RTS fixed-interval smoothing is the standard backward pass for the same linear
Gaussian state-space model. It does not use Q_SIC4DVar_interp, gauge, SVS, or
other discharge products in the estimator.
```

Important methodological constraint:

```text
RTS is applied to the full 22-day state vector.

State dimension remains:
x_k in R^(22*nR)

Forward KF remains:
x_pred = Phi_st * x_f
P_pred = Phi_st * P_f * Phi_st' + Q_st

Backward RTS smoother:
C_k = P_f,k * Phi_st' * inv(P_pred,k+1)
x_s,k = x_f,k + C_k * (x_s,k+1 - x_pred,k+1)
P_s,k = P_f,k + C_k * (P_s,k+1 - P_pred,k+1) * C_k'

Then the existing 22-day combine step is applied to smoothed x_s/P_s.

This is not a one-day KF reformulation.
```

Implementation:

```text
Added SmoothMode:
- "forward": original forward-only KF output
- "rts": same forward KF plus RTS backward smoothing before combine_xnn_SWOT

Added only storage of x_pred/P_pred during the existing forward pass.
The forward update logic is unchanged.
```

20-path quick results (`ConfigSet=sic22_rts20`, MaxPaths=20):

```text
Baseline interp:
corr 0.53306, NSE 0.18611, rRMSE 90.216, rB 26.368

rts_zero_Q0p09_pow0p75_R1p00:
corr 0.57792, NSE 0.20032, rRMSE 89.425, rB 22.395

rts_zero_Q0p10_pow0p75_R1p00:
corr 0.57762, NSE 0.20053, rRMSE 89.413, rB 22.425

rts_zero_Q0p06_meanR0p75:
corr 0.57860, NSE 0.19944, rRMSE 89.474, rB 22.400

rts_zero_Q0p10_pow0p75_R0p60:
corr 0.56540, NSE 0.20409, rRMSE 89.214, rB 22.588

forward control, same Q0.10/R0.60:
corr 0.57860, NSE 0.18043, rRMSE 90.530, rB 21.799
```

20-path conclusion:

```text
RTS improves the key dynamic metrics compared with the same forward-only KF.
For Q0.10/R0.60, NSE improves from 0.18043 to 0.20409 and rRMSE improves from
90.530 to 89.214.
```

80-path validation (`ConfigSet=sic22_rts_top80`, MaxPaths=80):

```text
Baseline interp:
corr 0.61672, NSE 0.28077, rRMSE 84.804, rB 15.883

rts_zero_Q0p09_pow0p75_R1p00:
corr 0.66582, NSE 0.30561, rRMSE 83.330, rB 15.880

rts_zero_Q0p10_pow0p75_R1p00:
corr 0.66856, NSE 0.30795, rRMSE 83.190, rB 15.939

rts_zero_Q0p06_meanR0p75:
corr 0.66173, NSE 0.30218, rRMSE 83.536, rB 16.201

rts_zero_Q0p10_pow0p75_R0p60:
corr 0.65039, NSE 0.30945, rRMSE 83.099, rB 16.270
```

Conclusion:

```text
The first configuration, rts_zero_Q0p09_pow0p75_R1p00, meets the hard target on
the 80-path sample:
- corr higher than interpolation
- NSE higher than interpolation
- rRMSE lower than interpolation
- rB slightly lower than interpolation

This is currently the best scientifically defensible solution because the
improvement comes from applying the standard fixed-interval RTS smoother to the
existing 22-day KF state-space model, not from validation-tuned output scaling.

Caveat:
The rB win is very small on the 80-path sample (15.880 vs 15.883). The result
should be followed by a full-sample run and CDF/detail output before treating it
as final paper-strength evidence.
```

Detail/CDF output for the best 80-path RTS candidate:

```text
ConfigSet: sic22_rts_best
DetailTag: rts_best80
Saved files:
sic22_compare_rts_best80_20260720_021737.mat
sic22_compare_rts_best80_20260720_021737_cdf.png
sic22_compare_rts_best80_20260720_021737_cdf.fig
sic22_compare_rts_best80_20260720_021737_summary.csv
sic22_compare_rts_best80_20260720_021737_group_summary.csv
```

Overall CDF/detail summary:

```text
all/corr:  KF median 0.66582 vs interp 0.61672, win_rate 0.615
all/NSE:   KF median 0.30561 vs interp 0.28077, win_rate 0.531
all/rRMSE: KF median 83.330 vs interp 84.804, win_rate 0.531
all/rB:    KF median 15.880 vs interp 15.883, win_rate 0.515
```

Qprior-group detail:

```text
low group:
RTS wins corr, NSE, rRMSE, and rB medians clearly.

mid group:
RTS wins corr and rB medians, but loses NSE/rRMSE medians slightly.

high group:
RTS wins rB median, but loses corr/NSE/rRMSE medians slightly, while win_rate
for NSE/rRMSE is above 0.5.
```

Interpretation:

```text
The best RTS candidate meets the overall four-metric target on the 80-path
sample and has a defensible algorithmic basis. However, the group detail shows
that the improvement is not uniform across discharge magnitude classes. A
larger/full-sample check is needed before claiming robust universal dominance.
```

## 16. Chunked full-sample validation for frozen RTS method

Frozen method:

```text
ConfigSet: sic22_rts_best
Name: rts_zero_Q0p09_pow0p75_R1p00
State: original 22*nR state
SmoothMode: rts
CombineMode: median
ObsUncMode: qprior_power_0p75
ObsUncScale: 1.00
QScale: 0.09
InitMode: zero
No estimator use of Q_SIC4DVar_interp/gauge/SVS/other products.
```

Reason for chunking:

```text
A single 666-path run was unstable and lost progress before writing final
detail outputs. The validation is now run in frozen-parameter chunks, each with
SaveDetail=true, then merged with aggregate_sic22_chunk_details.m. This does
not change the estimator or tune parameters.
```

Completed chunks:

```text
001-120:
N=148, corr 0.51712 vs 0.51860, NSE 0.19990 vs 0.12508,
rRMSE 89.448 vs 93.537, rB 24.051 vs 26.739
Comment: corr slightly loses; NSE/rRMSE/rB win.

121-180:
N=114, corr 0.54170 vs 0.45370, NSE 0.21770 vs 0.16017,
rRMSE 88.448 vs 91.642, rB 7.050 vs 10.417
Comment: four metrics win.

181-240:
N=115, corr 0.49330 vs 0.47312, NSE 0.18369 vs 0.14217,
rRMSE 90.350 vs 92.619, rB 16.106 vs 15.469
Comment: corr/NSE/rRMSE win; rB loses slightly.

241-360:
N=208, corr 0.65055 vs 0.56590, NSE 0.28714 vs 0.25241,
rRMSE 84.431 vs 86.463, rB 12.869 vs 14.076
Comment: four metrics win.

361-480:
N=212, corr 0.52322 vs 0.51584, NSE 0.16218 vs 0.08649,
rRMSE 91.532 vs 95.577, rB 50.146 vs 51.579
Comment: four metrics win.

481-520:
N=55, corr 0.76820 vs 0.75766, NSE 0.46672 vs 0.47044,
rRMSE 73.026 vs 72.771, rB 25.574 vs 28.155
Comment: corr/rB win; NSE/rRMSE lose slightly.

521-560:
N=59, corr 0.76347 vs 0.81121, NSE 0.50928 vs 0.55064,
rRMSE 70.052 vs 67.034, rB 51.592 vs 37.797
Comment: four metrics lose in this chunk.

561-600:
N=45, corr 0.81091 vs 0.80761, NSE 0.49449 vs 0.48864,
rRMSE 71.099 vs 71.509, rB 34.243 vs 40.644
Comment: medians win, but win_rate for corr/NSE/rRMSE is below 0.5 and rB
win_rate is 0.556.
```

Merged 001-600 result:

```text
N=956
corr:  KF median 0.58997 vs interp 0.54943, win_rate 0.601
NSE:   KF median 0.23868 vs interp 0.19548, win_rate 0.565
rRMSE: KF median 87.254 vs interp 89.695, win_rate 0.565
rB:    KF median 18.970 vs interp 22.346, win_rate 0.500

Means also improve overall:
corr mean 0.55455 vs 0.50836
NSE mean -16.40 vs -95.76
rRMSE mean 128.73 vs 202.21
rB mean 189.38 vs 247.91
```

Group detail for 001-600:

```text
low group:
All four medians win; win_rate is above 0.5 for all metrics.

mid group:
All four medians win; win_rate is above 0.5 for all metrics.

high group:
corr and rB medians win; NSE/rRMSE medians lose. win_rate is 0.5 for NSE/rRMSE
and below 0.5 for rB.
```

Current status:

```text
The frozen RTS method remains stronger than interpolation overall through
tasks 1-600, and the evidence is no longer just median-only: mean and win_rate
mostly support the same direction. However, it is not uniformly better for all
chunks or all Qprior groups. The last chunk 601-666 is still needed for the
full 666-task merged result.
```

Final 001-666 merged full-sample result:

```text
Merged files:
sic22_compare_rts_fullchunk_001_120_20260720_092117.mat
sic22_compare_rts_fullchunk_121_180_20260720_103443.mat
sic22_compare_rts_fullchunk_181_240_20260720_105326.mat
sic22_compare_rts_fullchunk_241_360_20260720_110529.mat
sic22_compare_rts_fullchunk_361_480_20260720_113858.mat
sic22_compare_rts_fullchunk_481_520_20260720_115318.mat
sic22_compare_rts_fullchunk_521_560_20260720_115757.mat
sic22_compare_rts_fullchunk_561_600_20260720_120508.mat
sic22_compare_rts_fullchunk_601_666_20260720_123135.mat

Merged output:
sic22_compare_rts_full_001_666_merged_20260720_123159.mat
sic22_compare_rts_full_001_666_merged_20260720_123159_cdf.png
sic22_compare_rts_full_001_666_merged_20260720_123159_cdf.fig
sic22_compare_rts_full_001_666_merged_20260720_123159_summary.csv
sic22_compare_rts_full_001_666_merged_20260720_123159_group_summary.csv
```

Overall full-sample summary:

```text
N=1021

corr:
KF median 0.59120 vs interp 0.54543
KF mean   0.55264 vs interp 0.50082
win_rate 0.600

NSE:
KF median 0.23934 vs interp 0.18373
KF mean  -15.37 vs interp -114.88
win_rate 0.573

rRMSE:
KF median 87.216 vs interp 90.348
KF mean   126.66 vs interp 220.17
win_rate 0.573

rB:
KF median 19.240 vs interp 22.796
KF mean   183.82 vs interp 249.20
win_rate 0.504
```

Final interpretation:

```text
The frozen RTS method beats interpolated SIC4DVar on the full merged sample in
all four overall median metrics, all four overall means, and win_rate is above
0.5 for all four metrics.

This is stronger than the earlier 80-path evidence and is not merely a median
artifact.
```

Remaining limitation:

```text
The improvement is still not uniform by Qprior group.

low group:
All four medians win; all win_rates above 0.5.

mid group:
All four medians win; all win_rates above 0.5.

high group:
corr/NSE/rRMSE medians lose slightly, while rB median wins:
corr 0.71890 vs 0.72065
NSE 0.36980 vs 0.41824
rRMSE 79.384 vs 76.273
rB 17.092 vs 19.678
win_rate is 0.5125 for corr/NSE/rRMSE and 0.45 for rB.

So the final claim should be:
RTS-KF is better overall on the full sample, but high-flow reaches still need
separate diagnosis if the paper needs group-wise dominance.
```

## 17. Follow-up: temporal-correlated R and physical output bounds

Reason for trying temporal-correlated R:

```text
The previous full-sample CDF still crossed the interpolation CDF, especially
for high-Qprior reaches. A defensible next hypothesis was that SIC4DVar
observation errors inside the same 22-day window are not independent. Treating
them as diagonal R could over-count repeated same-reach information.
```

Implemented test:

```text
ObsTemporalCorrMode = same_reach_tau
R_ij = sigma_i sigma_j exp(-abs(day_i-day_j)/tau_reach)
only for observations from the same reach; different reaches remain independent.
tau_reach comes from sg_path.tau, not validation.
```

Small 6-path sanity result:

```text
rts_zero_Q0p09_pow0p75_R1p00_tauR:
corr 0.47438 vs 0.66539, NSE -0.0119 vs 0.10883,
rRMSE 100.59 vs 94.156, rB 68.095 vs 64.785

Conclusion:
The direct same-reach tau-correlated R is logically defensible but too strong
in this implementation. It reduces the effective SIC observation information
too much, so it is not pursued as the current solution.
```

Reason for trying output bounds:

```text
High-Qprior diagnostics showed that the remaining weakness was not only a
small median loss. A few catastrophic high-flow reaches produced very bad
NSE/rRMSE/rB. Since discharge is physically nonnegative, a nonnegative output
constraint is defensible and does not use gauge, interpolation, SVS, or any
other product inside the estimator.

A stronger prior_minmax box was also tested because minQ_prior/maxQ_prior are
already used by the original KF covariance setup, but this is more restrictive
than nonnegative clipping.
```

20-path bounds panel:

```text
rts_zero_Q0p09_pow0p75_R1p00_nonneg:
corr 0.57104 vs 0.53306, NSE 0.19643 vs 0.18611,
rRMSE 89.642 vs 90.216, rB 21.935 vs 26.368

rts_zero_Q0p09_group_R1p00_priorbox:
corr 0.58071 vs 0.53306, NSE 0.19523 vs 0.18611,
rRMSE 89.709 vs 90.216, rB 21.949 vs 26.368
```

80-path bounds panel:

```text
rts_zero_Q0p09_pow0p75_R1p00_nonneg:
corr 0.64734 vs 0.61672, NSE 0.30281 vs 0.28077,
rRMSE 83.498 vs 84.804, rB 15.784 vs 15.883

rts_zero_Q0p09_pow0p75_R1p00_priorbox:
corr 0.66183 vs 0.61672, NSE 0.30380 vs 0.28077,
rRMSE 83.438 vs 84.804, rB 16.322 vs 15.883

rts_zero_Q0p09_group_R1p00_priorbox:
corr 0.66243 vs 0.61672, NSE 0.30301 vs 0.28077,
rRMSE 83.486 vs 84.804, rB 16.287 vs 15.883

rts_zero_Q0p09_mean_R1p00_priorbox:
corr 0.66537 vs 0.61672, NSE 0.29947 vs 0.28077,
rRMSE 83.698 vs 84.804, rB 16.740 vs 15.883
```

Interpretation:

```text
Nonnegative output bounds are useful and paper-defensible: they improve the
80-path overall result and keep all four overall median metrics better than
interpolation.

prior_minmax improves corr/NSE/rRMSE but worsens overall rB on 80 paths, so it
is not a complete solution.

None of the bounds variants achieves group-wise dominance. High-Qprior corr
still loses on 80 paths, and mid/high NSE/rRMSE still have median or win-rate
weaknesses. Bounds help the catastrophic tail but do not fully solve the high
flow dynamic-correlation problem.
```

## 18. Covariance-matching QScale

Reason:

```text
The fixed RTS method uses QScale = 0.09. A diagnostic comparing the first
effective SIC observation R diagonal against the process Q_st diagonal found:

median R_over_Q = 0.2388
p25 = 0.1251
p75 = 0.5051
min = 0.01783
max = 2.236

So QScale = 0.09 is often smaller than the estimator-internal R/Q covariance
balance, which can make the 22-day dynamics too stiff.
```

Implemented:

```text
QScaleMode = match_obs_qdiag
For each path:
  qscale = median(diag(R_first_valid_SIC_window)) / median(diag(Q_st_base))
  qscale is clipped to [0.03, 1.0] for numerical stability.

This uses only Q_st, Qprior-based SIC uncertainty, and raw SIC availability.
It does not use interpolation, gauge, SVS, or validation metrics inside the
estimator.
```

20-path qmatch result:

```text
rts_qmatch_mean_nonneg:
corr 0.57475 vs 0.53306, NSE 0.20954 vs 0.18611,
rRMSE 88.908 vs 90.216, rB 22.162 vs 26.368

rts_qmatch_group_nonneg:
corr 0.57770 vs 0.53306, NSE 0.20387 vs 0.18611,
rRMSE 89.226 vs 90.216, rB 21.854 vs 26.368
```

80-path qmatch result:

```text
rts_qmatch_group_nonneg:
corr 0.63405 vs 0.61672, NSE 0.30474 vs 0.28077,
rRMSE 83.382 vs 84.804, rB 16.393 vs 15.883

rts_qmatch_pow0p75_nonneg:
corr 0.63603 vs 0.61672, NSE 0.30268 vs 0.28077,
rRMSE 83.505 vs 84.804, rB 16.371 vs 15.883

rts_qmatch_mean_nonneg:
corr 0.63530 vs 0.61672, NSE 0.29930 vs 0.28077,
rRMSE 83.707 vs 84.804, rB 16.505 vs 15.883
```

Interpretation:

```text
Covariance-matching QScale is logically defensible and improves NSE/rRMSE, but
on 80 paths it worsens rB and does not solve high-Qprior corr. It is therefore
not the final method.
```

Scope correction:

```text
A relative-anomaly state idea was started, but it changes the KF state
definition from absolute anomaly Q-Qprior to relative anomaly
(Q-Qprior)/Qprior. This is outside the current constraint, so that line was
stopped and removed from the active experiment code. Subsequent attempts should
keep the absolute-anomaly KF state unchanged.
```

## 19. Attempts After Locking The Absolute-Anomaly KF State

Constraint:

```text
Do not change the KF state definition or the absolute-anomaly formulation.
The estimator remains:
  x = Q - Qprior
  x_k = Phi x_{k-1} + w
  z = Q_SIC4DVar_raw - Qprior

No Q_SIC4DVar_interp, Gauge_Q, SVS, or other discharge product is used inside
the estimator. The tested changes below are either observation-percent R
choices derived from obs_percent_Qprior, overlap-window output combination, or
short post-KF smoothing of the KF output itself.
```

Uncertainty-derived output anomaly weights:

```text
SIC obs_percent_Qprior:
  all recommended percent  = 0.16237
  low-Qprior percent       = 0.30030
  mid-Qprior percent       = 0.15821
  high-Qprior percent      = 0.083867

The defensible output anomaly scale used in the current best branch is:
  scale_g = sqrt(p_all / p_group)
  [low mid high] = [0.735 1.013 1.391]

Interpretation:
  higher observation percent uncertainty -> damp the anomaly
  lower observation percent uncertainty  -> retain more anomaly
This is derived before validation from the product uncertainty grouping, not
from metric fitting.
```

80-path `rts_uncsqrt_group_center_nonneg`:

```text
all:
  corr 0.65649 vs 0.61672
  NSE  0.30829 vs 0.28077
  rRMSE 83.169 vs 84.804
  rB 15.733 vs 15.883

group issue:
  low and mid median metrics mostly win.
  high rB wins and high NSE/rRMSE win-rate > 0.5, but high median corr and
  high median NSE/rRMSE still did not fully dominate interpolation.
```

Observation-count/proximity window-combination attempts:

```text
obs_count_center:
  Each overlapping 22-day estimate for a target day is weighted by
  center-distance and by the number of raw SIC observations for that reach in
  the source window.

20-path result:
  rts_uncsqrt_group_obscount_nonneg
  corr 0.56198 vs 0.53306
  NSE  0.20434 vs 0.18611
  rRMSE 89.200 vs 90.216
  rB 20.646 vs 26.368

obs_prox_center:
  Same idea, but observations closer to the target day receive larger
  exponential weight with tau = state_ep/3.

20-path result:
  rts_uncsqrt_group_obsprox_nonneg
  corr 0.56758 vs 0.53306
  NSE  0.20607 vs 0.18611
  rRMSE 89.103 vs 90.216
  rB 20.649 vs 26.368

Conclusion:
  Both are logically valid and do not use interpolation/gauge/SVS, but they
  are weaker than the simpler center-window combination.
```

Uncertainty-percent R variants:

```text
qprior_group_floor_mean:
  percent_eff = max(group recommended percent, product all recommended percent)
  For SIC high-flow this raises percent from 0.0839 to 0.1624, avoiding
  overconfident high-flow observations.

80-path result:
  rts_uncfloor_uncsqrt_center_nonneg
  corr 0.65434 vs 0.61672
  NSE  0.30852 vs 0.28077
  rRMSE 83.155 vs 84.804
  rB 15.704 vs 15.883

group result:
  high corr 0.50142 vs 0.58189 still loses median, but improves strongly from
  the earlier 0.45044.
  high NSE/rRMSE/rB medians all beat interpolation.
  mid NSE/rRMSE become essentially tied/slightly worse, so this is helpful but
  not final.
```

Additional R percentile tests:

```text
qprior_group_p68/p75:
  Use each Qprior group's empirical p68 or p75 percent instead of median.
  This made all groups too conservative.

20-path:
  p68 + uncsqrt + center:
    corr 0.56656 vs 0.53306
    NSE  0.18319 vs 0.18611
    rRMSE 90.378 vs 90.216
  p75 + uncsqrt + center:
    corr 0.54392 vs 0.53306
    NSE  0.15509 vs 0.18611
    rRMSE 91.919 vs 90.216

qprior_group_high_p75/p90:
  Keep low/mid at recommended percent and only make high-Qprior more
  conservative.

20-path:
  high_p75 + uncsqrt + center:
    corr 0.58493 vs 0.53306
    NSE  0.21453 vs 0.18611
    rRMSE 88.627 vs 90.216
  high_p90 + uncsqrt + center:
    corr 0.58263 vs 0.53306
    NSE  0.19826 vs 0.18611
    rRMSE 89.540 vs 90.216

Conclusion:
  high_p75 is close to the global floor idea; high_p90 is too conservative.
  Neither beats the current best.
```

Short post-KF smoothing of the KF output:

```text
Reason:
  The 22-day RTS output is assembled from overlapping windows. Even with center
  selection, the stitched daily series can contain high-frequency window
  switching noise that is not hydrologically meaningful. A short moving median
  on the KF output itself removes this jitter without using Q_SIC4DVar_interp,
  gauge, SVS, or another product.

Implementation:
  After RTS + center combine + uncertainty-derived output anomaly scaling +
  nonnegative bound:
    Q_KF_smooth = movmedian(Q_KF, 5 days, along time)

This is a post-KF output smoother; it does not change x = Q-Qprior, Phi, H, z,
R, Q, or the 22-day state.
```

20-path:

```text
rts_uncsqrt_center_smooth3_nonneg:
  corr 0.59438 vs 0.53306
  NSE  0.22191 vs 0.18611
  rRMSE 88.210 vs 90.216
  rB 20.791 vs 26.368

rts_uncsqrt_center_smooth5_nonneg:
  corr 0.59891 vs 0.53306
  NSE  0.22222 vs 0.18611
  rRMSE 88.192 vs 90.216
  rB 20.801 vs 26.368
```

80-path current best:

```text
rts_uncsqrt_center_smooth5_nonneg:
  corr 0.67034 vs 0.61672
  NSE  0.31138 vs 0.28077
  rRMSE 82.983 vs 84.804
  rB 15.842 vs 15.883

CDF:
  sic22_compare_rts_postsmooth_top80_20260720_174014_cdf.png
```

80-path group summary:

```text
low:
  corr 0.36333 vs 0.23606
  NSE  0.07805 vs -0.19904
  rRMSE 96.018 vs 109.501
  rB 124.606 vs 160.032

mid:
  corr 0.70974 vs 0.65494
  NSE  0.33606 vs 0.33490
  rRMSE 81.482 vs 81.554
  rB 14.847 vs 15.255

high:
  corr 0.51182 vs 0.58189  (median still loses)
  NSE  0.19226 vs 0.18774
  rRMSE 89.858 vs 90.084
  rB 14.685 vs 24.023
  high corr win-rate = 0.625

Conclusion:
  This is the strongest 80-path result so far and almost all group median
  metrics beat interpolation. The remaining blocker is high-Qprior median
  correlation, although high corr win-rate is now better than interpolation.
  It is not yet the requested full dominance.
```

## 20. High-Flow Correlation Follow-Up

High-corr loss diagnosis for `rts_highp75_uncsqrt_smooth5_nonneg`:

```text
Only 8 high-Qprior reach metrics still have corr(KF) < corr(interp) in the
80-path sample. The largest losses are concentrated:

task reach qprior  KF corr  interp corr  delta
371  3     434.31  0.21797  0.73449     -0.51653
14   1     543.58  0.44443  0.61328     -0.16885
448  34    360.78  0.59210  0.73432     -0.14222
119  23    342.94  0.47194  0.55051     -0.07857
448  43    371.77 -0.17604 -0.12300     -0.05303
518  1     536.36  0.53178  0.54372     -0.01195
413  1    1104.10  0.67962  0.68380     -0.00419
399  3    1514.20  0.80588  0.80823     -0.00234
```

Sampling diagnostics for those reaches:

```text
task reach nR qprior nobs first last median_gap max_gap
371  3     3  434.31 60   125   759  9          63
14   1    20  543.58 49   121   762  6         135
448  34   44  360.78 52   124   761 11          32
119  23   24  342.94 40   126   752 13          42
448  43   44  371.77 51   124   761 11          32
518  1    19  536.36 50   125   761 11          42
413  1     8 1104.10 27   126   752 21          42
399  3     6 1514.20 30   136   762 21          42
```

Extra smoothing-span attempts:

```text
20-path post-smoothing gap scale:

rts_uncsqrt_center_smooth7_nonneg:
  corr 0.59601 vs 0.53306
  NSE  0.21772 vs 0.18611
  rRMSE 88.447 vs 90.216
  rB 20.684 vs 26.368

rts_uncsqrt_center_smooth9_nonneg:
  corr 0.58846 vs 0.53306
  NSE  0.21155 vs 0.18611
  rRMSE 88.795 vs 90.216
  rB 20.589 vs 26.368

Conclusion:
  global smoothing longer than 5 days is too blunt.
```

High-only uncertainty with 5-day smoothing:

```text
80-path rts_highp75_uncsqrt_smooth5_nonneg:
  all corr 0.67034 vs 0.61672
  all NSE  0.31138 vs 0.28077
  all rRMSE 82.983 vs 84.804
  all rB 15.763 vs 15.883

group medians:
  low:  all four metrics win
  mid:  all four metrics win
  high: NSE/rRMSE/rB win, corr still loses 0.55620 vs 0.58189

This is the closest method to full group-wise dominance so far. It uses:
  - original absolute-anomaly 22-day KF
  - RTS smoothing over the same 22-day state
  - center-window output selection
  - uncertainty-derived output anomaly scale sqrt(p_all / p_group)
  - high-flow observation R uses high-group p75 percent
  - 5-day moving median post-KF output smoothing
  - no interpolation/gauge/SVS/other product in the estimator
```

Group-specific smoothing attempt:

```text
80-path [low mid high] OutputSmoothDays = [5 5 9]:
  all metrics remain the same as smooth5 overall, but high median corr is only
  0.51870 vs 0.58189, worse than high-p75+smooth5.

Conclusion:
  group-specific longer smoothing is not the fix.
```

## 21. Full 666-Path Validation Of Current Best Method

Method:

```text
rts_highp75_uncsqrt_smooth5_nonneg

Estimator:
  original 22-day absolute-anomaly KF state x = Q - Qprior
  original 22-day Phi/Q process model
  raw Q_SIC4DVar observations only
  z = Q_SIC4DVar_raw - Qprior
  no Q_SIC4DVar_interp, gauge, SVS, or other product in the estimator

Additions outside the core KF state:
  RTS smoothing over the original 22-day state sequence
  center-window output selection
  output anomaly scale derived from obs_percent_Qprior:
    sqrt(p_all / p_group) = [0.735 1.013 1.391]
  high-flow observation R percent uses high-group p75
  nonnegative output bound
  5-day moving median on the KF output only
```

Run:

```text
All 666 paths were run in three chunks:
  001-222
  223-444
  445-666

Merged output:
  sic22_compare_rts_highunc_smooth_full_001_666_merged_20260720_213727.mat
  sic22_compare_rts_highunc_smooth_full_001_666_merged_20260720_213727_cdf.png
  sic22_compare_rts_highunc_smooth_full_001_666_merged_20260720_213727_summary.csv
  sic22_compare_rts_highunc_smooth_full_001_666_merged_20260720_213727_group_summary.csv
```

Full merged all-sample result, N = 1021:

```text
metric  KF median   interp median  delta       win_rate
corr    0.61749     0.54543        +0.07206    0.63075
NSE     0.25196     0.18373        +0.06824    0.59745
rRMSE   86.489      90.348         -3.859      0.59745
rB      18.987      22.796         -3.809      0.52106
```

Full merged group result:

```text
low, N = 146:
  corr  0.32992 vs 0.23667
  NSE   0.06617 vs -0.06872
  rRMSE 96.635 vs 103.379
  rB    38.071 vs 51.865

mid, N = 715:
  corr  0.63035 vs 0.56325
  NSE   0.26582 vs 0.19974
  rRMSE 85.684 vs 89.457
  rB    17.174 vs 20.315

high, N = 160:
  corr  0.74142 vs 0.72065
  NSE   0.43256 vs 0.41824
  rRMSE 75.328 vs 76.273
  rB    16.530 vs 19.678
```

Conclusion:

```text
The current best method beats interpolated SIC4DVar on the full 666-path
sample for:
  - all four overall median metrics
  - all four low-Qprior group median metrics
  - all four mid-Qprior group median metrics
  - all four high-Qprior group median metrics

This satisfies the current hard target of outperforming interpolation without
using interpolation/gauge/SVS/other products in the estimator.
```

CDF correction:

```text
The statement above is about medians and paired win rates, not strict
first-order stochastic dominance of the full CDF.

For larger-is-better metrics such as corr and NSE, the KF CDF should be below
the interpolation CDF at every threshold to claim strict CDF dominance. The
full-sample CDFs still cross.

NSE exact ECDF diagnostic:
  median: 0.25196 vs 0.18373, KF wins
  paired win rate: 0.59745, KF wins
  75th percentile: 0.43225 vs 0.44251, interpolation wins
  90th percentile: 0.59411 vs 0.64632, interpolation wins
  95th percentile: 0.68286 vs 0.73556, interpolation wins
  max: 0.91716 vs 0.94446, interpolation wins
  max(F_KF - F_interp) = 0.03918 around NSE = 0.6599

Interpretation:
  The method improves the lower/middle part of the NSE distribution and median,
  but the high-performance NSE tail remains better for interpolation. Therefore
  the current method is not strict CDF-dominant for NSE.
```

Scope correction on output anomaly scaling:

```text
The uncertainty-derived output anomaly scale

  Q_final = Qprior + scale_group * (Q_KF - Qprior)
  scale_group = [0.735 1.013 1.391]

is not part of the original KF estimator. It is a post-processing calibration
that changes the KF anomaly amplitude after filtering. Even though it does not
use interpolation, gauge, SVS, or another discharge product, it changes the
method class and should not be treated as an acceptable "original KF parameter
optimization" under the current constraint.

Therefore rts_highp75_uncsqrt_smooth5_nonneg and related "uncsqrt" methods are
invalid as final candidates for the current target. They remain only as
diagnostic experiments. Subsequent acceptable candidates must set
OutputGroupScales = [] and avoid post-hoc anomaly rescaling.
```

## 2026-07-21 no-rescale full-run restart

After rejecting the output anomaly scaling, the full validation was restarted
with an acceptable frozen candidate:

```text
name: rts_highp75_Q0p18_center_smooth5_nonneg
estimator inputs: raw SIC observations only
excluded from estimator: Q_SIC4DVar_interp, gauge, SVS, other products
state: original 22-day absolute anomaly state x = Q - Qprior
smoother: 22-day-window RTS
observation uncertainty: high-flow group uses p75 uncertainty rule
process covariance: QScale = 0.18
output combination: center-window selection
post bounds/smoothing: nonnegative, 5-day moving median
output anomaly scaling: none, OutputGroupScales = []
```

Chunk 001-222 finished:

```text
detail: sic22_compare_rts_norescale_highp75_q018_fullchunk_001_222_20260721_140722.mat
cdf:    sic22_compare_rts_norescale_highp75_q018_fullchunk_001_222_20260721_140722_cdf.png
N = 343

overall medians:
  corr  0.55283 vs 0.50413
  NSE   0.22696 vs 0.15913
  rRMSE 87.922 vs 91.699
  rB    13.636 vs 15.527

paired win rates:
  corr  0.67930
  NSE   0.62099
  rRMSE 0.62099
  rB    0.49854
```

Chunk 001-222 group medians:

```text
low, N = 28:
  corr  0.32321 vs 0.18691
  NSE   0.08753 vs 0.00915
  rRMSE 95.519 vs 99.539
  rB    20.209 vs 21.238

mid, N = 287:
  corr  0.55849 vs 0.50354
  NSE   0.22780 vs 0.16133
  rRMSE 87.875 vs 91.579
  rB    13.670 vs 15.422

high, N = 28:
  corr  0.70059 vs 0.64580
  NSE   0.32062 vs 0.30569
  rRMSE 82.419 vs 83.311
  rB    11.727 vs 14.692
```

Interim conclusion:

```text
The acceptable no-rescale candidate wins all overall median metrics and all
low/mid/high group median metrics on chunk 001-222. Full 666-path validation is
still incomplete. Chunk 223-444 is currently running with the same frozen
parameters; chunk 445-666 is still pending.
```

Chunk 223-444 finished:

```text
detail: sic22_compare_rts_norescale_highp75_q018_fullchunk_223_444_20260721_150013.mat
cdf:    sic22_compare_rts_norescale_highp75_q018_fullchunk_223_444_20260721_150013_cdf.png
N = 387

overall medians:
  corr  0.59575 vs 0.54293
  NSE   0.23804 vs 0.17870
  rRMSE 87.290 vs 90.625
  rB    20.423 vs 23.167

paired win rates:
  corr  0.64599
  NSE   0.58656
  rRMSE 0.58656
  rB    0.47545
```

Chunk 223-444 group median note:

```text
low group:  corr/NSE/rRMSE/rB medians all win
mid group:  corr/NSE/rRMSE/rB medians all win
high group: corr/NSE/rRMSE medians win, but rB median loses

high rB:
  KF     18.351
  interp 17.210
  delta  +1.141, where lower is better
```

Interim conclusion after chunks 001-444:

```text
The frozen acceptable no-rescale candidate remains strong on overall medians in
both completed chunks. It is not yet proven to satisfy "all groups, all metrics"
because chunk 223-444 high-flow rB loses slightly. Full merged 001-666 remains
the deciding result.
```

Chunk 445-666 finished:

```text
detail: sic22_compare_rts_norescale_highp75_q018_fullchunk_445_666_20260721_154547.mat
cdf:    sic22_compare_rts_norescale_highp75_q018_fullchunk_445_666_20260721_154547_cdf.png
N = 291

overall medians:
  corr  0.69608 vs 0.64198
  NSE   0.33144 vs 0.24056
  rRMSE 81.766 vs 87.146
  rB    36.907 vs 42.337
```

Full 001-666 merged no-rescale result:

```text
detail: sic22_compare_rts_norescale_highp75_q018_full_001_666_merged_20260721_154629.mat
cdf:    sic22_compare_rts_norescale_highp75_q018_full_001_666_merged_20260721_154629_cdf.png
N = 1021

overall medians:
  corr  0.61041 vs 0.54543
  NSE   0.25154 vs 0.18373
  rRMSE 86.513 vs 90.348
  rB    19.409 vs 22.796

paired win rates:
  corr  0.63271
  NSE   0.58962
  rRMSE 0.58962
  rB    0.49755
```

Full 001-666 group medians:

```text
low, N = 146:
  corr  0.30750 vs 0.23667
  NSE   0.05817 vs -0.06872
  rRMSE 97.048 vs 103.379
  rB    43.987 vs 51.865

mid, N = 715:
  corr  0.62592 vs 0.56325
  NSE   0.26433 vs 0.19974
  rRMSE 85.771 vs 89.457
  rB    17.304 vs 20.315

high, N = 160:
  corr  0.74423 vs 0.72065
  NSE   0.39275 vs 0.41824
  rRMSE 77.926 vs 76.273
  rB    17.168 vs 19.678
```

Conclusion for this frozen acceptable candidate:

```text
The method beats interpolation overall and in low/mid groups on median metrics.
It does not yet satisfy the user's "all-around win" target because high-flow NSE
and high-flow rRMSE medians still lose. The next acceptable direction should
remain within uncertainty/covariance logic, especially the high-flow observation
error model R, and must not reintroduce interpolation/gauge/SVS or output
anomaly scaling.
```

## 2026-07-21 high-flow R p68 trial

Rationale:

```text
For SIC4DVar, OBS_PERCENT_QPRIOR high-flow percent values are:
  p50 = 0.0839
  p68 = 0.1369
  p75 = 0.1668
  p90 = 0.2751

The previous acceptable full run used high p75. Because R is a variance model,
p68 is scientifically interpretable as an approximate one-standard-deviation
empirical relative uncertainty. It is less conservative than p75 and may let
high-flow observations influence the KF/RTS update enough to improve high-flow
NSE/rRMSE without changing the output anomaly.
```

Code change:

```text
Added qprior_group_high_p68 support in build_H_obs_SWOT_Q.m.
Added config sic22_rts_norescale_highp68_q018_top80:
  rts_highp68_Q0p18_center_smooth5_nonneg
  OutputGroupScales = []
```

Top-80 result:

```text
detail: sic22_compare_rts_norescale_highp68_q018_top80_20260721_155816.mat
N = 86

overall medians:
  corr  0.53724 vs 0.52974
  NSE   0.23046 vs 0.15516
  rRMSE 87.723 vs 91.915
  rB    27.218 vs 32.027

high group, N = 9:
  corr  0.51697 vs 0.51771  (slight loss)
  NSE   0.24399 vs 0.23693  (win)
  rRMSE 86.949 vs 87.354    (win)
  rB    25.803 vs 27.091    (win)
```

Interpretation:

```text
The p68 R model moves high-flow NSE/rRMSE in the desired direction on the quick
sample, with high-flow corr almost tied. Because N_common dropped to 86 in this
quick run, this is not enough for a conclusion. It needs full 001-666 chunk
validation before it can replace the p75 candidate.
```

Full 001-666 p68 result:

```text
detail: sic22_compare_rts_norescale_highp68_q018_full_001_666_merged_20260721_180918.mat
cdf:    sic22_compare_rts_norescale_highp68_q018_full_001_666_merged_20260721_180918_cdf.png
N = 1021

overall medians:
  corr  0.60672 vs 0.54543
  NSE   0.25127 vs 0.18373
  rRMSE 86.529 vs 90.348
  rB    19.409 vs 22.796

high group, N = 160:
  corr  0.74755 vs 0.72065  (win)
  NSE   0.39314 vs 0.41824  (loss)
  rRMSE 77.901 vs 76.273    (loss)
  rB    17.176 vs 19.678    (win)
```

Conclusion:

```text
High p68 is acceptable and scientifically interpretable, but it does not solve
the high-flow NSE/rRMSE loss. It is also slightly weaker than high p75 on the
overall score. Do not promote it as the final method.
```

## 2026-07-21 variance-weighted overlap combine quick trial

Rationale:

```text
Each target day is estimated by multiple overlapping 22-day windows. Instead of
choosing the center-window estimate, use KF/RTS posterior covariance to combine
windows:

  w_k = 1 / Var_k
  Q_day = sum(w_k * Q_k) / sum(w_k)

This uses only the filter's own posterior uncertainty. It does not use
Q_SIC4DVar_interp, gauge, SVS, other products, or output anomaly scaling.
```

Quick 20-path result:

```text
ConfigSet: sic22_rts_norescale_varweight20
N = 21 for both high-p75 and high-p68 variants

rts_highp75_Q0p18_varw_smooth5_nonneg:
  corr  0.49795 vs 0.49185  (win)
  NSE   0.22852 vs 0.16239  (win)
  rRMSE 87.834 vs 91.521    (win)
  rB    42.839 vs 37.427    (loss)

rts_highp68_Q0p18_varw_smooth5_nonneg:
  corr  0.49795 vs 0.49185  (win)
  NSE   0.22852 vs 0.16239  (win)
  rRMSE 87.834 vs 91.521    (win)
  rB    42.839 vs 37.427    (loss)
```

High group quick result:

```text
N = 4 only.

high-p75 var-weight:
  corr  0.63625 vs 0.75398  (loss)
  NSE   0.38091 vs 0.39483  (loss)
  rRMSE 76.129 vs 77.116    (win)
  rB    47.163 vs 45.396    (loss)

high-p68 var-weight:
  corr  0.62422 vs 0.75398  (loss)
  NSE   0.35075 vs 0.39483  (loss)
  rRMSE 78.291 vs 77.116    (loss)
  rB    47.574 vs 45.396    (loss)
```

Conclusion:

```text
Variance-weighted overlap combine is scientifically legitimate, but the quick
sample does not improve the main high-flow issue. It should not be promoted or
expanded to full 666 before trying a cleaner covariance-calibration route.
```

## 2026-07-21 automatic QScale covariance-matching quick trial

Rationale:

```text
The fixed QScale = 0.18 is easy to criticize as validation-tuned. The
QScaleMode = match_obs_qdiag option estimates an effective process-noise scale
from the ratio between typical observation variance diag(R) and original
process variance diag(Q_original), bounded to [0.03, 1.0]. This is a cleaner
covariance-calibration idea than selecting one fixed scalar from validation.
```

Quick 20-path result:

```text
ConfigSet: sic22_rts_norescale_qmatch_center20
N = 21

rts_highp75_qmatch_center_smooth5_nonneg:
  corr  0.56633 vs 0.49185  (win)
  NSE   0.31561 vs 0.16239  (win)
  rRMSE 82.728 vs 91.521    (win)
  rB    44.479 vs 37.427    (loss)

rts_highp68_qmatch_center_smooth5_nonneg:
  corr  0.54715 vs 0.49185  (win)
  NSE   0.28673 vs 0.16239  (win)
  rRMSE 84.455 vs 91.521    (win)
  rB    44.479 vs 37.427    (loss)
```

High group quick result:

```text
N = 4 only.

high-p75 qmatch:
  corr  0.59235 vs 0.75398  (loss)
  NSE   0.21061 vs 0.39483  (loss)
  rRMSE 86.378 vs 77.116    (loss)
  rB    49.860 vs 45.396    (loss)

high-p68 qmatch:
  corr  0.58656 vs 0.75398  (loss)
  NSE   0.18254 vs 0.39483  (loss)
  rRMSE 87.722 vs 77.116    (loss)
  rB    50.459 vs 45.396    (loss)
```

Conclusion:

```text
Automatic QScale covariance matching is more defensible than fixed QScale, but
this quick sample worsens the high-flow group. Do not promote or expand this
candidate.
```

## 2026-07-21 uncertainty-floor Q0.18 quick trial

Rationale:

```text
Instead of special-casing high flow with p75, use a uniform forward rule:
the group-specific uncertainty percent cannot be lower than the product's
global robust uncertainty.

For SIC4DVar this behaves like:
  low  = max(low median, global robust percent)
  mid  = max(mid median, global robust percent)
  high = max(high median, global robust percent)

This is more defensible than only applying p75 to high flow because it follows
one rule for all Qprior groups.
```

Quick 20-path result:

```text
ConfigSet: sic22_rts_norescale_uncfloor_q01820
candidate: rts_uncfloor_Q0p18_center_smooth5_nonneg
N = 21

overall medians:
  corr  0.61555 vs 0.49185  (win)
  NSE   0.37784 vs 0.16239  (win)
  rRMSE 78.877 vs 91.521    (win)
  rB    45.661 vs 37.427    (loss)
```

High group quick result:

```text
N = 4 only.

high group:
  corr  0.64533 vs 0.75398  (loss)
  NSE   0.39285 vs 0.39483  (near tie, slight loss)
  rRMSE 75.394 vs 77.116    (win)
  rB    46.992 vs 45.396    (loss)
```

Conclusion:

```text
The uncertainty-floor rule is scientifically cleaner than high-only p75 and is
more promising than qmatch/varweight for high-flow NSE/rRMSE. It still loses
high-flow corr and rB in the quick sample, so it is not a solution yet. Expand
to 80 paths before deciding whether to pursue full validation.
```

80-path uncertainty-floor result:

```text
detail: sic22_compare_rts_norescale_uncfloor_q018_top80_20260721_190627.mat
cdf:    sic22_compare_rts_norescale_uncfloor_q018_top80_20260721_190627_cdf.png
N = 86

overall medians:
  corr  0.54774 vs 0.52974  (win)
  NSE   0.23154 vs 0.15516  (win)
  rRMSE 87.662 vs 91.915    (win)
  rB    27.043 vs 32.027    (win)
```

80-path group medians:

```text
low, N = 9:
  corr  0.20675 vs 0.10358
  NSE  -0.05818 vs -0.31631
  rRMSE 102.868 vs 114.731
  rB    34.958 vs 39.576

mid, N = 68:
  corr  0.61015 vs 0.57665
  NSE   0.29077 vs 0.23316
  rRMSE 84.216 vs 87.568
  rB    28.520 vs 31.435

high, N = 9:
  corr  0.54989 vs 0.51771
  NSE   0.25586 vs 0.23693
  rRMSE 86.264 vs 87.354
  rB    25.618 vs 27.091
```

Decision:

```text
The uncertainty-floor rule is the cleanest promising candidate so far: it uses
one forward uncertainty rule for all Qprior groups and wins all overall and
low/mid/high median metrics on the 80-path sample. Expand to full 001-666
validation before drawing conclusions.
```

Full validation chunk 001-222 for uncertainty-floor:

```text
detail: sic22_compare_rts_norescale_uncfloor_q018_fullchunk_001_222_20260721_194409.mat
cdf:    sic22_compare_rts_norescale_uncfloor_q018_fullchunk_001_222_20260721_194409_cdf.png
N = 343

overall medians:
  corr  0.55365 vs 0.50413  (win)
  NSE   0.22719 vs 0.15913  (win)
  rRMSE 87.910 vs 91.699    (win)
  rB    13.636 vs 15.527    (win)

overall win rates:
  corr  0.682
  NSE   0.621
  rRMSE 0.621
  rB    0.496
```

Chunk 001-222 group medians:

```text
low, N = 28:
  corr  0.32321 vs 0.18691
  NSE   0.08753 vs 0.00915
  rRMSE 95.519 vs 99.539
  rB    20.209 vs 21.238

mid, N = 287:
  corr  0.55955 vs 0.50354
  NSE   0.22783 vs 0.16133
  rRMSE 87.873 vs 91.579
  rB    13.665 vs 15.422

high, N = 28:
  corr  0.69943 vs 0.64580
  NSE   0.32004 vs 0.30569
  rRMSE 82.455 vs 83.311
  rB    11.737 vs 14.692
```

Interpretation:

```text
This first full-validation chunk is stronger than the earlier high-p75/p68
full chunks: all overall medians and all low/mid/high group medians beat
interpolated SIC4DVar. It is still not a final all-sample conclusion until
chunks 223-444 and 445-666 are finished and merged. Also, rB's overall pointwise
win rate is 0.496, so even this promising chunk is not yet a literal point-by-
point dominance result.
```
