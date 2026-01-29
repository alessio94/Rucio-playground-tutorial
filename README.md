# Getting Started with the Rucio Docker Playground

> **Overview:** This tutorial walks you through setting up a complete Rucio test environment using Docker Compose. The playground includes 17 containers with XRootD servers, MinIO S3 storage, FTS (File Transfer Service), and a full Rucio stack for testing data replication and multi-hop transfers.

## Prerequisites

Before starting, ensure you have the following installed:

- **Docker** (with Docker Compose support)
- **Basic understanding of Rucio concepts** (RSEs, replication rules, datasets)

> [!NOTE]
> All Rucio CLI commands run inside Docker containers -- no local Rucio or Python installation is required.

## Tutorial Scripts Overview

This tutorial uses a series of numbered scripts that progressively set up and configure your Rucio playground environment. Each script builds on the previous one to create a fully functional test infrastructure.

A Jupyter notebook version of the tutorial (`rucio-playground-tutorial.ipynb`) is also available for interactive use.

### Quick Start

```bash
./qt-000-up.sh          # Start the environment
./qt-replay.sh          # Run all tutorial steps (000-008) sequentially
```

Or run each step individually -- see below.

---

## Environment Management Scripts

### qt-000-up.sh -- Start the Environment

Launches the complete Docker Compose stack with all storage services and the Rucio infrastructure.

```bash
./qt-000-up.sh
```

**What it does:**

- Generates MinIO SSL certificates (`etc/certs/generate_minio12.sh`)
- Starts 17 containers including:
  - XRootD servers (XRD1, XRD2, XRD3)
  - MinIO instances (MINIO1, MINIO2)
  - File Transfer Service (FTS)
  - Rucio server and daemons
  - PostgreSQL database

### qt-999-down.sh -- Clean Up Environment

Stops and removes all Docker containers, volumes, and resources from the Rucio playground. Use this to start fresh or clean up after testing.

```bash
./qt-999-down.sh
```

**What it does:**

- Stops all running containers via `docker compose down`
- Prunes orphaned containers
- Attempts to clean up unused volumes

> [!WARNING]
> **Volume Persistence Issue:** The `docker volume prune -f` command only removes unused volumes, not the ones that might still be referenced. PostgreSQL database volumes persist between runs, keeping old schema objects.
>
> To completely clean up, you may need to manually remove specific volumes:
> ```bash
> docker volume rm dev_vol-ruciodb-data1 2>/dev/null
> docker volume rm dev_vol-ftsdb-mysql1 2>/dev/null
> ```

---

## Configuration Scripts

### qt-001-initialize.sh -- Initialize Rucio

Runs the Rucio initialization and test script that sets up the basic Rucio infrastructure inside the `dev-rucio-1` container.

```bash
./qt-001-initialize.sh
```

**What it does:**

Executes `tools/run_tests.sh -ir` inside the Rucio container, which:

- Creates the database schema and default account (`root`)
- Creates test scopes and initial datasets
- Registers XRootD RSEs (XRD1, XRD2, XRD3)
- Sets up basic RSE attributes and protocol endpoints

### qt-002-xrd3-http-protocol.sh -- Add HTTPS Protocol to XRD3

Adds HTTPS protocol support to the XRD3 RSE, enabling it to communicate with S3 backends for multi-hop transfers.

```bash
./qt-002-xrd3-http-protocol.sh
```

**What it does:**

- Configures HTTPS protocol on XRD3 using `rucio.rse.protocols.gfal.Default`
- Enables S3 compatibility for multi-hop routing
- Sets protocol priorities for WAN and LAN operations (read, write, delete, third-party copy)

### qt-003-minio-buckets.sh -- Create MinIO Buckets

Creates the necessary storage buckets on both MinIO instances using the MinIO Client (`mc`).

```bash
./qt-003-minio-buckets.sh
```

**What it does:**

- Configures MinIO Client aliases for each instance (`dev-minio-1` on port 9001, `dev-minio-2` on port 9002)
- Creates the `rucio` bucket on both MinIO instances
- Verifies bucket creation with `mc ls`

### qt-004-minio-rses.sh -- Configure MinIO RSEs

Registers MinIO instances as Rucio Storage Elements with S3 protocol configuration.

```bash
./qt-004-minio-rses.sh
```

**What it does:**

- Registers **MINIO1** and **MINIO2** as Rucio RSEs
- Configures S3 protocol endpoints using `rucio.rse.protocols.gfal.NoRename` (S3 does not support rename)
- Sets RSE attributes: `sign_url=s3`, `s3_url_style=path`, checksum/upload/copy settings
- Configures FTS endpoint (`https://fts:8446`) for each RSE
- Sets infinite storage quota for the `root` account
- Establishes bidirectional network distances (distance=1) between MinIO RSEs and XRD3 for multi-hop routing
- Writes S3 credentials (`rse-accounts.cfg`) keyed by RSE ID

> [!TIP]
> **Understanding RSE Distance:** RSE distance determines routing for data transfers. A distance of 1 means direct transfer is possible. Setting distances between MINIO RSEs and XRD3 enables multi-hop transfers through XRD3.

### qt-005-minio-fts-creds.sh -- Configure FTS Credentials

Registers S3 storage credentials in the File Transfer Service (FTS).

```bash
./qt-005-minio-fts-creds.sh
```

**What it does:**

- Registers cloud storage endpoints (`S3:minio1`, `S3:minio2`) in FTS via REST API
- Supplies S3 access credentials for the `/CN=Rucio User` DN
- Writes GFAL2 S3 configuration (`/etc/gfal2.d/s3.conf`) with access keys, secret keys, and region

> [!NOTE]
> **What is FTS?** FTS (File Transfer Service) is responsible for executing actual data transfers between storage endpoints. It handles authentication, retries, checksums, and provides monitoring for transfers.

---

## Data Management Scripts

### qt-006-simple-upload.sh -- Upload Test Data

Creates and uploads initial test files to MinIO instances.

```bash
./qt-006-simple-upload.sh
```

**What it does:**

- Generates two 10 MB random files (`file5`, `file6`)
- Uploads `file5` to **MINIO1** and `file6` to **MINIO2** under the `test` scope
- Creates a dataset DID (`test:dataset9`)
- Attaches both files to the dataset

### qt-007-replication-rules.sh -- Create Replication Rules

Creates replication rules to trigger data transfers between storage endpoints.

```bash
./qt-007-replication-rules.sh
```

**What it does:**

- Creates a rule to replicate `test:dataset9` (1 copy) to **XRD1** -- triggers S3-to-XRootD multi-hop transfers
- Creates a rule to replicate `test:dataset2` (1 copy) to **MINIO2**

### qt-008-replicte-loop.sh -- Execute Replication Cycle

Runs a single iteration of the Rucio replication cycle to process pending transfers.

```bash
./qt-008-replicte-loop.sh
```

**What it does:**

- Lists current rules (`rucio rule list --account root`)
- Executes the four conveyor daemons in sequence:
  1. `rucio-judge-evaluator --run-once` -- evaluates pending replication rules
  2. `rucio-conveyor-submitter --run-once` -- submits transfer requests to FTS
  3. `rucio-conveyor-poller --run-once --older-than 0` -- polls FTS for transfer status
  4. `rucio-conveyor-finisher --run-once` -- finalizes completed transfers
- Lists rules again to show state changes

> [!NOTE]
> **Running Continuously:** In a production environment, these daemons run continuously. This script executes a single cycle for testing purposes. You may need to run it multiple times to see transfers complete.

---

## Utility Scripts

### qt-replay.sh -- Run All Tutorial Steps

Runs all numbered tutorial steps (000 through 008) sequentially in a single command.

```bash
./qt-replay.sh
```

### qt-enter.sh -- Interactive Container Shell

Opens an interactive bash shell inside the `dev-rucio-1` container for debugging and exploration.

```bash
./qt-enter.sh
```

Useful commands once inside the container:

```bash
rucio list-file-replicas test:dataset1
rucio list-file-replicas test:dataset9
rucio rule list --account root
rucio rse show MINIO1
```

---

## Multi-Hop Transfer Flow

The playground demonstrates multi-hop transfers where data flows from MinIO through XRD3 to XRootD destinations:

```
User creates replication rule
        │
        ▼
Judge Evaluator processes rule
        │
        ▼
Conveyor submits transfer to FTS
        │
        ▼
FTS orchestrates multi-hop transfer:
   MINIO1/2 ──(S3→HTTPS)──▶ XRD3 ──(XRootD)──▶ XRD1/2
```

---

## Reference Documentation

- [Rucio Documentation](https://rucio.cern.ch/documentation)
- [S3 RSE Configuration](https://rucio.github.io/documentation/operator/s3_rse_config/)
- [FTS3 S3 Support](https://fts3-docs.web.cern.ch/fts3-docs/docs/s3_support.html)
- [EGI Data Transfer Tutorial](https://docs.egi.eu/users/tutorials/adhoc/data-transfer-object-storage/)
- [Rucio K8s Tutorial](https://github.com/rucio/k8s-tutorial)
- [Rucio Docker Dev Environment](https://github.com/rucio/rucio/tree/master/etc/docker/dev)
