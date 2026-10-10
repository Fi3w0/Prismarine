# Security policy

Security fixes target the latest Prismarine beta and current `main` branch.
Older builds may need to upgrade to receive a fix.

## Report privately

Use [GitHub's private vulnerability reporting](https://github.com/Fi3w0/Prismarine/security/advisories/new).
Do not post exploit details or credentials in a public issue.

Include the Prismarine version or commit, OS, Prism Launcher version, the
smallest safe reproduction, and the potential impact. Remove account tokens,
CurseForge API keys, private server addresses, and personal paths unless they
are essential to reproduce the problem.

Confirmed issues are handled according to severity. This is a solo beta
project, so response and fix times depend on availability.

## Scope

Prismarine downloads and unpacks mods and modpacks, edits instance files,
starts external programs, and optionally stores API keys and a Friends
identity through QtKeychain. Reports involving archive path traversal,
unverified downloads, credential exposure, unsafe file writes, or command
execution across these boundaries are especially useful.

Microsoft sign-in stays in Prism Launcher. If a vulnerability is in Prism
itself, report it through [Prism Launcher's security policy](https://github.com/PrismLauncher/PrismLauncher/security/policy).
