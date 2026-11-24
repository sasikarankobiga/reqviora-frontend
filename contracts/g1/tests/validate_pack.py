#!/usr/bin/env python3
"""Offline structural checks ONLY; not security integration or live SQL/API tests."""
from pathlib import Path
import copy,csv,json,re,sys
import yaml
from jsonschema import Draft202012Validator,FormatChecker

BASE=Path(__file__).resolve().parents[1]

def loadj(rel):return json.loads((BASE/rel).read_text(encoding='utf-8'))

def assert_valid(rel_schema,rel_fixture):
 schema=loadj(rel_schema)
 Draft202012Validator.check_schema(schema)
 fixture=loadj(rel_fixture)
 errs=list(Draft202012Validator(schema,format_checker=FormatChecker()).iter_errors(fixture))
 assert not errs, '\n'.join(f'{rel_fixture}: {e.message} at {list(e.path)}' for e in errs)
 return schema,fixture

def semantic(draft,blue):
 assert blue['projectId']==draft['projectId'] and blue['draftId']==draft['draftId'] and blue['draftVersion']==draft['draftVersion']
 stages=draft['builderSteps'];assert [x['stepNo'] for x in stages]==list(range(1,9))
 assert stages[7]['stage']=='review-export'
 for domain,seq,key in [('screens',blue['screens'],'screenId'),('routes',blue['routes'],'routeId'),('actions',blue['actions'],'actionId'),('components',blue['componentInstances'],'componentInstanceId')]:
  ids=[x[key] for x in seq]
  assert len(ids)==len(set(ids)),f'duplicate {domain}'
 screens={x['screenId']:x for x in blue['screens']}
 comp={x['componentInstanceId']:x for x in blue['componentInstances']}
 actions={x['actionId']:x for x in blue['actions']}
 routes={x['routeId']:x for x in blue['routes']}
 app_roles=set(blue['applicationRoleIds'])
 for scr in blue['screens']:
  assert set(scr['applicationRoleIds']) <= app_roles
  for rid in scr['rootComponentIds']:
   assert rid in comp and comp[rid]['screenId']==scr['screenId'] and comp[rid]['parentComponentId'] is None
 for c in comp.values():
  assert c['screenId'] in screens
  assert set(c['actionRefs']).issubset(actions)
  parent=c['parentComponentId']
  if parent is not None:
   assert parent in comp and comp[parent]['screenId']==c['screenId']
   # Parent relation must be acyclic.
   visited={c['componentInstanceId']}
   while parent is not None:
    assert parent not in visited,'component hierarchy cycle'
    visited.add(parent);parent=comp[parent]['parentComponentId']
 for r in routes.values():
  assert r['sourceScreenId'] in screens and r['targetScreenId'] in screens
  assert r['triggerActionId'] in actions and actions[r['triggerActionId']]['kind']=='navigate'
  assert actions[r['triggerActionId']]['params']['routeId']==r['routeId']
  assert any(c['screenId']==r['sourceScreenId'] and r['triggerActionId'] in c['actionRefs'] for c in comp.values()),'route without origin component'
 for a in actions.values():
  if a['kind']=='navigate':assert a['params']['routeId'] in routes
  if a['kind'] in ('openModal','closeModal'):
   m=a['params']['modalComponentId'];assert m in comp and comp[m]['type']=='dialog'
 for t in blue['traceLinks']:
  assert t['screenId'] in screens
  assert t['featureId'] in {x['featureId'] for x in draft['features'] if x['status']=='confirmed'}
  assert t['requirementId'] in {x['requirementId'] for x in draft['requirements'] if x['status']=='confirmed'}
  if 'actionId' in t:assert t['actionId'] in actions
  if 'sourceId' in t:assert t['sourceId'] in {x['sourceId'] for x in draft['sources']}
  if 'criterionId' in t:assert t['criterionId'] in {x['criterionId'] for f in draft['features'] for x in f.get('acceptanceCriteria',[])}
 assert blue['simulationNotice']=='SIMULATED_PREVIEW_NO_LIVE_TRANSACTIONS'

project_schema,draft=assert_valid('schemas/project-draft-v1.schema.json','examples/coffee-shop.project-draft.json')
blue_schema,blue=assert_valid('schemas/blueprint-v1.schema.json','examples/coffee-shop.blueprint.json')
manifest_schema,manifest=assert_valid('schemas/manifest-v1.schema.json','examples/manifest.SHAPE_ONLY_NOT_EXPORT.json')
Draft202012Validator.check_schema(loadj('schemas/problem-v1.schema.json'))
semantic(draft,blue)
registry=loadj('schemas/component-registry-v1.CANDIDATE.json')
reg_types={r['type']:r for r in registry['componentTypes']}
assert len(reg_types)==len(registry['componentTypes']) and set(reg_types)==set(blue_schema['properties']['componentInstances']['items']['properties']['type']['enum'])
for comp in blue['componentInstances']:
 definition=reg_types[comp['type']]
 assert set(comp['props']) <= set(definition['allowedProps']),f"unsupported prop for {comp['type']}"
 assert set(definition['requiredProps']) <= set(comp['props']),f"missing prop for {comp['type']}"
assert registry['noExecutableProps'] and registry['simulationOnly']

# Negative: unknown executable action, unsupported component/prop, broken reference and stale source.
neg=copy.deepcopy(blue);neg['actions'][0]['kind']='runJavaScript'
assert not Draft202012Validator(blue_schema).is_valid(neg)
neg=copy.deepcopy(blue);neg['componentInstances'][1]['props']['onClick']='alert(1)'
assert not Draft202012Validator(blue_schema).is_valid(neg)
neg=copy.deepcopy(blue);neg['componentInstances'][1]['type']='remote-code'
assert not Draft202012Validator(blue_schema).is_valid(neg)
neg=copy.deepcopy(blue);neg['routes'][0]['targetScreenId']='00000000-0000-4000-8000-000000000000'
try:
 semantic(draft,neg)
 raise AssertionError('unknown route target passed semantic check')
except AssertionError as ex:
 if 'unknown route target passed' in str(ex):raise

expected=['README.md','project-overview.md','goals-and-success-criteria.md','audience-and-roles.md','scope-and-constraints.md','feature-catalog.md','business-rules-and-acceptance.md','screen-specifications.md','feature-screen-mapping.md','navigation-and-journeys.md','design-tokens.md','components-and-layout.md','interactions-and-states.md','accessibility-requirements.md','decision-register.md','open-questions.md','validation-report.md','implementation-checklist.md','project.json']
file_names=[x['path'] for x in manifest['files']]
assert file_names==expected and len(set(file_names))==19
assert all(x['sourceRevisionId']==manifest['revisionId'] for x in manifest['files'])
assert 'manifest.json' not in file_names
assert manifest['generatorVersion']=='fixture-only-0.1','expected an illustrative manifest not a real package'

api=yaml.safe_load((BASE/'api/reqviora.openapi.yaml').read_text())
assert api['openapi']=='3.1.0'
ops=[]
for path,methods in api['paths'].items():
 for method,entry in methods.items():
  if method not in ['get','post','patch','put','delete']:continue
  ops.append((method,path,entry))
  expected_pars=set(re.findall(r'\{([^}]+)\}',path))
  actual_pars={p['name'] for p in entry.get('parameters',[]) if p['in']=='path' and p['required']}
  assert expected_pars==actual_pars,(path,actual_pars,expected_pars)
  if method in ['put','patch']:
   assert 'If-Match' in {p['name'] for p in entry.get('parameters',[])}, f'{method} {path} lacks ETag precondition'
  assert entry.get('x-rbac-action'),f'no action {method} {path}'
  assert '401' in entry['responses'] and '403' in entry['responses']
assert len(ops)>=60 and len(set(x[2]['operationId'] for x in ops))==len(ops)
with (BASE/'api/endpoint_inventory.csv').open(encoding='utf-8') as f:
 assert len(list(csv.DictReader(f)))==len(ops)
with (BASE/'security/rbac_39_actions_delegated_baseline.csv').open(encoding='utf-8-sig') as f:
 rows=list(csv.DictReader(f)); assert len(rows)==39 and len(set(x['ID'] for x in rows))==39
with (BASE/'trace/137_screen_registry_first_pass.csv').open(encoding='utf-8-sig') as f:
 rows=list(csv.DictReader(f));assert len(rows)==137
print('PASS: 4 JSON Schemas + 19 candidate component types; Coffee Shop Draft+Blueprint+manifest fixtures; 4 negative cases; stable reference checks')
print(f'PASS: OpenAPI {len(ops)} operations and {len(api["paths"])} paths; endpoint inventory exact; ETags and auth response placeholders')
print('PASS: 19 canonical manifest references, 39 preserved RBAC actions, 137 first-pass mock screen rows')
print('NOT TESTED: SQL Server execution, real API, per-field RBAC, ZIP integrity, AI provider, frontend rendering, deployment')
