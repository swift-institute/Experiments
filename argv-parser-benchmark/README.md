# argv-parser-benchmark

Benchmark experiment comparing the **institute argv-parser spike** (built on
`Parser.Protocol` from `swift-parser-primitives`) against
**Apple's `swift-argument-parser`** on three axes:

1. **Parse latency** — nanoseconds per `argv → struct` parse, 100k iterations
2. **Executable binary size** — bytes for `.build/release/<name>`
3. **Compile time** — wall-clock seconds for a cold rebuild

Both targets implement the same canonical `Repeat` example
(`--count <Int>`, `--include-counter` flag, `<positional String>`) and are
byte-identical at stdout for the same argv.

This feeds U8 in
`/Users/coen/Developer/swift-institute/Research/2026-05-15-swift-arguments-ecosystem-design.md`.

## Methodology

- Toolchain: default macOS toolchain, 2026-05-15.
- Build config: `swift build -c release` (optimization on, no debug symbols
  in measurement).
- Parse latency: 100,000 iterations on warm cache (one warm parse per
  parser before timing); `ContinuousClock` per iteration. Mean and min
  reported in nanoseconds.
- Binary size: byte count of `.build/release/RepeatApple` and
  `.build/release/RepeatInstitute` after a full release build. Both
  unstripped and stripped (`strip`) numbers reported.
- Compile time: `rm -rf .build && time swift build -c release --target
  <name>`, two trials each, wall-clock seconds.

The institute target uses the **leaf `RepeatParser`** from
`argv-parser-protocol-spike` (verbatim source copies, no modification).
The combinator variant from the spike was excluded because it fails to
compile against the current `Parser.Many` API.

## Equivalence check

```
$ .build/release/RepeatApple --count 3 --include-counter hello
1: hello
2: hello
3: hello
$ .build/release/RepeatInstitute --count 3 --include-counter hello
1: hello
2: hello
3: hello
```

Identical for the heavy case as well (`--count 1000 --include-counter hello`
produces 1000 numbered lines from both; verified via `tail -3`).

## Results

### 1. Parse latency (100k iterations, warm cache)

| Parser                          | Mean (ns/parse) | Min (ns/parse) |
| ------------------------------- | --------------: | -------------: |
| Apple `swift-argument-parser`   |        61,292.5 |         55,750 |
| Institute `Parser.Protocol`     |           534.4 |            416 |
| **Ratio (institute / apple)**   |     **0.009×**  |     **0.007×** |

Institute is ~**115× faster** on this micro-benchmark.

### 2. Binary size (`swift build -c release`)

| Parser                          | Bytes (unstripped) | Bytes (stripped) |
| ------------------------------- | -----------------: | ---------------: |
| Apple `swift-argument-parser`   |          1,517,976 |          735,704 |
| Institute `Parser.Protocol`     |          4,708,624 |        1,645,512 |
| **Ratio (institute / apple)**   |            **3.1×** |        **2.24×** |

Institute binary is **3.1× larger** unstripped, **2.24× larger** stripped.

### 3. Compile time (cold rebuild, wall-clock)

| Parser                          | Trial 1 | Trial 2 | Mean    |
| ------------------------------- | ------: | ------: | ------: |
| Apple `swift-argument-parser`   | 20.1 s  | 18.1 s  | ~19 s   |
| Institute `Parser.Protocol`     | 24.8 s  | 27.0 s  | ~26 s   |
| **Ratio (institute / apple)**   |         |         | **1.4×** |

Institute compile is **~1.4× slower** wall-clock. CPU time is much higher
(~45s vs ~17s) but the institute build parallelizes more aggressively
(226% vs 107% CPU), so wall-clock gap is smaller than CPU-time gap.

## Interpretation

**The institute design is dramatically faster on parse latency** —
two orders of magnitude faster on this input. The reason is structural:
Apple's `ParsableCommand` does reflective argument parsing via `Mirror`
and goes through a generic `ArgumentSet` / `ArgumentDecoder` pipeline
each call. The institute leaf parser is a hand-rolled switch over
`Element == String` with O(n) characteristics — and the call is fully
specialized at compile time because the parser type is statically known.

**The institute design pays for that speed with binary size and compile
time.** Even the leaf-only path pulls in ~150 institute submodules
(`Parser_*_Primitives`, `Input_Primitives`, `Array_*_Primitives`,
`Memory_*_Primitives`, etc.). That's ~3 MB of code linked in. Apple's
`swift-argument-parser` is a single library target with a tighter
transitive dep set (just `ArgumentParserToolInfo`).

**Compile time is closer than expected.** Despite the institute target
compiling ~150 small modules vs. Apple's ~2, wall-clock is only 1.4×
slower because the institute modules parallelize well across cores. CPU
time tells a different story (~2.6× more CPU consumed), which would
matter on a single-core CI runner or under load.

## Verdict on U8 (research-doc impact)

| Axis           | Verdict for institute design       |
| -------------- | ---------------------------------- |
| Parse latency  | **Decisive win** (~115×)           |
| Binary size    | **Decisive loss** (~3.1× larger)   |
| Compile time   | **Mild loss** (~1.4× slower)       |

The institute approach shows a **mixed result** that depends on the use
case:

- A **CLI launcher** that runs once per process invocation: parse
  latency is irrelevant (microseconds either way); binary size and
  compile time dominate; **Apple wins**.
- A **library that parses argv-like structures repeatedly** (e.g.,
  shell-completion engines, REPL command dispatchers, embedded
  command DSLs): parse latency matters; **institute wins decisively**.
- A **production daemon parsing user-supplied argv strings as part of
  its hot path** (e.g., a coordinator that re-parses subcommand
  strings inside a request loop): parse latency dominates; **institute
  wins**.

The 3.1× binary-size cost is **largely a packaging artifact** of the
swift-primitives layering, not an intrinsic cost of the design — the
leaf parser touches a small fraction of the modules it transitively
pulls in. A future `swift-arguments` L3 package that consolidates the
specific subset of `Parser.Protocol` + `Input.Protocol` machinery into
a leaner umbrella module would likely close most of that gap.

## Caveats

1. **Stripped sizes (where SDK boilerplate is removed) narrow the gap
   from 3.1× to 2.24×.** Unstripped binaries include debug-info /
   symbol tables, which inflate the institute binary disproportionately
   because it has more discrete modules each contributing module-info
   strings.
2. **Apple's `swift-argument-parser` includes help-text generation,
   error formatting, completion-script generation, and ManualGen
   plugins** — none of which the institute leaf parser provides. A
   real `swift-arguments` L3 that adds these features will pay back
   some of the size advantage.
3. **The institute leaf parser was hand-rolled for this specific
   grammar** (`--count <Int>`, `--include-counter` flag, positional
   `String`). A general-purpose declarative API on top (analogous to
   `@Option`/`@Flag`/`@Argument`) will add overhead. The combinator
   variant from the spike was excluded because it fails to compile
   against the current `Parser.Many` API; whether the combinator
   variant retains the parse-latency advantage is an open question.
4. **Benchmark machine: M-series Mac**, single run. Numbers will
   differ on x86_64 and Linux.
5. **The 115× parse-latency ratio is for a specific 4-element argv
   (`--count 1000 --include-counter hello`).** Larger argvs may
   narrow the gap as both implementations spend more time per-element;
   smaller argvs (single positional) may widen it.

## Recommendations for the research doc

For U8: the institute Parser.Protocol approach has a **clear
performance ceiling advantage** but currently incurs a **packaging tax**
on binary size and a smaller tax on compile time. The verdict is
mixed but **favors institute for non-launcher use cases**.

If the L3 `swift-arguments` package can be packaged tightly (fewer
transitive imports), the binary-size cost should fall meaningfully —
this is an L3-design question, not a P1 (institute-approach-feasible)
refutation. The 115× speedup is too large to ignore, and even if the
declarative-API layer doubles or triples parse cost (i.e., ~1500 ns
mean vs. Apple's ~60,000 ns), the institute design still wins by
~40×.

## Build and run

```sh
cd /Users/coen/Developer/swift-institute/Experiments/argv-parser-benchmark
swift build -c release
.build/release/RepeatApple --count 3 --include-counter hello
.build/release/RepeatInstitute --count 3 --include-counter hello
.build/release/BenchDriver

# Compile-time measurement (cold rebuild):
./Scripts/measure-compile-time.sh
```

## Files

- `Package.swift` — declares `RepeatApple`, `RepeatInstitute`,
  `BenchDriver` executable targets. Path deps to
  `swiftlang/swift-argument-parser` and three institute primitives.
- `Sources/RepeatApple/Repeat.swift` — verbatim copy of
  `swift-argument-parser/Examples/repeat/Repeat.swift`.
- `Sources/RepeatInstitute/` — verbatim copies of leaf-parser sources
  from `argv-parser-protocol-spike` (`Repeat.swift`, `RepeatParser.swift`,
  `ArgvInput.swift`) plus a `main.swift` that drives the parser with
  `CommandLine.arguments` and prints byte-equivalent output to
  `RepeatApple`. Foundation deliberately not imported (to keep the
  size comparison clean).
- `Sources/BenchDriver/main.swift` — single-process latency benchmark
  that times both parsers on the same input.
- `Scripts/measure-compile-time.sh` — cold-rebuild compile-time script.
