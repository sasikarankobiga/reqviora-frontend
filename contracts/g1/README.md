# REQVIORA — G1 Shared API, Database & Blueprint Technical Contracts

**Contract pack:** G1-CANDIDATE-2026-11-19  
**Status:** Authored design/engineering draft; local schemas/fixtures checked. **No live backend, SQL Server migration, hosted endpoint, or production authorization was executed.**

## Read first

- `docs/01_precedence_and_decisions.md`: what is approved vs delegated vs still pending.
- `docs/02_canonical_domain_and_database.md`: stable IDs, draft/revision transitions, lineage, SQL constraints.
- `docs/03_api_contract_guide.md`: HTTP rules, RBAC, ETag, idempotency, jobs, errors, priority gaps.
- `docs/04_blueprint_renderer_contract.md`: safe Blueprint, registry, interactions, mock preview.
- `docs/05_approval_export_mcp.md`: immutable snapshots, independent approval, 19 files + manifest, MCP.
- `docs/06_qa_acceptance_and_handoff.md`: tests, implementation milestones, five team workstreams.
- `api/reqviora.openapi.yaml`: OpenAPI 3.1 **88 candidate operations** over 57 paths.
- `api/endpoint_inventory.csv`: one row per OpenAPI operation with RBAC action and remaining contract work.
- `schemas/`: 4 JSON Schema Draft 2020-12 contracts **and** one versioned candidate component-registry allowlist (19 type names; implementation not implied).
- `examples/`: Coffee Shop draft + Blueprint test fixtures and an explicitly non-production manifest shape example.
- `database/sqlserver/001_foundation.CANDIDATE.sql`: proposed SQL Server DDL, **not applied**.
- `database/erd.mmd`: entity relationship overview.
- `security/`: **unchanged copies** of the 39-action owner-delegated RBAC, SA module inventory, decision register.
- `trace/137_screen_registry_first_pass.csv`: unchanged first-pass UI inventory; not a claim of pixel/interaction audit completion.
- `trace/builder_step_contract_map.csv`: eight owner-approved stages connected to API and DB domains; not a line-by-line audit of all 166 feature entries.
- `tests/validate_pack.py`: local schemas, references, OpenAPI, manifest inventory and negative fixture checks.
- `tests/test_catalog.md`: product/security integration tests that still require running services.

## Source-of-truth order (do not silently rewrite)

1. Explicit product-owner decisions in conversation (V1 boundary, PB-V1, 8-stage Builder, Step 01 prefill, Step 08 Review & Export, Super Admin limit, AC-01A–E).
2. Owner-delegated AC-01F–H, AC-02–09 implementation direction (2026-11-18 pack). Marked **delegated**, not falsified as individual owner signatures.
3. BRD v0.5 and REQVIORA 12 Architecture Pack as **proposed reference material**, not working code. Conflicts resolved via current owner decisions only.
4. 137 UI mockup registry as first-pass evidence; mockups are not automatically production screens.

## Existing source artifacts inspected

- `Final BRD(3).pdf`, Candidate v0.5 (Nov 12 2026): Modules 1–14, REST suggestions, BRULE-01..12, Appendix A 8-step Builder, Appendix C canonical 19 + manifest.
- `REQVIORA_12_Complete_Engineering_Architectures(1).zip`: Architecture 06 backend, 07 canonical DB, 09 Blueprint/UI, 10 Validation/Approval, 11 Handoff, 12 MCP/security; associated unapproved Blueprint fixture.
- `REQVIORA_Access_Control_Delegated_Baseline_2026-11-18/REQVIORA_RBAC_Final_39_Actions.csv` and decision baseline.
- `REQVIORA_137_Screen_Mapping/REQVIORA_137_Screen_Mapping.csv` (first-pass inventory).

## How to validate

```bash
python tests/validate_pack.py
```

Validation is for **specification structure and sample fixtures only**. It cannot establish SQL Server correctness, an implemented API, secure authorization, UI parity, AI quality, actual 19-file export integrity, or deployed system readiness.

## Contract gates for parallel development

- **Gate G1-A**: stable identity and field-level access semantics signed off by dev/security leads.
- **Gate G1-B**: all OpenAPI endpoints used in the first vertical slice have fully typed DTOs; eliminate the generic `ObjectWrite.payload` before independent teams implement those endpoints.
- **Gate G1-C**: approved Blueprint registry version + renderer implemented with semantic reference validation.
- **Gate G1-D**: draft/version/approval/export/MCP negative integration tests pass.

**No AI provider, speech model, hosting region, storage vendor, cost ceiling, retention duration, or performance threshold is newly approved here.** G0-07 technical status remains deferred. Frontend/backend repository creation and deployment were not requested and were not performed.
