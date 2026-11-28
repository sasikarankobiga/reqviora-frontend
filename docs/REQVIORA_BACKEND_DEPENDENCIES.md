# REQVIORA Backend Dependencies

Backend reference: `54daf30be57fcb76aaa76c4b3fed45f8c6d44cef` (read-only)

| Feature | Existing controller/endpoint | Missing capability | Authorization | Frontend impact | Priority / recommendation |
|---|---|---|---|---|---|
| SMTP delivery | `AuthController`, `AccountSecurityController`; `EmailService` retries transient failures/timeouts | No missing exception handling found; live transport still unverified | Public/authenticated depending action | Delivery cannot be certified locally | P0 environment: test with isolated SMTP mailbox and failure injection |
| Member identity | `GET /api/projects/{projectId}/members` | `ProjectMemberResponse` has only `UserId`, `Role`, `JoinedAtUtc`; no display name/email | Project reader | UI must truthfully display IDs | P1: add authorized sanitized identity fields without exposing non-member data |
| Validation directory | `/api/admin/validation/summary`, `/statistics`/`trends`, `/error-categories` | No project-level run directory/details | Administrator | Aggregate monitoring only | P1: add paginated authorized run metadata/detail contracts |
| Validation analytics | Same endpoints | No severity/rule-level filters or analytics | Administrator | Cannot implement requested drill-down | P2: extend aggregate DTO/filter contract |
| AI queue mutations | `GET /api/admin/ai-jobs`, `/{id}`, `/statistics`, `/health` | No admin retry endpoint | Administrator | Read-only monitoring | P1: define audited retry eligibility/idempotency contract |
| AI queue mutations | Same | No admin cancellation endpoint | Administrator | Cannot safely cancel jobs | P1: define terminal-state/concurrency/audit semantics |
| MCP filters | `GET /api/admin/mcp/grants` | Supports page/pageSize/search/state/projectId only; no additional audit/date/sort filters | Administrator | Directory limited to supported filters | P2: add only if operationally required |
| Export diagnostics | `GET /api/admin/exports/jobs`, `/{id}`, `/summary` | Supports status/project/date; no broader category/integrity/sort filters | Administrator | Existing UI cannot invent filters | P2: add explicit allowlisted sorting/filter DTO |
| Support tickets | No separate support controller | Ticket/conversation API absent | Administrator/support role required | Incidents cannot masquerade as support tickets | P1 if product-required: design separate ticket authorization/model |
| Support collaboration | No endpoint | Responses and internal notes absent | Administrator/support role | No conversation/note UI | P2 after ticket contract, with redaction/audit rules |
| Incident priority update | `/api/admin/incidents` supports create, status, assignment, history | No dedicated priority mutation | Administrator | Priority is fixed after creation | P2: add concurrency-token-protected audited mutation if required |
| Browser session restoration | `/api/auth/login`, `/refresh`, `/logout` use refresh tokens in JSON | No secure HttpOnly/SameSite cookie restoration contract | Authenticated | Tokens correctly remain memory-only; Ctrl+R requires sign-in | P0 UX/security: add CSRF-aware secure-cookie refresh/bootstrap endpoint or explicitly accept reauthentication |
| Admin profile detail | `/api/admin/profile`, `/security`, `/sessions`, `/login-history` | Profile/session DTOs omit role/status/creation/last-login and browser/last-activity/status fields; sessions are active-only | Administrator + MFA policy | UI displays only authoritative fields | P2: enrich sanitized DTOs if operationally necessary |
| Admin payment diagnostics | `/api/admin/billing/*` | No provider/callback/refund-history/entitlement diagnostic API | Administrator + fresh MFA | Details remain intentionally limited | P1: add redacted diagnostic DTOs and entitlement read endpoint |
| Admin refunds | `/api/admin/billing/refunds/*` | Review records workflow only; no real provider refund execution, reason/idempotency/concurrency contract | Administrator + fresh MFA | UI must not claim money transfer | P0 before production refunds: explicit provider workflow, idempotency, audit and entitlement semantics |

No endpoint names above are fabricated: missing capabilities are described as dependencies, not as implemented routes.
