#!/bin/sh
# Two-module minimal repro (matched configs). Expect: -Onone all OK; -O prints
# "nested, box + IKUR ... ** SKIP **" (user deinit omitted, fields destroyed).
# Toolchain of record: Apple Swift 6.3.2 (org.swift.632202605101a).
set -e
TC=${TOOLCHAINS:-org.swift.632202605101a}
for opt in -Onone -O; do
  echo "=== matched $opt ==="
  TOOLCHAINS=$TC xcrun swiftc $opt -parse-as-library -emit-module -emit-library -module-name Inner3 inner.swift -o libInner3.dylib
  TOOLCHAINS=$TC xcrun swiftc $opt main.swift -I . -L . -lInner3 -o main_$opt
  ./main_$opt
done
