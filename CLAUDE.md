# CLAUDE.md - AI Assistant Guide for Rucio Playground Tutorial

## Project Overview

This is a **Rucio Playground Tutorial** -- a collection of sequential shell scripts that walk through setting up and operating a complete Rucio data management environment using Docker containers. Rucio is a scientific data management framework used to organize, manage, and access large volumes of scientific data across distributed storage systems. This tutorial demonstrates the complete lifecycle: environment setup, storage registration, data upload, replication policies, and automated transfer execution.

## Repository Structure

```
Rucio-playground-tutorial/
├── README.md                        # General Rucio project description
├── CLAUDE.md                        # This file
├── qt-000-up.sh                     # Step 0: Generate certs, start Docker environment
├── qt-001-initialize.sh             # Step 1: Initialize Rucio (run tests)
├── qt-002-xrd3-http-protocol.sh     # Step 2: Add HTTPS protocol to XRD3 RSE
├── qt-003-minio-buckets.sh          # Step 3: Create MinIO S3 buckets
├── qt-004-minio-rses.sh             # Step 4: Register MinIO RSEs and configure S3 attributes
├── qt-005-minio-fts-creds.sh        # Step 5: Configure FTS3 cloud storage credentials
├── qt-006-simple-upload.sh          # Step 6: Create test files and upload to RSEs
├── qt-007-replication-rules.sh      # Step 7: Create data replication rules
├── qt-008-replicte-loop.sh          # Step 8: Execute judge/conveyor transfer pipeline
├── qt-999-down.sh                   # Teardown: Stop containers, prune volumes
├── qt-enter.sh                      # Utility: Open interactive shell in Rucio container
└── qt-replay.sh                     # Utility: Run all tutorial steps (000-008) sequentially
```

## Key Conventions

### File Naming

- All scripts follow the pattern `qt-XXX-description.sh` (qt = quickstart tutorial)
- Scripts numbered `000`-`008` are the sequential tutorial steps
- Script `999` is the teardown/cleanup step
- Utility scripts (`qt-enter.sh`, `qt-replay.sh`) have no numeric prefix beyond `qt-`
- All scripts are Bash (`#!/bin/bash`)

### Script Architecture

- Scripts execute commands **inside Docker containers** using `docker exec -i <container> /bin/bash`
- Heredocs (`<<END` / `<<'END'`) are used to pass multi-line command blocks into containers
- Quoted heredocs (`<<'END'`) prevent shell variable expansion on the host (used when `$` variables should expand inside the container)
- Unquoted heredocs (`<<END`) allow host-side variable expansion
- Scripts change directory to their own location: `cd \`dirname $0\``

### Docker Containers

The tutorial uses these Docker containers (defined in an external docker-compose file):
| Container | Service |
|-----------|---------|
| `dev-rucio-1` | Main Rucio server (CLI commands, daemons, uploads) |
| `dev-minio-1` | MinIO S3 storage instance 1 (port 9001) |
| `dev-minio-2` | MinIO S3 storage instance 2 (port 9002) |
| `dev-fts-1` | FTS3 file transfer service |

### External Dependencies (Not in This Repo)

- `etc/docker/dev/docker-compose-qt.yml` -- Docker Compose file (from Rucio project)
- `etc/certs/generate_minio12.sh` -- Certificate generation script
- Rucio Docker dev environment: https://github.com/rucio/rucio/tree/master/etc/docker/dev

## Rucio Concepts Demonstrated

### RSEs (Replica Storage Elements)
Storage backends registered with Rucio:
- **MINIO1** / **MINIO2**: S3-compatible MinIO storage with `gfal.NoRename` protocol
- **XRD3**: XRootD storage with HTTPS protocol enabled for multihop transfers

### DIDs (Data Identifiers)
Named data objects using `scope:name` format (e.g., `test:file5`, `test:dataset9`).

### Replication Rules
Policies that specify where data should be replicated (e.g., `rucio rule add test:dataset9 --copies 1 --rses XRD1`).

### Conveyor Pipeline
The data transfer pipeline runs as a sequence of Rucio daemons:
1. `rucio-judge-evaluator` -- Evaluates rules and creates transfer requests
2. `rucio-conveyor-submitter` -- Submits transfers to FTS3
3. `rucio-conveyor-poller` -- Polls FTS3 for transfer status
4. `rucio-conveyor-finisher` -- Finalizes completed transfers

## Tutorial Execution

### Run All Steps
```bash
./qt-replay.sh          # Runs scripts qt-000 through qt-008 in order
```

### Run Individually (Step by Step)
```bash
./qt-000-up.sh          # Start environment
./qt-001-initialize.sh  # Initialize Rucio
./qt-002-xrd3-http-protocol.sh
./qt-003-minio-buckets.sh
./qt-004-minio-rses.sh
./qt-005-minio-fts-creds.sh
./qt-006-simple-upload.sh
./qt-007-replication-rules.sh
./qt-008-replicte-loop.sh
```

### Inspect & Debug
```bash
./qt-enter.sh           # Opens interactive bash in dev-rucio-1 container
```

### Teardown
```bash
./qt-999-down.sh        # Stops containers, prunes containers and volumes
```

## Development Guidelines

### Adding New Tutorial Steps

1. Create a new script following the naming pattern: `qt-0XX-description.sh`
2. Start with `#!/bin/bash` shebang
3. Use `docker exec -i <container> /bin/bash <<END ... END` to run commands inside containers
4. Use quoted heredocs (`<<'END'`) when shell variables should be expanded inside the container, not on the host
5. Update `qt-replay.sh` if the new step number exceeds the current glob range (`{0..8}`)
6. Keep scripts idempotent where possible

### Modifying Existing Steps

- Scripts must remain independently runnable (no shared state between script files beyond Docker container state)
- Maintain the sequential numbering -- later scripts depend on earlier ones having run
- Credentials are hardcoded for demo purposes (`admin`/`password`) -- this is intentional for a tutorial environment

### Important Notes

- No CI/CD pipeline exists -- this is a hands-on tutorial, not a production project
- No unit tests exist in this repo; testing is done via Rucio's built-in test suite (`tools/run_tests.sh -ir`) inside the container
- The `qt-008-replicte-loop.sh` filename contains a typo ("replicte" instead of "replicate") -- preserve this for backward compatibility unless explicitly asked to rename
- Error handling is minimal by design -- scripts are meant to be run interactively and observed
- All `docker exec` calls use `-i` (interactive stdin) but not `-t` (pseudo-TTY), except `qt-enter.sh` which uses `-it` for interactive shell access

## Reference Documentation

- Rucio Documentation: https://rucio.cern.ch/documentation
- S3 RSE Configuration: https://rucio.github.io/documentation/operator/s3_rse_config/
- FTS3 S3 Support: https://fts3-docs.web.cern.ch/fts3-docs/docs/s3_support.html
- EGI Data Transfer Tutorial: https://docs.egi.eu/users/tutorials/adhoc/data-transfer-object-storage/
- K8s Tutorial (referenced in scripts): https://github.com/rucio/k8s-tutorial
- Rucio Docker Dev Environment: https://github.com/rucio/rucio/tree/master/etc/docker/dev
