# G1 Test Catalog — Not Executed Against Services

| ID | Scenario | Expected |
|---|---|---|
| T-01 | Verified active user creates project | Project, active draft, Owner membership atomic; no orphan records |
| T-02 | Concurrent same-idempotency create | One Project and one Owner assignment |
| T-03 | Unverified/suspended user creates project | Server rejects; no project stored |
| T-04 | User guesses other ProjectId | 403/404 without project metadata leakage |
| T-05 | Editor attempts Owner-only scope change | Rejected or proposal-only; authoritative project unchanged |
| T-06 | Editor attempts AI confirm | No confirmed requirement; proposal tracked |
| T-07 | Designer runs AI analysis | Job permitted if consent/quota; results remain unconfirmed |
| T-08 | Two tabs save stale If-Match | Second save 409, newer draft preserved |
| T-09 | PB-V1 four input methods | Sources remain independently attributed and re-enterable |
| T-10 | Unreadable PDF or uncertain Tamil STT | Explicit unresolved status, no fabricated source anchor |
| T-11 | AI provider down | Manual creation/Builder still usable; data preserved |
| T-12 | 7-step legacy migration dry-run and rollback | No loss of old Step 7 or approved revision hash |
| T-13 | Remove screen referenced by route | Validator emits blocker/recheck; not silent delete success |
| T-14 | Route target from other project | Validation rejects, never renders/action-executes |
| T-15 | Unknown Blueprint type/prop/action code | Schema/renderer rejects, no arbitrary code evaluation |
| T-16 | Component action refers missing route | Semantic validator rejects |
| T-17 | Editor change followed by regeneration | Diff/impact warning and saved history; no overwritten approved revision |
| T-18 | Mock preview button navigation | Moves Home → Menu, no network customer transaction |
| T-19 | Only Reviewer tries approval | 403; no ApprovedRevision |
| T-20 | Super Admin tries customer approval/private ZIP | Denied with safe audit |
| T-21 | Same person materially edits and approves | Denied by independent Approver check |
| T-22 | Stale validation run vs modified draft | Approval blocked; revalidation required |
| T-23 | Two competing valid approvals | Exactly one immutable revision for exact draft version |
| T-24 | Read previously approved REV after new draft edit | Identical frozen digest and content |
| T-25 | Canonical export 19+manifest | 20 ZIP entries; content/revision/hash/bytes/path checks pass |
| T-26 | Mismatched file hash or mixed revision | Export fails integrity; never reports ready |
| T-27 | Viewer granted one screen group | Can only read frozen listed resource IDs/revision |
| T-28 | Viewer URL guesses ungranted document or ZIP | Denied; download separate from view |
| T-29 | Revoke MCP grant, then read | Immediate denied on next request; no cached privileged response |
| T-30 | MCP tries write/export download/new revision | No tool/permission; server denies |
| T-31 | Remove final project Owner | Denied until atomic ownership transfer |
| T-32 | Audit on sensitive changes | Actor, project, time/correlation recorded without secret/source data |
| T-33 | SQL migrations + rollback on disposable SQL Server | All FK and immutability constraints verify |
| T-34 | 137 UI mock entry ↔ actual route/interaction audit | Every retained entry disposition documented, no silent drop |
| T-35 | 166 Builder features / 47 buttons trace audit | Every source feature maps to UI, API, domain rule/test or explicit missing item |

CI stages: schema unit → OpenAPI lint/DTO generation → DB migration & negative data constraints → auth/cross-project integration → renderer/preview → end-to-end Coffee Shop → security/accessibility/release thresholds. Actual results must be recorded per environment and version; the 35 rows above are **planned checks**, not passing evidence.
