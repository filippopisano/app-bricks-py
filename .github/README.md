# Docker Images Release Process

## Three Docker Images

The repo produces three container images, each with its own Dockerfile under `containers/`:

| Image | Base | Purpose |
|---|---|---|
| **python-base** | `python:3.13-slim` | Foundation layer — system deps, user/group setup, fonts |
| **python-apps-base** | `python-base` | App runtime — installs the Arduino App Bricks `.whl`, Streamlit config |
| **ei-models-runner** | Edge Impulse inference image | AI/ML model inference with OOTB models |

## Release Triggers (Tag-Based)

Each image has a **separate tag namespace** that triggers its workflow:

| Tag pattern | Workflow | Image published |
|---|---|---|
| `base/X.Y.Z` | `docker-github-base-image.yml` | `python-base:X.Y.Z` + `:latest` |
| `release/X.Y.Z` | `docker-github-publish.yml` | `python-apps-base:X.Y.Z` |
| `ai/X.Y.Z` | `docker-github-publish-ai-containers.yml` | `ei-models-runner:X.Y.Z` |

Version extraction is driven by `setuptools_scm` in `pyproject.toml` with the regex `^(ai|release)/(?P<version>[0-9.]+)$`.

There is also a **manual dev build** workflow (`docker-github-dev-build.yml`) that builds both `python-apps-base` and `ei-models-runner` with the `dev-latest` tag.

## How Exceptions Are Handled

### 1. Conditional Python package build (matrix strategy)

The dev build workflow uses a matrix with a `build_python_package` flag:

- `python-apps-base` -> `build_python_package: true` — runs `task init:ci` + `task build` to produce the `.whl`
- `ei-models-runner` -> `build_python_package: false` — skips the Python build entirely

This avoids running unnecessary build steps for the AI container.

### 2. AI container auto-PR for compose file updates

The `ai/*` workflow has unique post-build logic that other workflows don't:

- After pushing the image, it runs `arduino-bricks-update-ai-container-ref -v <VERSION> -r <REGISTRY>`
- This calls `update_ai_container_references()` in `src/arduino/app_tools/module_listing.py`
- It then **automatically creates a PR** (branch: `ai-container-release-YYYYMMDDHHMMSS`) to update all brick compose files

### 3. Selective compose file updates (`only_ei_containers`)

The core update function `_update_compose_release_version()` in `src/arduino/app_internal/core/module.py` handles two modes:

- **Full release** (default): Replaces both `${APPSLAB_VERSION:-...}` and `${DOCKER_REGISTRY_BASE:-...}` variables in compose files
- **AI-only** (`only_ei_containers=True`): Only updates lines containing `ei-models-runner:X.Y.Z` via a targeted regex, leaving all other image references untouched. It also **skips compose files** that don't contain the `ei-models-runner` substring at all.

### 4. Base image version pinning

`python-apps-base` accepts a `BASE_IMAGE_VERSION` build arg (defaults to `latest`). This allows pinning to a specific `python-base` version without rebuilding the base, and the `REGISTRY` arg allows switching between production (`ghcr.io/arduino/`) and alternative registries.

### 5. Image size monitoring

`calculate-size-delta.yml` is a manual workflow that builds both `python-base` and `python-apps-base`, measures their sizes using a local Docker registry, and posts a comment on the associated PR. If no PR is found, it falls back to the GitHub Actions Job Summary.

## Build Characteristics

- **Single platform**: All images target `linux/arm64` only
- **Registry**: `ghcr.io/arduino/app-bricks/`
- **Caching**: GitHub Actions cache (`type=gha`, `mode=max`)
- **Release assets**: The `release/*` workflow also uploads the `.whl` to the GitHub Release via `softprops/action-gh-release`
