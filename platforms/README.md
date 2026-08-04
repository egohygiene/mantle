# Platform runtimes

Mantle loads one operating-system adapter after its shared and shell-specific
runtime layers.

| Adapter | Coverage |
| --- | --- |
| `darwin/` | macOS on Apple Silicon and Intel, including discovered Homebrew paths |
| `linux/` | Linux distributions, containers, and WSL |
| `windows/` | MSYS2, Git Bash, and similar Unix-compatible Windows environments |

Platform runtimes are quiet, idempotent, and safe to source repeatedly. They
may expose platform metadata, add existing platform paths, and load
interactive conveniences. They must not install software, prompt, access the
network, request privileges, or mutate operating-system preferences.

Native PowerShell support is outside the current shell-runtime boundary.
Destructive or privileged workstation configuration belongs in an explicit,
reviewable command—not shell startup.
