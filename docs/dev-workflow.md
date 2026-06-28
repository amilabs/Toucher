# Toucher development workflow

## Build and test

Before finishing behavior changes:

```bash
make check
```

For core-only changes:

```bash
swift test
```

For debug runtime checks:

```bash
make run-debug
make debug-verify-bundle
```

## Git workflow for Codex

Codex should not commit or push without an explicit user request.

When the user explicitly asks to update GitHub, Codex should ask for approval once for the whole git batch, not once per individual git command. After approval, run git commands in one shell block where possible.

Typical batch:

```bash
git status
git add ...
git commit -m "..."
git pull --rebase origin main
git push origin main
```

If the Codex client/tooling enforces per-command approval, group commands into one script block where allowed.

Never commit:

- `.build/`
- `*.app`
- `.DS_Store`
- derived data
- logs

Do not commit build artifacts.
