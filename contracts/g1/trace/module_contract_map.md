# 137-screen first-pass registry → primary API domains

**Not a second audit of all visuals.** The accompanying `137_screen_registry_first_pass.csv` is copied unchanged from the previous stage; titles and grouping were reviewed then, pixel/state/action mapping is still pending. Exact 137 mock screens are not necessarily 137 deployed routes.

| PDF page range | Previous mapping area | Primary G1 contract domains |
|---|---|---|
| 001–022 | Account & Project Workspace | Accounts, Projects, Drafts, RBAC, invitations |
| 023–042 | Input Studio & AI Review | Sources, transcripts, candidate claims, clarifications, jobs |
| 043–104 | Approved 8-step Builder | Builder, requirements/features/screens/routes/tokens/components/Blueprint, preview, validation, approval, exports |
| 105–109 | Additional AI Assistant concepts | **G0-07 deferred:** DO NOT infer approved production endpoint/implementation from these mocks |
| 110–113 | Governance & Help | Allowed project audit and help contracts; no hidden SA content access |
| 114–137 | Super Admin | Aggregated operations, account metadata/actions, scoped grant revocation, support — one SA tier; no customer approval |

Important: PDF Builder Step 08 still ends in owner-approved **Review & Export**; Pre-Builder PB-V1 is six primary screen families regardless of extra mock states. All route/feature/screen IDs must be stable and any disappearing item triggers dependent validation. This file maps major domains, not all 166 feature entries individually.
