# CI pipeline

The smaller third-party caches reduce restoration time. Overall PR speedup remains inconclusive: the median improves slightly, while p90 increases.
Keep the artifact scopes because the restore benefit is measured and the existing build and test checks pass.

Measurements collected on 2026-10-12 Pacific cover [PR CI](../.github/workflows/ci.yml), [main releases](../.github/workflows/main.yml), and the shared [macOS setup action](../.github/actions/setup-macos/action.yml).
The [policy workflow](../.github/workflows/pr-policy.yml) runs independently; its [branch check](https://github.com/supabitapp/supacode/actions/runs/38327493664) took eight seconds.
Issue, label, and manually dispatched automation do not determine this PR's build completion.

## Measurement basis

Historical runs and initial branch runs measure workflow `created_at` to the last job's `completed_at`, including runner allocation.
Branch reruns measure the attempt's `run_started_at` to the last job's completion as a proxy for a fresh PR run.
These intervals omit client push latency and any delay before GitHub creates the workflow.
Runner minutes sum active job intervals, including overlapping jobs.
Median averages the middle pair for even samples; p90 uses nearest rank, `ceil(0.9 * n)`.

The historical cohorts contain the last 20 successful runs available before this branch's experiments.
Their dates span August through October and include older app versions and cold artifacts; the broad PR cohort includes one successful rerun.
The comparable cohort contains three warm PR runs using Xcode 26.3, the same artifact keys, and 179 Swift files under `supacodeTests`.
The latest baseline and measured branch have identical app, test, project, and build-script sources.

Read each run and its jobs through the GitHub API:

```bash
gh api repos/supabitapp/supacode/actions/runs/RUN_ID
gh api 'repos/supabitapp/supacode/actions/runs/RUN_ID/jobs?per_page=100'
gh api repos/supabitapp/supacode/actions/runs/38327243428/attempts/5
gh api 'repos/supabitapp/supacode/actions/runs/38327243428/attempts/5/jobs?per_page=100'
gh run view 38327243428 --attempt 5 --repo supabitapp/supacode --log
```

The CI timing skill's `scripts/ci-timings.sh` also verified the job and step intervals.
Its multi-run output uses the first job's creation time and a lower-order percentile convention, so its aggregates differ from the definitions above.

## Before and after

| Cohort | Successful samples | Wall median | Wall p90 | Runner minutes median | Runner minutes p90 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Historical PR CI | 20 | 10:58 | 26:03 | 10.86 | 25.92 |
| Historical main | 20 | 15:48 | 24:01 | 30.59 | 35.33 |
| Comparable warm PR baseline | 3 | 12:01 | 12:04 | 11.87 | 11.95 |
| Finished-artifact caches, warm | 3 | 11:48 | 13:43 | 11.60 | 13.48 |
| Finished-artifact caches, cold | 1 | 27:48 | 27:48 | 27.63 | 27.63 |

The observed warm median saving is 13 seconds (1.8%), against a projected 30 seconds and a predicted 11:31 path.
Warm p90 increases by 99 seconds (13.7%).
Median runner usage falls by 0.27 minutes; the prediction was 0.50 minutes.
Three successful samples per comparable cohort cannot establish a stable tail or attribute the whole workflow difference to caching.

All finished-artifact measurements use head commit [`545c55f7a2961d9d5d554a62fce5b47f04f3d53c`](https://github.com/supabitapp/supacode/commit/545c55f7a2961d9d5d554a62fce5b47f04f3d53c).
GitHub executes the PR merge commit; the head SHA identifies the measured branch candidate.

| Cohort | Run or attempt | Head SHA | Wall | Active runner time | Artifact restore |
| --- | --- | --- | ---: | ---: | ---: |
| Baseline | [38169616449](https://github.com/supabitapp/supacode/actions/runs/38169616449) | `19470831` | 12:01 | 11:52 | 31.211s |
| Baseline | [38132196681](https://github.com/supabitapp/supacode/actions/runs/38132196681) | `0e5dd3e8` | 11:12 | 11:05 | 37.553s |
| Baseline | [38130249983](https://github.com/supabitapp/supacode/actions/runs/38130249983) | `0d96942b` | 12:04 | 11:57 | 24.273s |
| Cold | [38327243428/1](https://github.com/supabitapp/supacode/actions/runs/38327243428/attempts/1) | `545c55f7` | 27:48 | 27:38 | Both miss |
| Warm | [38327243428/2](https://github.com/supabitapp/supacode/actions/runs/38327243428/attempts/2) | `545c55f7` | 13:43 | 13:29 | 10.322s |
| Warm | [38327243428/3](https://github.com/supabitapp/supacode/actions/runs/38327243428/attempts/3) | `545c55f7` | 11:48 | 11:36 | 5.431s |
| Failed warm | [38327243428/4](https://github.com/supabitapp/supacode/actions/runs/38327243428/attempts/4) | `545c55f7` | 9:00 | 8:50 | 6.785s |
| Warm retry | [38327243428/5](https://github.com/supabitapp/supacode/actions/runs/38327243428/attempts/5) | `545c55f7` | 8:07 | 7:58 | 4.309s |

Attempt 4 fails `WorktreeTerminalManagerReaperTests/terminateKillsTrackedEvenWithLiveClientsButSparesUntrackedInUse`: the mocked kill callback records the tracked session twice.
The unchanged shutdown implementation races a six-second budget and retries cancelled local kills.
This suggests an existing scheduling or timeout flake; the exact cause remains unproven.
The complete retry passes on the same SHA without suppressing or editing tests.
Successful timing aggregates exclude that failed attempt, which adds 8.83 runner minutes to the experiment's cost.

## Critical path and attribution

The PR path remains one `build` job: checkout, macOS setup, parallel lint/dependency inspection, app build, and the complete test scheme.
In baseline run 38169616449, it takes 12:01 from workflow creation, including nine seconds of runner allocation.
The latest main run, [38175604080](https://github.com/supabitapp/supacode/actions/runs/38175604080), takes 18:53 through `warm (Debug) -> build -> detect -> publish-stable -> publish`, including allocation gaps.
The main test job runs alongside the release build after both warm configurations finish.
Main after-measurements remain unavailable until merge.

| Phase | Class | Latest warm baseline seconds | Longest historical PR seconds | Warm after median seconds |
| --- | --- | ---: | ---: | ---: |
| Allocation and pre-attempt delay | Gating | 9 | 32 | 12 |
| Checkout | Setup | 16 | 15 | 14 |
| macOS setup | Setup | 58 | 1,019 | 37 |
| Lint, overlaps inspection | Toolchain | 24 | 19 | 18 |
| Dependency inspection, includes installation | Setup/toolchain | 110 | 90 | 93 |
| App build, includes project generation | Execution/toolchain | 191 | 255 | 202 |
| Test build and execution | Execution/toolchain | 329 | 352 | 338 |
| Remaining gaps and cleanup | Gating/setup | 8 | 52 | Not additive |

The longest historical PR is [33860687494](https://github.com/supabitapp/supacode/actions/runs/33860687494), attempt 2, at 30:15 from workflow creation.
Its pre-attempt delay is 27 seconds; using attempt start gives 29:48.
The parallel group counts once when calculating the path; phase medians do not sum to the workflow median.
Baseline Xcode reports a 126.563-second test-operation window inside the 329-second test step.
The remainder includes compilation, startup, and reporting; raw buffered log timestamps cannot isolate compiler time precisely.

| Step start, seconds from workflow or attempt start | Warm baseline median | Warm after median |
| --- | ---: | ---: |
| Job setup | 8 | 13 |
| Checkout | 9 | 14 |
| macOS setup | 21 | 28 |
| Lint and dependency inspection | 77 | 65 |
| App build | 176 | 158 |
| Tests | 378 | 360 |

Runner allocation and checkout place early after-steps five to seven seconds later.
Inspection and downstream steps start earlier at the median.
Attempt 2's inspection takes 128 seconds and its app build takes 242 seconds, delaying tests until offset 457 seconds.
Attempt 5's corresponding durations fall to 84 and 132 seconds, with tests starting at offset 262 seconds.
The cache change alters neither command nor test membership, so these differences remain confounders for overall attribution.
Lint and inspection already overlap in both cohorts; this branch adds no parallelism.

The cache action logs confirm misses on attempt 1 and hits on every warm attempt.
The cold run builds Ghostty in 824.959 seconds and zmx in 209.123 seconds, then saves both new namespaces.
Warm restore median falls from 31.211 to 5.431 seconds: 25.780 seconds (82.6%), within 20% of the predicted saving.
Compressed artifact bytes fall from 997,507,615 to 130,549,674, an 86.9% reduction, using decimal bytes from the cache logs.

The action stores the GhosttyKit framework, runtime resources, universal zmx binary, and their fingerprints.
Compiler intermediates are excluded; [the Ghostty build script](../scripts/build-ghostty.sh) and [the zmx build script](../scripts/build-zmx.sh) verify the retained outputs.
Cache namespaces change to `ghostty-v4` and `zmx-v2`; OS, architecture, Xcode, submodule, script, tooling, and patch inputs remain in the keys.
Both cache misses and fingerprint mismatches retain their rebuild paths.

Verdict: **inconclusive for overall speedup; keep for the measured restore reduction**.
The slower workflow tail prevents confirming the predicted overall saving, while the action-level measurement confirms the intended reduction in cache work.
The change uses the existing runners and job count, with no paid runner or concurrency increase.
Billing impact is unmeasured; observed runner usage appears in the cohort table.
Release concurrency, publication gates, contribution policy, test membership, and existing incident comments retain their behavior.

## Rejected package cache and validation

The earlier package-source cache experiment uses [`88d0b3ac0e23d56ef1fcb9562f76de315b62cca2`](https://github.com/supabitapp/supacode/commit/88d0b3ac0e23d56ef1fcb9562f76de315b62cca2).
Its [warm attempts 2](https://github.com/supabitapp/supacode/actions/runs/38322197846/attempts/2), [3](https://github.com/supabitapp/supacode/actions/runs/38322197846/attempts/3), and [4](https://github.com/supabitapp/supacode/actions/runs/38322197846/attempts/4) all pass.
The wall median is 11:11, p90 14:28, and median runner usage 10.98 minutes.
Setup plus inspection improves by only one second at the median, against a projected 75-second saving.
Verdict: **not confirmed; removed before the artifact experiment**.

Pinned package installation still resolves and materializes packages on warm runs.
The pinned [Tuist implementation](https://github.com/tuist/tuist/blob/4.203.1/swifterpm/Sources/swifterpm/Environment.swift) copies cached package directories in CI, while the local experiment uses symlinks.
Local package-cache timings therefore do not substitute for branch measurements.

The finished-artifact cold run and three successful warm runs pass `make lint`, `make inspect-dependencies`, `make build-app`, and `make test`.
The test scheme includes `supacodeTests`, `supacodeFeatureTests`, `supacodeGitTests`, and `supacodeTerminalTests`.
YAML parsing and `git diff --check` pass.
Actionlint 1.7.12 with ShellCheck 0.11.0 reports the same 14 existing diagnostics for CI/main before and after, including native `parallel` syntax and custom runner labels.
Local `make build-app` stops at preflight because this machine lacks a Zig-compatible Xcode; branch CI supplies the completed build and test validation.

## Trend and remaining work

| Measurement week | Swift test source files | Warm PR median | p90 | Median minutes per 100 source files |
| --- | ---: | ---: | ---: | ---: |
| 2026-10-12 baseline | 179 | 12:01 | 12:04 | 6.71 |
| 2026-10-12 artifact candidate | 179 | 11:48 | 13:43 | 6.59 |

The source count includes test helpers and comes from `git ls-tree -r --name-only HEAD supacodeTests`, filtered to `.swift` files at the measured head SHA.
All three comparable baseline commits have the same count; a growth rate cannot be inferred from these snapshots.
Re-measure after 20 successful runs with the new caches, when the source count reaches 200, or when warm median exceeds 13 minutes.

- Separate test compilation from execution using Xcode timing data before changing test distribution. The four existing bundles already parallelize within one runner.
- Prove package-manifest reuse across CI environments before introducing another package cache. The rejected source cache does not establish that benefit.
- Measure main's shared setup after merge, separating release tags, ordinary pushes, and cold artifacts.
- Investigate the shutdown-test timeout flake independently; retry time can exceed the cache savings.
- Additional jobs repeat checkout, setup, and dependency inspection. Their warm baseline cost is about three minutes per macOS job; paid runners or metered concurrency need a separate cost proposal.

Historical PR run IDs: `38169616449`, `38132196681`, `38130249983`, `38095569391`, `38077150421`, `33960070335`, `33957039399`, `33956316070`, `33860687494`, `32982779142`, `32952755575`, `32951702340`, `32674571324`, `32586101523`, `32577515125`, `32573412301`, `32537618482`, `32527867710`, `32523604380`, `32516784778`.

Historical main run IDs: `38175604080`, `38170482502`, `38132893114`, `38097069792`, `33960493293`, `33863224547`, `32958829053`, `32824437104`, `32675099911`, `32586608471`, `32578090169`, `32573485953`, `32538133016`, `32527910261`, `32524457443`, `32517761937`, `32486998417`, `32482563657`, `32375917087`, `32298378449`.
