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

## Tailscale Integration

The image includes [Tailscale](https://tailscale.com/) for routing API traffic through your tailnet. This is useful when the Anthropic API is blocked on the node where the container runs.

### Configuration

Copy the example env file and fill in your values:

```bash
cp .env.example .env
```

| Variable | Required | Description |
|---|---|---|
| `TS_AUTHKEY` | Yes | Tailscale auth key ([generate one](https://login.tailscale.com/admin/settings/keys)) |
| `TS_EXIT_NODE` | Yes | Tailscale exit node to route traffic through |
| `TS_HOSTNAME` | No | Node name on your tailnet (default: `claude-code`) |

### Running with Tailscale

Mount your `.env` file into the container:

```bash
docker run -it -v $(pwd)/.env:/.env jbkirkland/claude-code
```

The entrypoint script starts Tailscale in userspace networking mode (no `--privileged` needed), authenticates via your auth key, connects to the specified exit node, and then launches Claude.

Make sure the exit node is [advertising itself](https://tailscale.com/kb/1103/exit-nodes) and approved in the Tailscale admin console.

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
