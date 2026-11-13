#!/bin/sh
# Re-register WSL's Windows-interop binfmt entry if another distro's shutdown
# removed it (binfmt_misc is shared by all distros in the WSL VM). Installed as
# /usr/local/sbin/wsl-interop-heal, run by wsl-interop-heal.timer.
f=/proc/sys/fs/binfmt_misc
[ -e "$f/WSLInterop" ] && exit 0
[ -w "$f/register" ] || exit 0
echo ':WSLInterop:M::MZ::/init:P' > "$f/register" && echo "re-registered WSLInterop"
