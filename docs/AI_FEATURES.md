# GRIVIO — AI Features

Five AI features, all served by the backend through Groq. The rule that
shapes everything: **AI proposes, the user disposes.**

## The path a request takes

```
Flutter sheet  →  POST /api/ai/... (JWT)  →  ai-*.service.js  →  groq.service.js  →  Groq
```

- The Flutter app **never** holds a Groq key and never calls Groq directly.
- `backend/src/services/groq.service.js` is the only module that talks to
  Groq (built-in `fetch`, 30 s `AbortController` timeout, no extra
  dependency).
- The model defaults to `openai/gpt-oss-120b` and can be changed with the
  `GROQ_MODEL` environment variable.

## The five features

| Feature | Endpoint | Where in the app |
| --- | --- | --- |
| Subtask suggestions | `POST /api/ai/subtasks/generate` | Task Detail → ✨ AI Assist |
| Task improvement | `POST /api/ai/tasks/improve` | Task Detail / Add Task → ✨ Improve |
| Goal breakdown (phases + tasks) | `POST /api/ai/breakdown/generate` | Goal Detail → ✨ Break down |
| Daily planner | `POST /api/ai/daily-plan/generate` | Home / Tasks → "Plan my day" |
| Weekly growth review | `POST /api/ai/weekly-review/generate` | Weekly Review → ✨ Generate AI Growth Review |

## The approval flow (preview-first)

1. **Generate** — the sheet asks the backend for suggestions built from the
   user's *own* data.
2. **Edit** — every suggestion is editable in the sheet: change text, reorder,
   select/deselect, remove.
3. **Confirm** — only the explicitly confirmed items are sent to the normal
   CRUD endpoints (`POST /api/tasks/:id/subtasks`, task update, milestone
   creation, …).
4. **Cancel** — closing a sheet without confirming changes nothing; the
   database is untouched.

The daily planner is even stricter: an accepted plan lives only in app memory
(`SessionPlanStore`) — there is no schedule table, so "accepting" never
writes anything.

## Guardrails that keep suggestions honest

| Guardrail | Where | What it does |
| --- | --- | --- |
| Ownership scoping | `ai-*.service.js` | prompts are built only from the requesting user's rows (`user_id = req.userId`) |
| Foreign-ID dropping | `ai-plan.service.js` | scheduled task IDs that don't resolve to the user's own open tasks are discarded |
| Low-data skip | `ai-weekly.service.js` | weeks with almost no activity answer without calling the model at all |
| Statistic scrubber | `ai-weekly.service.js` | sentences containing fabricated percentages/time claims (anything not backed by real data) are removed from the narrative |
| Free-text = input | `ai-plan.service.js` | the "What should your day look like?" text is treated as user context, never as system instructions, and is not stored |
| Response sanitation | all `ai-*.service.js` | JSON is parsed defensively; invalid enum values (e.g. unknown priority) are dropped |

## Error mapping

Groq failures never leak internals; they map to safe HTTP statuses:

| Provider problem | API response |
| --- | --- |
| missing `GROQ_API_KEY` / auth rejected (401/403) | 503 — "AI unavailable" (rest of the app keeps working) |
| rate limited (429) | 429 |
| provider 5xx | 502 |
| timeout (30 s) | 504 |
| malformed/empty answer | 502 |

## Testing note

The AI smoke suites (`backend/scripts/ai*_smoke_test.js`) **mock Groq's HTTP
response** — they verify prompt plumbing, parsing, guardrails and error
mapping without any live Groq call. Live behavior has not been exercised by
the automated tests.
