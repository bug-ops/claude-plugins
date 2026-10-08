# Rust — CI/CD Rules

SHAs below were resolved on 2026-10-08. Re-resolve them for the version you add (see Action Pinning in the agent prompt); never copy them blindly. `dtolnay/rust-toolchain` is pinned to its `v1` commit and selects the toolchain through the `toolchain` input. `taiki-e/install-action` takes the tool through the `tool` input when pinned by SHA.

## Complete GitHub Actions Workflow

**.github/workflows/ci.yml:**

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

permissions:
  contents: read

env:
  CARGO_TERM_COLOR: always
  RUSTFLAGS: "-D warnings"

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    name: Check
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: dtolnay/rust-toolchain@7e38f4b43b4db5c8dd498af069a4f6196df1d067 # v1
        with:
          toolchain: stable
          components: rustfmt, clippy
      - uses: Swatinem/rust-cache@6323deb102c322ba6fcbdcafc7e3dddab59af2b6 # v2.9.2
      - run: cargo fmt --check
      - run: cargo clippy --all-targets -- -D warnings

  test:
    name: Test (${{ matrix.os }})
    needs: [check]
    runs-on: ${{ matrix.os }}
    timeout-minutes: 30
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: dtolnay/rust-toolchain@7e38f4b43b4db5c8dd498af069a4f6196df1d067 # v1
        with:
          toolchain: stable
      - uses: mozilla-actions/sccache-action@fc920bf0ec8de6ee65d409111f7ec508035751ba # v0.0.11
      - uses: Swatinem/rust-cache@6323deb102c322ba6fcbdcafc7e3dddab59af2b6 # v2.9.2
      - uses: taiki-e/install-action@f7e5d7c961414b23f5b25b2da9294395d08513ad # v2.87.26
        with:
          tool: cargo-nextest
      - run: cargo nextest run --all-features

  coverage:
    name: Coverage
    needs: [check]
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: dtolnay/rust-toolchain@7e38f4b43b4db5c8dd498af069a4f6196df1d067 # v1
        with:
          toolchain: stable
      - uses: taiki-e/install-action@f7e5d7c961414b23f5b25b2da9294395d08513ad # v2.87.26
        with:
          tool: cargo-llvm-cov
      - run: cargo llvm-cov --lcov --output-path lcov.info
      - uses: codecov/codecov-action@303a32d7a59b442fa8d48b6a1cc6825c09c847a5 # v7.1.1
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: lcov.info

  security:
    name: Security
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: taiki-e/install-action@f7e5d7c961414b23f5b25b2da9294395d08513ad # v2.87.26
        with:
          tool: cargo-deny
      - run: cargo deny check
```

The `check` and `test` steps show the shape; replace them with the full check suite from `toolchain.md` (nightly `rustfmt`, workspace flags, the doc gate) or the project's own CI-matching commands.

## Caching Strategies

### Swatinem/rust-cache

```yaml
- uses: Swatinem/rust-cache@6323deb102c322ba6fcbdcafc7e3dddab59af2b6 # v2.9.2
  with:
    shared-key: "build"
    save-if: ${{ github.ref == 'refs/heads/main' }}
```

### sccache

```yaml
- uses: mozilla-actions/sccache-action@fc920bf0ec8de6ee65d409111f7ec508035751ba # v0.0.11
- run: echo "RUSTC_WRAPPER=sccache" >> $GITHUB_ENV
```

## Security Scanning

**deny.toml** (cargo-deny config format version 2; vulnerabilities are always denied):
```toml
[advisories]
version = 2

[licenses]
version = 2
allow = ["MIT", "Apache-2.0"]
```

## Dependabot

**.github/dependabot.yml:**
```yaml
version: 2
updates:
  - package-ecosystem: cargo
    directory: "/"
    schedule:
      interval: weekly
    groups:
      minor-patch:
        patterns: ["*"]
        update-types: [minor, patch]
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```

## MSRV Check

```yaml
msrv:
  runs-on: ubuntu-latest
  timeout-minutes: 15
  steps:
    - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
    - id: msrv
      run: |
        MSRV=$(grep '^rust-version' Cargo.toml | sed 's/.*"\(.*\)".*/\1/')
        echo "version=$MSRV" >> $GITHUB_OUTPUT
    - uses: dtolnay/rust-toolchain@7e38f4b43b4db5c8dd498af069a4f6196df1d067 # v1
      with:
        toolchain: ${{ steps.msrv.outputs.version }}
    - run: cargo check
```

## Release Workflow

```yaml
on:
  push:
    tags: ['v*']

permissions:
  contents: read

jobs:
  build:
    runs-on: ${{ matrix.os }}
    timeout-minutes: 30
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            target: x86_64-unknown-linux-gnu
          - os: macos-latest
            target: aarch64-apple-darwin
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: dtolnay/rust-toolchain@7e38f4b43b4db5c8dd498af069a4f6196df1d067 # v1
        with:
          toolchain: stable
          targets: ${{ matrix.target }}
      - run: cargo build --release --target ${{ matrix.target }}
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: binary-${{ matrix.target }}
          path: target/${{ matrix.target }}/release/
```

## Feature Flags Testing Strategy

When a crate has default features and optional features disabled by default, CI verifies both configurations to catch feature-gating bugs.

**Feature matrix job:**
```yaml
feature-test:
  name: Features (${{ matrix.features }})
  needs: [check]
  runs-on: ubuntu-latest
  timeout-minutes: 30
  strategy:
    fail-fast: false
    matrix:
      features:
        - ""              # default features only
        - "--all-features"
  steps:
    - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
    - uses: dtolnay/rust-toolchain@7e38f4b43b4db5c8dd498af069a4f6196df1d067 # v1
      with:
        toolchain: stable
        components: clippy
    - uses: Swatinem/rust-cache@6323deb102c322ba6fcbdcafc7e3dddab59af2b6 # v2.9.2
      with:
        key: ${{ matrix.features }}
    - run: cargo test ${{ matrix.features }}
    - run: cargo clippy ${{ matrix.features }} -- -D warnings
```

**Why both configurations matter:**
- Default features: what most users get out of the box
- All features: ensures optional code compiles and tests pass

**Extended matrix for complex projects:**
```yaml
matrix:
  features:
    - ""                    # default
    - "--all-features"      # everything enabled
    - "--no-default-features"  # minimal build
    - "--no-default-features --features feat1,feat2"  # specific combination
```

For exhaustive coverage, run the feature-combinations command from `toolchain.md` (`cargo hack`).

## Common Issues & Solutions

**Slow builds:**
- Add sccache
- Use nextest instead of cargo test
- Optimize dependency features

**Flaky tests:**
```yaml
- uses: nick-fields/retry@ad984534de44a9489a53aefd81eb77f87c70dc60 # v4.0.0
  with:
    max_attempts: 3
    timeout_minutes: 20
    command: cargo nextest run
```
