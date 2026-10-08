# Badge Reference

> [!NOTE]
> Badges are the first thing users see. Choose wisely — they signal project health and maturity.

Complete badge syntax for all ecosystems.

## Rust Badges

### Required

```markdown
<!-- Crates.io version -->
[![Crates.io](https://img.shields.io/crates/v/{crate})](https://crates.io/crates/{crate})

<!-- docs.rs -->
[![docs.rs](https://img.shields.io/docsrs/{crate})](https://docs.rs/{crate})
```

### Recommended

```markdown
<!-- CI Status (GitHub Actions) -->
[![CI](https://img.shields.io/github/actions/workflow/status/{owner}/{repo}/ci.yml?branch=main)](https://github.com/{owner}/{repo}/actions)

<!-- MSRV -->
[![MSRV](https://img.shields.io/crates/msrv/{crate})](https://crates.io/crates/{crate})

<!-- License -->
[![License](https://img.shields.io/crates/l/{crate})](LICENSE)
```

### Optional

```markdown
<!-- Downloads -->
[![Downloads](https://img.shields.io/crates/d/{crate})](https://crates.io/crates/{crate})

<!-- Code Coverage (Codecov) -->
[![codecov](https://codecov.io/gh/{owner}/{repo}/branch/main/graph/badge.svg)](https://codecov.io/gh/{owner}/{repo})

<!-- Dependency Status -->
[![deps.rs](https://deps.rs/repo/github/{owner}/{repo}/status.svg)](https://deps.rs/repo/github/{owner}/{repo})

<!-- unsafe forbidden -->
[![unsafe forbidden](https://img.shields.io/badge/unsafe-forbidden-success.svg)](https://github.com/rust-secure-code/safety-dance/)

<!-- no_std compatible -->
[![no_std](https://img.shields.io/badge/no__std-compatible-success.svg)]()
```

## TypeScript/JavaScript Badges

### Required

```markdown
<!-- npm version -->
[![npm](https://img.shields.io/npm/v/{package})](https://www.npmjs.com/package/{package})

<!-- License -->
[![License](https://img.shields.io/npm/l/{package})](LICENSE)
```

### Recommended

```markdown
<!-- Bundle Size (minified + gzipped) -->
[![Bundle Size](https://img.shields.io/bundlephobia/minzip/{package})](https://bundlephobia.com/package/{package})

<!-- TypeScript -->
[![TypeScript](https://img.shields.io/badge/TypeScript-Ready-blue?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)

<!-- CI Status -->
[![CI](https://img.shields.io/github/actions/workflow/status/{owner}/{repo}/ci.yml)](https://github.com/{owner}/{repo}/actions)
```

### Optional

```markdown
<!-- Downloads -->
[![Downloads](https://img.shields.io/npm/dm/{package})](https://www.npmjs.com/package/{package})

<!-- Node version -->
[![Node](https://img.shields.io/node/v/{package})](https://nodejs.org)

<!-- Code Coverage -->
[![codecov](https://codecov.io/gh/{owner}/{repo}/branch/main/graph/badge.svg)](https://codecov.io/gh/{owner}/{repo})

<!-- Dependencies -->
[![Dependencies](https://img.shields.io/librariesio/release/npm/{package})](https://libraries.io/npm/{package})

<!-- Minified size only -->
[![Minified](https://img.shields.io/bundlephobia/min/{package})](https://bundlephobia.com/package/{package})
```

## Python Badges

### Required

```markdown
<!-- PyPI version -->
[![PyPI](https://img.shields.io/pypi/v/{package})](https://pypi.org/project/{package})

<!-- Python versions -->
[![Python](https://img.shields.io/pypi/pyversions/{package})](https://pypi.org/project/{package})

<!-- License -->
[![License](https://img.shields.io/pypi/l/{package})](LICENSE)
```

### Recommended

```markdown
<!-- CI Status -->
[![CI](https://img.shields.io/github/actions/workflow/status/{owner}/{repo}/ci.yml)](https://github.com/{owner}/{repo}/actions)

<!-- Documentation (Read the Docs) -->
[![Documentation](https://readthedocs.org/projects/{package}/badge/?version=latest)](https://{package}.readthedocs.io)
```

### Optional

```markdown
<!-- Downloads -->
[![Downloads](https://img.shields.io/pypi/dm/{package})](https://pypi.org/project/{package})

<!-- Code Coverage -->
[![codecov](https://codecov.io/gh/{owner}/{repo}/branch/main/graph/badge.svg)](https://codecov.io/gh/{owner}/{repo})

<!-- Code style: black -->
[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)

<!-- Ruff -->
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)

<!-- PyPI Format -->
[![Format](https://img.shields.io/pypi/format/{package})](https://pypi.org/project/{package})

<!-- Typed -->
[![Typed](https://img.shields.io/badge/typed-mypy-blue)](http://mypy-lang.org/)
```

## Universal Badges

### CI/CD

```markdown
<!-- GitHub Actions -->
[![CI](https://img.shields.io/github/actions/workflow/status/{owner}/{repo}/{workflow}.yml?branch=main)](https://github.com/{owner}/{repo}/actions)

<!-- GitHub Actions with label -->
[![Build](https://img.shields.io/github/actions/workflow/status/{owner}/{repo}/ci.yml?branch=main&label=build)](https://github.com/{owner}/{repo}/actions)
```

### Code Quality

```markdown
<!-- Code Coverage (Codecov) -->
[![codecov](https://codecov.io/gh/{owner}/{repo}/branch/main/graph/badge.svg)](https://codecov.io/gh/{owner}/{repo})

<!-- Code Coverage (Coveralls) -->
[![Coverage Status](https://coveralls.io/repos/github/{owner}/{repo}/badge.svg?branch=main)](https://coveralls.io/github/{owner}/{repo}?branch=main)
```

### Community

```markdown
<!-- GitHub Stars -->
[![Stars](https://img.shields.io/github/stars/{owner}/{repo})](https://github.com/{owner}/{repo}/stargazers)

<!-- GitHub Issues -->
[![Issues](https://img.shields.io/github/issues/{owner}/{repo})](https://github.com/{owner}/{repo}/issues)

<!-- Contributors -->
[![Contributors](https://img.shields.io/github/contributors/{owner}/{repo})](https://github.com/{owner}/{repo}/graphs/contributors)

<!-- Discord -->
[![Discord](https://img.shields.io/discord/{server_id})](https://discord.gg/{invite})
```

### Licenses

```markdown
<!-- MIT -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

<!-- Apache 2.0 -->
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

<!-- GPL v3 -->
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

<!-- Dual License (Rust common) -->
[![License](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue)](LICENSE)
```

## Badge Order Guidelines

> [!CAUTION]
> More than 6 badges creates visual noise. If you have 10+ badges, you're doing it wrong.

Arrange badges by importance:

1. **Version/Registry** - Primary identifier
2. **Build/CI status** - Project health
3. **Documentation** - Learnability  
4. **Coverage** - Code quality
5. **License** - Legal clarity
6. **Downloads/Stars** - Social proof

**Maximum badges:** 6 in hero section. More becomes visual noise.

## Formatting

### Single Row

```markdown
[![A](url)](link) [![B](url)](link) [![C](url)](link)
```

### Multi-Row (if many badges)

```markdown
[![A](url)](link)
[![B](url)](link)
[![C](url)](link)

[![D](url)](link)
[![E](url)](link)
```

### With Line Breaks (HTML)

```html
<p align="center">
  <a href="link"><img src="badge-url" alt="badge"></a>
  <a href="link"><img src="badge-url" alt="badge"></a>
</p>
```
