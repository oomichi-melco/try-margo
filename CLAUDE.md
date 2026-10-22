# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About Margo

Margo is an open standard for edge interoperability in industrial automation, hosted under the Linux Foundation. It defines how edge applications, edge devices, and edge orchestration software interoperate, and provides a specification, a reference implementation, and a compliance testing toolkit.

Official resources:
- Website: https://margo.org/
- Specification: https://specification.margo.org/
- GitHub organization: https://github.com/margo (includes `margo/sandbox`, whose scripts `margo-installer/` uses)

## Directory Structure

This repository is a personal sandbox for trying and testing Margo. Note that the repository root contains a nested `try-margo/` directory, which holds all the actual content.

```
.
├── .github/workflows/pull-request.yml   # CI: the only workflow, runs on PRs to main
└── try-margo/
    ├── application-descriptions/        # Margo ApplicationDescription samples (sample01.yaml)
    ├── margo-installer/                 # Scripts that set up and verify a Margo sandbox (WFM + device agents)
    ├── plugfest202607/apps/             # Applications prepared for the Plugfest
    │   ├── push_container_images.sh     # Tags and pushes built images to ghcr.io (podman)
    │   └── edge-app/                    # The sample edge app and all its deployment variants
    │       ├── main.py, Dockerfile      # Python app and its container image
    │       ├── helm-chart/              # Helm deployment variant
    │       ├── docker-compose/          # Compose deployment variant
    │       ├── application-description/ # margo.yaml referencing the helm and compose variants
    │       └── build_container_image.sh, run_*_tests.sh   # Build and test scripts
    └── tests/install_k3s.sh             # Shared helper that installs single-node k3s if missing
```
