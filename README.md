# wsl-bootstrap

Idempotent bootstrap for an Ubuntu 26.04 WSL2 distro used for infrastructure
work: Kubernetes, OpenTofu, Packer, Bitwarden, GitHub CLI, Claude Code. Every
step can be re-run at any time and skips what is already in place.

## Quick start

From Windows (PowerShell):

```powershell
wsl --install Ubuntu-26.04          # creates the distro and prompts for a Linux user
```

Inside the new distro:

```bash
git clone https://github.com/zollo/wsl-bootstrap.git ~/wsl-bootstrap
cd ~/wsl-bootstrap
cp bootstrap.local.conf.example bootstrap.local.conf   # optional: git identity, Windows links
./bootstrap.sh
```

Then, from PowerShell, `wsl --terminate Ubuntu-26.04` once so the `/etc/wsl.conf` changes
(systemd, default user) apply. Open a new shell and run `./bootstrap.sh check`.

## What it does

| Step | Script | What |
|---|---|---|
| `wsl-conf` | `steps/10-wsl-conf.sh` | `/etc/wsl.conf`: systemd on, default user, Windows interop + PATH; `wsl-interop-heal.timer` (see Troubleshooting) |
| `apt` | `steps/20-apt.sh` | full upgrade, `config/apt-packages.txt`, GitHub CLI from cli.github.com |
| `apt-optional` | `steps/20-apt.sh optional` | `config/apt-packages-optional.txt` (only when asked) |
| `tools` | `steps/30-tools.sh` | pinned binaries into `~/.local/bin`, checksum-verified (see below) |
| `dotfiles` | `steps/40-dotfiles.sh` | `~/.bashrc.d/*.sh` + one sourcing block in `~/.bashrc`; Windows-side symlinks |
| `git` | `steps/50-git.sh` | sane git defaults, identity from local config, `gh auth setup-git` |
| `claude` | `steps/60-claude.sh` | Claude Code via the official native installer |
| `check` | `steps/90-check.sh` | read-only report: versions, systemd, Docker, gh/bw login state |

Run a subset: `./bootstrap.sh tools check`. Reinstall pinned tools: `FORCE=1 ./bootstrap.sh tools`.

### Pinned tools (`versions.env`)

kubectl, helm, OpenTofu, Packer, Bitwarden CLI (`bw`), Bitwarden Secrets Manager CLI (`bws`),
mikefarah `yq`. Each download is verified against the project's published checksum file, or
against a hash pinned in `versions.env` where none is published (bw, yq). To upgrade: bump the
version (and hash, where pinned), then `./bootstrap.sh tools`.

Tools live in `~/.local/bin`, so updating them never needs root.

### Shell config (`dotfiles/bashrc.d/`)

- `00-path.sh`: `~/.local/bin` on `PATH`
- `10-aliases.sh`: `k`, `tf`, `gs`, `gl`, `explorer`
- `20-completion.sh`: bash completion for kubectl (and `k`), helm, gh, yq, tofu, packer
- `30-bitwarden.sh`: `bwu` (unlock, export `BW_SESSION`, save it to `~/.config/bw/session`
  mode 600) and `bwl` (lock and delete it)

Put your own snippets in `~/.bashrc.d/*.local.sh`; the bootstrap never touches those.

**Secrets never go in dotfiles.** Run `bw login` once (the login persists in
`~/.config/Bitwarden CLI`), then `bwu` per session. Don't export a master password, API client
secret or session key from `~/.bashrc`: every process you start can read your environment.

### Docker

Docker comes from Docker Desktop on Windows, not from apt: Docker Desktop > Settings >
Resources > WSL integration > enable the distro. `./bootstrap.sh check` reports whether it's
reachable.

## Migrating from another distro

`migrate/pull-from-distro.sh` runs **inside the new distro** and streams `$HOME` paths out of
the old one through `wsl.exe -d <old> -- tar`, so nothing is staged on the Windows drive.
Permissions and symlinks are kept; existing files in the new distro are kept unless
`--overwrite`.

```bash
migrate/pull-from-distro.sh Ubuntu-24.04 --dry-run     # what would be copied, with sizes
migrate/pull-from-distro.sh Ubuntu-24.04
```

- `migrate/paths.txt`: the default set (SSH keys, gh/Bitwarden/kube/helm/packer config,
  Claude Code state, shell history).
- `migrate/paths.local.txt` (gitignored): add your project directories here.
- `migrate/excludes.txt` (+ gitignored `migrate/excludes.local.txt`): always skipped. That includes `~/.config/bw/session`, because a
  saved Bitwarden session key unlocks the whole vault.

See [docs/MIGRATION.md](docs/MIGRATION.md) for the full runbook.

## Troubleshooting

**`wsl.exe`/`code`/`explorer.exe` fail with "Exec format error"**: Windows interop's
binfmt_misc entry was dropped. All distros share one VM, and stopping one distro (seen with
`wsl --terminate`/`--export`/`--unregister` of Ubuntu 26.04) can remove the entry for every
distro. In a bootstrapped distro `wsl-interop-heal.timer` re-registers it within ~30 s
(`journalctl -u wsl-interop-heal` shows each repair). Anywhere else, restore it with:

```bash
sudo sh -c 'echo ":WSLInterop:M::MZ::/init:P" > /proc/sys/fs/binfmt_misc/register'
```

or restart the affected distro (`wsl --terminate <distro>` from PowerShell).

**`systemd` not running** (check says "NOT pid 1"): `/etc/wsl.conf` changed and the distro
wasn't restarted. `wsl --terminate <distro>`, then open it again.

**The Claude Code installer says `~/.local/bin` isn't on PATH**: it is once the new shell
config loads; open a new shell.

## Layout

```
bootstrap.sh                   entry point
versions.env                   pinned versions + hashes
bootstrap.local.conf.example   personal settings template (copy to bootstrap.local.conf)
config/                        wsl.conf, apt package lists
dotfiles/bashrc.d/             shell snippets
lib/common.sh                  shared helpers
steps/                         one script per step
migrate/                       copy $HOME data from another distro
docs/MIGRATION.md              migration runbook
```

## License

MIT
