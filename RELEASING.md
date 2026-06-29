# Releasing Sel01-Tweaker

**Rule: every big update gets a version bump everywhere + a GitHub release.**
Use [Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

- **MAJOR** - breaking change (removed flag, changed revert format).
- **MINOR** - new module/feature (e.g. a new tweak module). ← most of our updates.
- **PATCH** - bug fix / tweak adjustment, no new feature.

## Single source of truth

The version lives in **one place**: `Version = '...'` in `src/lib/Common.ps1`.
It shows in the console banner and the run log. Everything else (tag, release
title, zip) derives from it.

## One-command release (preferred)

```powershell
.\release.ps1 -Version 1.1.0
```

This automatically:
1. writes `1.1.0` into `src/lib/Common.ps1`
2. rebuilds `dist/Sel01Tweaker.ps1`
3. packages `release/Sel01-Tweaker.zip`
4. commits `release: v1.1.0`, tags `v1.1.0`, pushes `main` + tag
5. creates the GitHub release (zip + single-file script + `release/NOTES.md`)

Auth reuses the token already stored for `git push` (Credential Manager) - no
separate `gh auth login` needed.

> Before running: update `release/NOTES.md` with the highlights for this version
> (it becomes the release body), and tick the new work in `PROGRESS.md`.

## Manual checklist (if not using release.ps1)

1. Bump `Version` in `src/lib/Common.ps1`.
2. Update `release/NOTES.md`, `PROGRESS.md`, and `README.md` if usage changed.
3. `.\build.ps1` and run `.\tests\run-checks.ps1` - must pass.
4. `git add -A && git commit -m "release: vX.Y.Z"`
5. `git tag -a vX.Y.Z -m "Sel01-Tweaker vX.Y.Z" && git push origin main --tags`
6. `gh release create vX.Y.Z release\Sel01-Tweaker.zip dist\Sel01Tweaker.ps1 --title "Sel01-Tweaker vX.Y.Z" --notes-file release\NOTES.md`

## After release

- Verify: `gh release view vX.Y.Z --repo seltonmt012/Sel01-Tweaker`
- Bump `Version` is already done; the next dev work happens on top of it.
