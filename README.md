# claude-image

Auto-published Docker image with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`@anthropic-ai/claude-code`) pre-installed.

A GitHub Actions workflow checks npm every 6 hours and pushes a new image to Docker Hub whenever a new version is released.

## Tags

| Tag | Description |
|---|---|
| `latest` / `<version>` | Base image |
| `rocm-latest` / `rocm-<version>` | AMD GPU with [ROCm](https://rocm.docs.amd.com/) |
| `tailscale-latest` / `tailscale-<version>` | Base + Tailscale networking |
| `rocm-tailscale-latest` / `rocm-tailscale-<version>` | ROCm + Tailscale networking |

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

## Tailscale Integration

The `tailscale` tagged images include [Tailscale](https://tailscale.com/) and [proxychains4](https://github.com/rofl0r/proxychains-ng) for routing API traffic through your tailnet. This is useful when the Anthropic API is blocked on the node where the container runs.

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

### Running with Tailscale (Docker)

```bash
docker run -it -v $(pwd)/.env:/.env jbkirkland/claude-code:tailscale-latest
```

The entrypoint starts Tailscale in userspace networking mode (no `--privileged` needed), authenticates via your auth key, connects to the specified exit node, and launches Claude through `proxychains4`.

Make sure the exit node is [advertising itself](https://tailscale.com/kb/1103/exit-nodes) and approved in the Tailscale admin console.

### Singularity / Apptainer (HPC)

Pull the image:

```bash
export APPTAINER_CACHEDIR=/ddn_scratch/$USER/.apptainer_cache
singularity pull /ddn_scratch/$USER/claude-code-tailscale.sif docker://jbkirkland/claude-code:tailscale-latest
```

Run with Tailscale:

```bash
singularity run --nv \
  --writable-tmpfs \
  --bind /ddn_scratch:/ddn_scratch \
  --bind ~/repos/claude-image/.env:/.env \
  /ddn_scratch/$USER/claude-code-tailscale.sif --dangerously-skip-permissions
```

`--writable-tmpfs` is required so `tailscaled` can write to its state directories. To persist Tailscale state across runs (avoids re-auth each time):

```bash
mkdir -p /ddn_scratch/$USER/.tailscale-state

singularity run --nv \
  --writable-tmpfs \
  --bind /ddn_scratch:/ddn_scratch \
  --bind ~/repos/claude-image/.env:/.env \
  --bind /ddn_scratch/$USER/.tailscale-state:/var/lib/tailscale \
  /ddn_scratch/$USER/claude-code-tailscale.sif --dangerously-skip-permissions
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

Build the Tailscale variant:

```bash
docker build -f Dockerfile.tailscale -t claude-code:tailscale-latest .
```
