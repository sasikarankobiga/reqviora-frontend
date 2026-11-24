# 04 — Universal Blueprint JSON, registry, editor, preview

## One machine-readable truth

`schemas/blueprint-v1.schema.json` is a strict Draft 2020-12 schema for a **draft Blueprint**. `examples/coffee-shop.blueprint.json` is a conformant mock design with Home → Menu route and one button action. This is **not** an executable customer application.

Root contract:

```text
Blueprint 1.0.0
 ├─ identity: blueprintId, projectId, draftId, draftVersion, schemaVersion
 ├─ renderer: rendererContractVersion, componentRegistryVersion, generationSource
 ├─ applicationRoleIds (customer design personas, NOT REQVIORA authoring RBAC)
 ├─ designTargets: web | mobile | desktop
 ├─ screens: screenId, purpose, rootComponentIds, applicationRoleIds
 ├─ componentInstances: stable instance ID, screen, parent, registry type, order, typed props, actionRefs
 ├─ actions: actionId, kind, safe typed params
 ├─ routes: routeId, sourceScreenId, targetScreenId, triggerActionId, condition
 ├─ designTokens: color, typography, spacing, radius, light/dark/system
 ├─ interactionStates: loading | empty | error | success | disabled | permission-denied etc.
 ├─ traceLinks: requirementId, featureId, screenId, actionId, criterionId, sourceId
 └─ simulationNotice: SIMULATED_PREVIEW_NO_LIVE_TRANSACTIONS
```

## Component registry

Source-approved design families preserved: **Button, Input Field, Card, Dialog, Tabs, Chart**. Approved Step 05 includes further UI categories. The *candidate schema type names* currently include `text`, `container`, `row`, `column`, `grid`, `section`, `button`, `input`, `card`, `dialog`, `tabs`, `chart`, `list`, `table`, `navbar`, `sidebar`, `header`, `form`, `image`. **These are contractual candidates, not proof all renderers exist or an authorization to drop unsupported Step 05 features.**

Registry for each type must define: renderer key, version, supported props and enums, allowed children, accepted variants, layout profile, accessibility semantics, edit inspector fields, fallback/error behavior. `additionalProperties:false` prevents unknown props at schema level; runtime must still check per-type constraints and reject unregistered type/version.

## Safe mock-only actions

Allowed candidate action `kind` values:

- `navigate` (valid `routeId` and selected target screen)
- `openModal` / `closeModal` (registered `modalComponentId`)
- `setMockState` (bounded in-memory simulated state)
- `submitMockForm` (mock success/errors, no HTTP posting to customer backend)
- `showMessage` (safe displayed string)
- `simulateError` / `simulateLoading` (preview only)

No `eval`, arbitrary JS/Dart/SQL, arbitrary network URL, production booking API, customer authentication or live payment may be generated or executed from Blueprint JSON. JSON Schema alone is insufficient: runtime compiler and action dispatcher must enforce references and semantics. Unrecognized types **fail visibly** with validation findings, never silently produce a functional-looking blank control.

## Semantic validation beyond JSON Schema

1. Every screen, action, route, component and trace ID is unique **within its ID domain** and belongs to the same project/draft.
2. `rootComponentIds` point to components with matching `screenId` and no parent; no cyclic or cross-screen parent chains.
3. Every enabled route refers to selected source/target screens and one `navigate` action with a matching route ref and origin component.
4. All `actionRefs` exist; modal/form references target the right registered component; property types match component type.
5. Trace links resolve existing confirmed requirements, features, screens, actions and acceptance criteria. Missing referenced objects are blockers when mandatory.
6. The editor and preview consume the same saved Blueprint registry and tokens; versions are explicit and cross-rendering parity is tested.
7. Regeneration warns about impact, preserves previous design/version, and never mutates an approved snapshot.
8. Screens with inaccessible roles or missing empty/error/loading states are explicitly flagged.

## Versioning and migrations

A Blueprint compiled from DraftVersion N is immutable as that particular saved Blueprint version; further design edits must write new design revisions, not silently mutate it. The approved revision references the exact content digest and renderer/registry version. Version downgrade or unknown major schema must fail closed or show declared unsupported preview, never lie about compatibility.

## Example trace

`Text source → confirmed RequirementId → confirmed FeatureId → Menu ScreenId → route ActionId → AcceptanceCriterionId`. JSON fixture includes one valid trace and navigation link. AI-derived and template-derived generation must carry honest source labels. Source evidence is advisory until Owner confirmation.
