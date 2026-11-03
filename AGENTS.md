# Project instructions

## Superpowers

Superpowers is installed locally in `.superpowers/`. Its skills are exposed to
Codex through directory junctions named `.agents/skills/superpowers-*`.

At the start of each session, read
`.superpowers/skills/using-superpowers/SKILL.md` and follow its instructions.
For Codex tool adaptations, read the referenced `references/codex-tools.md`.
Read and apply the relevant skill before starting a task, including
`brainstorming` for new features, `systematic-debugging` for bugs, and
`verification-before-completion` before reporting completion. Follow higher
priority system/developer instructions and the user's explicit instructions
when they conflict with a skill.

The checkout and junctions are local installation artifacts, ignored by Git.
To install them again on Windows, run from this repository root:

```powershell
git clone --depth 1 https://github.com/obra/superpowers.git .superpowers
New-Item -ItemType Directory -Path .agents/skills -Force | Out-Null
Get-ChildItem -LiteralPath .superpowers/skills -Directory | ForEach-Object {
    $skillSource = $_.FullName
    $skillLink = Join-Path '.agents/skills' ('superpowers-' + $_.Name)
    if (-not (Test-Path -LiteralPath $skillLink)) {
        New-Item -ItemType Junction -Path $skillLink -Target $skillSource | Out-Null
    }
}
```

To update the installed skills, run `git -C .superpowers pull --ff-only`, then
repeat the junction creation commands above to expose any newly added skills.
Start a new Codex session to refresh automatic skill discovery after installation
or updates. If the local checkout is missing, restore it using the commands above
before trying to read its skills.
