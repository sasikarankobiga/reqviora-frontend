# 05 — Validation, independent approval, canonical handoff and read-only MCP

## Final stage is Step 08: Review & Export

**Preserve owner-approved stage name and scope.** Validation Center, Approval Center, Second Brain and Export Center may be subviews, but not a ninth numbered Builder step. Step 08 may show full project summary, eight-step completion, findings, user comments, immutable revision status, final simulated preview and export options.

## Approval transaction protocol

Request: `{draftId, expectedDraftVersion, validationRunId, expectedDraftSha256}` with authorized Approver identity and `Idempotency-Key`. Server performs ALL of:

1. Authenticate active verified user; verify project-scoped **Approver role AND explicit approval grant**. Reviewer/Owner/Super Admin alone never qualifies.
2. Verify requester did **not materially contribute** to the exact version being approved (AC-07 delegated baseline). Material change definition and attribution evidence must be codified and tested before release.
3. Re-read persisted draft under concurrency-safe transaction; match exact draft ID, version/hash and current validation run.
4. Check validation run is completed, its hash/version is still current, zero blockers, mandatory source/trace/component/action checks passed. Draft incomplete states remain blocker for complete approval as determined by rule catalog.
5. Create immutable `ApprovedRevision` snapshot, approval event, digest and audit event **atomically**. Duplicate idempotency key returns the same committed result, not duplicate approvals.
6. New editing continues in a separate draft; old revision and its export stay stable.

HTTP failure examples: `403 FORBIDDEN` wrong Approver or SA; `409 STALE_DRAFT_VERSION` changed draft; `422 REVIEW_BLOCKERS` incomplete/invalid; `409 CONFLICT` duplicate incompatible request.

## Canonical 19 documents + separate manifest.json

From *one selected saved draft version* (labeled DRAFT) or *one approved revision* (labeled APPROVED), produce the exact original 19 filenames from BRD Appendix C, as listed here:

1. `README.md`
2. `project-overview.md`
3. `goals-and-success-criteria.md`
4. `audience-and-roles.md`
5. `scope-and-constraints.md`
6. `feature-catalog.md`
7. `business-rules-and-acceptance.md`
8. `screen-specifications.md`
9. `feature-screen-mapping.md`
10. `navigation-and-journeys.md`
11. `design-tokens.md`
12. `components-and-layout.md`
13. `interactions-and-states.md`
14. `accessibility-requirements.md`
15. `decision-register.md`
16. `open-questions.md`
17. `validation-report.md`
18. `implementation-checklist.md`
19. `project.json`

**+ `manifest.json`** as the **20th ZIP entry**, not one of the canonical 19. `schemas/manifest-v1.schema.json` covers an APPROVED package; a separate explicit draft variant is needed to implement and label draft manifests. This pack does not claim the 19 actual outputs have been generated.

### Export integrity

Select source version → load frozen snapshot/draft → validate all output semantics → render final file bytes → calculate SHA-256 and byte length for each final file → emit manifest listing 19 entries → ZIP exactly 19 + manifest → reopen ZIP and verify unique safe relative paths, file count, byte sizes, digest matches and source version alignment → private storage → reauthorize downloads. No path traversal or hidden package extras. Do not recursively include a hash of `manifest.json` inside itself.

`examples/manifest.SHAPE_ONLY_NOT_EXPORT.json` deliberately has zero-length-file metadata as a **schema-shape fixture only**, not a valid complete export and not proof any files exist.

## Viewer and private sharing

Viewer is metadata-only by default, requires exact action/resource/revision grants for actual screens/designs/preview/source documents/ZIP. A frozen group grant resolves to a listed set of resource IDs at grant creation; new screens/revisions do not automatically inherit it. Read and Download are separate actions; access denial on direct URL is mandatory. Expiry/revocation and admin limits apply.

## MCP (separate transport, not a public project JSON URL)

Owner issues an `McpGrant` for an **approved revision** with `ClientId`, allowlisted read scopes, expiry, revoke flag. Super Admin can emergency-revoke metadata but cannot implicitly read content. Each MCP tool request checks identity/grant/project/revision/scope and audits minimal safe metadata. `read:overview`, `read:requirements`, `read:screens`, `read:traceability`, `read:manifest` are illustrative scope names. The transport/client implementation remains pending, and MCP cannot approve, edit, execute generated code or directly download arbitrary ZIPs. REST grant management endpoints do **not** implement MCP transport.

## Non-negotiable isolation tests

Cross-project `RevisionId` / `ScreenId` / `ExportId`; Viewer ungranted file and ZIP URL; SA access to project content or approval; Editor AI confirmation; revoked/expired grant; stale validation/approval; second export after new draft; source revision mix; package files mismatch; arbitrary code in generated action/props must all fail closed.
