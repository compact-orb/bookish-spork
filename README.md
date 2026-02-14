# bookish-spork

[![CodeFactor](https://www.codefactor.io/repository/github/compact-orb/bookish-spork/badge)](https://www.codefactor.io/repository/github/compact-orb/bookish-spork)

Gentoo binary package build system powered by GitHub Actions. Builds customized binary packages from a set of `/etc` configurations using Clang/LLVM with LTO, and stores images and packages on Bunny Storage.

## Configurations

Each numbered directory contains a complete `/etc` tree for a target system.

| Config | Profile | Arch | `-march`/`-mcpu` | Runner | Description |
| -------- | --------- | ------ | ------------------- | -------- | ------------- |
| `1` | `amd64/23.0/no-multilib/systemd` | amd64 | `x86-64-v3` | `ubuntu-24.04` | General x86_64v3 servers |
| `2` | `amd64/23.0/desktop/gnome/systemd` | amd64 | `goldmont-plus` | `ubuntu-24.04` | Gemini Lake desktop/workstation |
| `3` | `arm64/23.0/systemd` | arm64 | `neoverse-n1` | `ubuntu-24.04-arm` | ARM cloud servers |
| `4` | `arm64/23.0/systemd` | arm64 | `cortex-a55` | `ubuntu-24.04-arm` | Specific Android device |

All configurations use Clang/LLVM toolchain, thin LTO, and build with `-O3`.

## Workflows

Three workflow types exist per configuration, prefixed by the config number:

### `*-bootstrap.yml` — Initial Image Creation

Converts a generic Gentoo stage3 into a customized base image. Run manually via `workflow_dispatch`.

- **Step 1**: Downloads a bootstrap stage3 tarball, applies the configuration, sets the Portage profile, bootstraps Clang/Rust/PyPy from Gentoo binhost, then syncs the tree.
- **Step 2**: Rebuilds the entire `@world` with `--emptytree` using the final configuration. Supports `--resume` for continuing after timeouts.

### `*-bootstrap-update.yml` — Base Image Updates

Updates the base image. Runs on a daily cron schedule and can be triggered manually.

| Input | Purpose |
| ------- | --------- |
| `skip-sync` | Skip `emerge --sync` |
| `skip-update` | Skip `emerge --update @world` |
| `reconfigure` | Re-apply the configuration from the repo |
| `packages` | Only update specific packages (oneshot) |

### `*-emerge-other.yml` — Binary Package Builds

Builds binary packages for packages listed in the corresponding `*-emerge-other.list` file. Uses an OverlayFS layer on top of the base image. Runs on a daily cron schedule (staggered per config).

| Input | Purpose |
| ------- | --------- |
| `ephemeral` | Build without saving the layer |
| `force_rebuild` | Start from a fresh layer |
| `no-update` | Skip `--update` flag |
| `packages` | Override the package list |
| `usepkg-exclude` | Exclude specific packages from using binpkgs |
| `temporary` | Upload the layer as temporary |

## Scripts

CI scripts are in the `scripts/` directory and run on the GitHub Actions host.

### PowerShell

| Script | Purpose |
| -------- | --------- |
| `PushPullImage.ps1` | Downloads/uploads system images (base, bootstrap, temporary, overlay layers) to/from Bunny Storage. Supports OverlayFS for layered images. |
| `PushPullBinaryPackages.ps1` | Syncs binary packages via OverlayFS — downloads existing packages to a read-only lower layer, mounts an overlay for new packages, then uploads only the upper (new) layer. |
| `SetConfiguration.ps1` | Cleans old Portage/kernel/SSH config from the image and copies the repo's configuration. On build nodes, overrides `make.conf` with higher parallelism and `--buildpkg` flags. Also sets up the SSH key for the private overlay repo. |
| `MountFilesystems.ps1` | Mounts/unmounts `proc`, `sys`, `dev`, `run`, `tmp`, and the working directory into the chroot at `/mnt/gentoo`. |
| `DownloadBunnyStorageDirectory.ps1` | Recursively downloads a directory from Bunny Storage with parallel threads and retry logic. Uses CDN endpoint for listing. |
| `UploadBunnyStorageDirectory.ps1` | Recursively uploads a local directory to Bunny Storage with parallel threads and retry logic. Uses CDN endpoint for uploads. |

### Shell

| Script | Purpose |
| -------- | --------- |
| `scripts/BuildPackages.sh` | Core emerge wrapper. Handles bootstrap (step 1 & 2), sync, `@world` update, and package installation. Enforces a 5h30m timeout to stay within the GitHub Actions 6-hour job limit. |
| `scripts/ShowRunnerInfo.sh` | Prints CPU, memory, and disk info for debugging. |
| `tools/ConfigureSystem.sh` | Client-side script for applying a configuration to a live Gentoo system. Cleans existing Portage config directories and copies the specified configuration. |

## Repository Secrets

| Secret | Purpose |
| -------- | --------- |
| `BUNNY_STORAGE_ACCESS_KEY` | API key for Bunny Storage authentication |
| `BUNNY_STORAGE_CDN` | CDN pull zone with the storage zone as the origin |
| `BUNNY_STORAGE_ENDPOINT` | Standard storage API endpoint (used for downloads) |
| `BUNNY_STORAGE_ENDPOINT_CDN` | CDN pull zone with storage API endpoint as origin (used for listing and uploads — more reliable?) |
| `BUNNY_STORAGE_ZONE_NAME` | Storage zone name |
| `REDESIGNED_BROCCOLI_SSH_KEY` | Base64-encoded SSH key for authenticating that private overlay repository |

## Client Setup

To consume the binary packages on a Gentoo system:

```bash
git clone <this-repo>
cd bookish-spork
sudo bash tools/ConfigureSystem.sh <config-number>
```

This replaces Portage configuration directories with the selected configuration. The `make.conf` in each config sets `--getbinpkgonly` by default, so the client will only install pre-built binary packages.

> **Note**: You will need to configure `binrepos.conf` on the client to point to your Bunny Storage CDN URL serving the binary packages for the corresponding config prefix.

## Maintenance Notes

- **Adding/removing config files**: Update `cleanup-paths.txt` to match. Both `scripts/SetConfiguration.ps1` and `tools/ConfigureSystem.sh` read from this shared file.
- **Adding a new configuration**: Create a new numbered directory with `/etc` tree, a `*-emerge-other.list`, and duplicate/adjust the three workflow files with the correct `CONFIG_PREFIX`, `BOOTSTRAP_BINREPOS_ARCHITECTURE`, runner, and Portage profile.
- **Build timeouts**: `scripts/BuildPackages.sh` has a 5h30m timeout. If an emerge times out, the step 2 bootstrap and emerge-other workflows support `--resume`.
- **Bootstrap step 1 specifics**: The bootstrap process installs Clang, Rust, PyPy, and Portage from Gentoo's official binhost before rebuilding. If the toolchain bootstrap changes, update `scripts/BuildPackages.sh` case `1`.
