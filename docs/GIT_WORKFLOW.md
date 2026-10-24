# GRIVIO — Git Workflow

How commits are written and how changes reach GitHub.

## Commit messages (Conventional Commits)

```
<type>(<scope>): <short imperative summary>

<optional body: why, and anything a reviewer should know>
```

Types used in this repo:

| Type | When |
| --- | --- |
| `feat` | adds or imports working application code |
| `fix` | repairs behavior |
| `test` | test-only changes |
| `docs` | documentation **and** explanatory comment-only changes |
| `chore` | tooling/ignore files, no product change |

Rules:

- One commit = one understandable logical change.
- Never use `feat:` for comment-only or doc-only changes.
- Never fabricate history — this repo's first commits are honest single
  snapshots ("import …") rather than replayed per-phase history.
- Never write `update`, `changes`, `fix stuff`, `final`.

## Branching

- `main` — always working: analysis clean, tests green.
- Feature branches for anything non-trivial: `feat/<name>`, `fix/<name>`,
  `docs/<name>`. Merge back after verification.

## Pushing

```powershell
git status                       # know exactly what is changing
git add <specific paths>         # never `git add -A` blindly
git diff --cached                # review the staged diff before EVERY commit
git commit -m "docs(scope): summary"
git push origin main
```

## Security checklist before every push

- [ ] `git status` does **not** show `.env` (it is git-ignored — if it ever
      appears, stop and remove it from the index with `git rm --cached`)
- [ ] no API keys, tokens, database URLs or personal data in code, comments
      or docs — watch for Groq-style keys, connection strings with embedded
      credentials, and long JWT-looking strings
- [ ] `.env.example` still contains placeholders only
- [ ] build outputs / `node_modules` / `.idea` not staged

## If authentication fails on push

Windows Git Credential Manager opens a browser login on the first push —
complete it there. Never paste tokens into chats or commit them. To reset a
stored credential: Windows Credential Manager → remove the `git:https://github.com`
entry and push again.

## Recovering safely

- Undo an unstaged edit: `git restore <file>` (destructive — only when you
  really mean it).
- Never `push --force` to a shared branch; never rewrite published history
  without explicit agreement.
