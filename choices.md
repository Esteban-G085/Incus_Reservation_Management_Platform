# Choices and Changes Log

This file documents the current state of the Incus microservices lab repository and logs all changes for traceability. Updates follow the KISS principle (Keep It Simple, Stupid) for simplicity and maintainability.

## Current Repository State (May 18, 2026)

### Project Overview

- **Purpose**: Containerized microservices lab for a reservation management platform using Incus on Debian 13.
- **Infrastructure**: 6 containers (ctl, api, core, db, mon, ceph) with resource profiles, OVN network, and persistent volumes.
- **Tools**: Incus for containers, Bash scripts for IaC (replaces OpenTofu), Ansible for configuration (executed via scripts).

### Files and Structure

```text
Incus_Reservation_Management_Platform/
├── README.md                   # Main project documentation
├── infraestructura.md          # Technical decision document (Spanish)
├── memory.md                   # Installation and profile guide
├── setupnetwork.md             # OVN network setup reference
├── install_log.txt             # Quick setup reference
├── deploymentcommand.txt       # Single-line deployment command
├── wlsclone.py                 # WSL clone utility
├── scripts/
│   ├── incusinstall.sh         # Automated Incus installation
│   ├── network.sh              # OVN network creation
│   ├── profiles.sh             # Profile creation (simplified names)
│   ├── volumes.sh              # Persistent volumes creation
│   ├── containers.sh           # Container launching and configuration
│   ├── setup-services.sh       # Ansible-based service configuration
│   ├── setup-api.sh            # API specific setup script
│   ├── setup-db.sh             # DB specific setup script
│   ├── setup-lab.sh            # Full infrastructure deployment (calls other scripts)
│   ├── start-services.sh       # Script to start inner container services
│   ├── startup.sh              # Orchestrated lab startup script
│   ├── shutdown.sh             # Orchestrated lab shutdown script
│   ├── validate.sh             # System validation script
│   └── validate-services.sh    # Services validation script
└── choices.md                  # This file (changes log)
```

### Infrastructure Components

- **Profiles**: ctl (1 CPU, 512 MiB), api (2 CPU, 1024 MiB), core (2 CPU, 1536 MiB), db (4 CPU, 4096 MiB), mon (2 CPU, 1024 MiB), ceph (2 CPU, 2048 MiB) - each with root disk from default pool
- **Network**: OVN network `lab-net` (10.10.0.0/24)
- **Volumes**: postgres-data, prometheus-data, grafana-data, ceph-data, app-data
- **Containers**: Launched via `scripts/containers.sh` with volumes attached

### Deployment Status

- ✅ Incus installation and initialization
- ✅ Profiles created with resource limits
- ✅ OVN network configured
- ✅ Persistent volumes created
- ✅ Containers launched and configured
- ✅ Service configuration (Ansible via `setup-services.sh`)
- ✅ Validation scripts implemented
- ❌ OpenTofu IaC (Discarded in favor of bash scripts for simplicity)

## Changes Log

### May 18, 2026 | Added detailed explanations of scripts in infraestructura.md | infraestructura.md | Ensure the technical document clearly explains what each script does under the hood without hardcoding the logic inline

### May 18, 2026 | Deleted incussetup.md | incussetup.md | Removed redundant file as installation is covered by `incusinstall.sh` and profile management is documented in `infraestructura.md`

### May 18, 2026 | Updated infraestructura.md to reference bash scripts | infraestructura.md | Reflect the architectural shift from OpenTofu/inline scripts to a modular bash approach in `scripts/`. Replaced node names with shortened versions (e.g. `app-api` to `api`)

### May 13, 2026 | Added volume existence checks in containers.sh before adding devices | scripts/containers.sh | Prevent device validation errors by checking if storage volumes exist before attaching them

### May 13, 2026 | Modified containers.sh to skip launching containers that already exist | scripts/containers.sh | Prevent script failure by checking container existence before launch and continuing with next

### May 13, 2026 | Fixed volume source paths in containers.sh to use pool/volume format | scripts/containers.sh | Correct device validation errors by specifying default pool for volume sources

### May 13, 2026 | Updated containers.sh to use correct launch syntax with images:debian/13 and -p default | scripts/containers.sh | Ensure containers launch with proper image source and default profile applied

### May 13, 2026 | Added root disk device to all profiles in profiles.sh | scripts/profiles.sh, choices.md | Ensure profiles have root storage from default pool for proper container mounting

### May 13, 2026 | Made network.sh dynamic to detect incusbr0 subnet and set OVN/DHCP ranges | scripts/network.sh | Handle varying bridge subnets in Incus to prevent IP range parsing errors

### May 13, 2026 | Updated network.sh with full OVN setup and changed lab-net to 10.100.0.0/24 | scripts/network.sh, choices.md | Properly configure OVN for Incus on Debian to prevent network creation failures, based on setupnetwork.md

### May 13, 2026 | Restructured setup-lab.sh to call separate scripts for each stage | scripts/setup-lab.sh, scripts/network.sh, scripts/volumes.sh, scripts/containers.sh | Modularize setup process for easier debugging and maintenance

### May 13, 2026 | Created instructions.md for workspace rules | instructions.md | Establish guidelines for consistency and traceability

### May 13, 2026 | Created .github/instructions/instructions.instructions.md | .github/instructions/instructions.instructions.md | Proper VS Code agent instructions file with extracted rules from conversation

**Log Format**: Date | Change Description | Files Affected | Rationale
