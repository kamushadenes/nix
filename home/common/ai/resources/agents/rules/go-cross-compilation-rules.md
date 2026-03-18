---
paths: **/*.go
---

# Go Cross-Compilation

When cross-compiling Go with CGO enabled, use `zig` as the C/C++ compiler:

```bash
CGO_ENABLED=1 CC="zig cc -target aarch64-linux-gnu" CXX="zig c++ -target aarch64-linux-gnu" go build
```

Common targets: `aarch64-linux-gnu`, `x86_64-linux-gnu`, `aarch64-linux-musl`, `x86_64-linux-musl`.
