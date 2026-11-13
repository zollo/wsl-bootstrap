# Migrating to a new Ubuntu WSL2 distro

A generic runbook for moving from one Ubuntu WSL distro (e.g. `Ubuntu-24.04`) to a new one
(e.g. `Ubuntu-26.04`) using this repo. Keep the old distro until the new one has been used
for real work for a while; it costs nothing but disk.

## 0. Before you start (old distro)

- Push or stash every git repository: list unpushed commits and dirty trees with

  ```bash
  for d in ~/*/ ~/*/*/; do [ -d "$d/.git" ] || continue
    printf '%-40s dirty=%s unpushed=%s\n' "$d" \
      "$(git -C "$d" status --porcelain | wc -l)" \
      "$(git -C "$d" log --branches --not --remotes --oneline 2>/dev/null | wc -l)"
  done
  ```

  Untracked/ignored files (state files, keys, `.env`) aren't in git: copy those directories
  whole with the migrate script instead of re-cloning.
- Note anything installed outside apt and this repo: `ls ~/.local/bin /usr/local/bin`,
  `apt-mark showmanual`, `/etc/apt/sources.list.d/`, `crontab -l`, `systemctl --user list-unit-files --state=enabled`.
- Remove secrets from shell startup files (`grep -nE 'PASS|SECRET|TOKEN|KEY' ~/.bashrc ~/.profile`).
- Full backup from PowerShell (distro is stopped by the export):

  ```powershell
  wsl --export Ubuntu-24.04 D:\wsl-backup\Ubuntu-24.04-$(Get-Date -f yyyyMMdd).tar
  ```

## 1. Create and bootstrap the new distro

```powershell
wsl --install Ubuntu-26.04
```

Inside it, follow the README quick start (`./bootstrap.sh`), then `wsl --terminate Ubuntu-26.04`
and reopen. Enable it under Docker Desktop > Settings > Resources > WSL integration.

## 2. Copy data across

Inside the new distro:

```bash
cd ~/wsl-bootstrap
$EDITOR migrate/paths.local.txt                 # add project dirs (one per line, relative to ~)
migrate/pull-from-distro.sh Ubuntu-24.04 --dry-run
migrate/pull-from-distro.sh Ubuntu-24.04
```

## 3. Log in and verify

```bash
gh auth status || gh auth login
./bootstrap.sh git             # gh as git credential helper
bw status                      # "locked" if the copied login state is valid; else bw login
bwu
claude                         # copied ~/.claude* keeps settings, memory and login
./bootstrap.sh check
```

Then exercise real work: `git fetch` in each repo, `ssh` to a host you use, `kubectl get nodes`,
`tofu plan` in a project (state is in the copied project directories).

## 4. Switch the default

```powershell
wsl --set-default Ubuntu-26.04
```

Point Windows Terminal's default profile, VS Code Remote-WSL and Docker Desktop's
integration at the new distro.

## 5. Retire the old distro (weeks later)

```powershell
wsl --export Ubuntu-24.04 D:\wsl-backup\Ubuntu-24.04-final.tar   # last backup
wsl --unregister Ubuntu-24.04                                    # irreversible
```

`--unregister` deletes the distro's virtual disk. Keep the export until you're sure.

## Rollback

Until step 5 the old distro is untouched: `wsl --set-default Ubuntu-24.04` and carry on.
After step 5: `wsl --import Ubuntu-24.04 <dir> <export.tar>`.
