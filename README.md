# Experiments

Standalone Swift packages that verify compiler and runtime behaviour for the [Swift Institute](https://swift-institute.org) ecosystem — receipts for blog posts and research documents.

## Overview

Each subdirectory is a Swift package isolating one hypothesis (a compiler behaviour, a language constraint, an architectural approach) with a runnable build readers can clone and verify. Multi-variant experiments encode related claims as separate targets within the same package.

When a blog post claims "the compiler rejects this pattern," the experiment proves it. When research says "approach A compiles but approach B does not," the experiment shows both.

The convention for this repository is documented at [swift-institute.org](https://swift-institute.org/documentation/swift-institute/experiments). The companion research repository is at [swift-institute/Research](https://github.com/swift-institute/Research).

## Building

Each experiment is a standalone Swift package. Clone this repository and run `swift build` (or `swift run`) inside the experiment directory:

```
git clone https://github.com/swift-institute/Experiments.git
cd Experiments/{experiment-name}
swift build
```

Requires Swift 6.3 or newer.

## Index

[`_index.md`](_index.md) lists every experiment with its topic and result.

## License

[Apache 2.0](LICENSE.md).
