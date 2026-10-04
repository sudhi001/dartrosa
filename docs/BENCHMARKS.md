# Benchmarks

`packages/dartrosa/benchmark/engine_benchmark.dart`, compiled AOT
(`dart compile exe`), on a desktop (Apple silicon). Mobile devices are
slower; the plan's targets are for a mid-range Android phone.

| Case | Result | Target (PORTING_PLAN §1, §10.1) |
|---|---|---|
| Parse a 1,000-question form (relevance, calculations, constraints) | 85 ms | < 300 ms on a phone |
| Answer → recompute dependents | < 0.1 ms | < 16 ms |
| Start a session (initialize all calculations) | 13 ms | — |
| Filter a 100,000-row CSV choice list (`[region = /data/region]`) | 4.1 ms | < 50 ms |
| Grow a repeat to 1,000 instances with `position()` / `count()` dependents | 4.6 s | JavaRosa 6.0.0 on the JVM: 3.0 s |

Repeat growth is quadratic in both engines: JavaRosa recomputes
triggerables that depend on the repeat's size in every instance on each
insertion, and DartRosa reproduces that algorithm. It is the only case
where DartRosa is noticeably slower than JavaRosa (about 1.5×).

Reproduce:

```sh
cd packages/dartrosa
dart compile exe benchmark/engine_benchmark.dart -o /tmp/dartrosa-bench
/tmp/dartrosa-bench
```
