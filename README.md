# claude-image

Auto-published Docker image with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`@anthropic-ai/claude-code`) pre-installed.

A GitHub Actions workflow checks npm every 6 hours and pushes a new image to Docker Hub whenever a new version is released.

## Usage

```bash
docker run -it -e ANTHROPIC_API_KEY=sk-ant-... jbkirkland/claude-code
```

Check the installed version:

```bash
docker run -it jbkirkland/claude-code --version
```

Pin to a specific version:

```bash
docker run -it jbkirkland/claude-code:1.0.0
```

### ROCm variant

For AMD GPU environments with [ROCm](https://rocm.docs.amd.com/) support:

```bash
docker run -it -e ANTHROPIC_API_KEY=sk-ant-... jbkirkland/claude-code:rocm-latest
```

Pin to a specific version:

```bash
docker run -it jbkirkland/claude-code:rocm-1.0.0
```

## Setup

To enable automatic publishing, add these secrets to your GitHub repository:

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | A Docker Hub [access token](https://hub.docker.com/settings/security) |

Then push to `main` — the workflow runs on a schedule (every 6 hours) and can also be triggered manually via `workflow_dispatch`.

## Building locally

```bash
docker build -t claude-code .
docker run -it -e ANTHROPIC_API_KEY=sk-ant-... claude-code
```

Build a specific version:

```bash
docker build --build-arg CLAUDE_VERSION=1.0.0 -t claude-code:1.0.0 .
```

Build the ROCm variant:

```bash
docker build -f Dockerfile.rocm -t claude-code:rocm-latest .
```
