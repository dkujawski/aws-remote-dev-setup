# IaC Lambda Artifact Bootstrap — Execution Plan

## Objective

Create and land the bootstrap deployment redesign so long-lived artifact infrastructure is managed by a dedicated Terraform bootstrap root, while routine website/service deploy roots consume those resources without owning them.

## Why this change

The current ownership model mixes long-lived infrastructure (artifact buckets and deploy-role identities) with routine deployment concerns. That coupling increases blast radius and makes iterative deploy work riskier.

A bootstrap root must become the source of truth for:

- Lambda artifact buckets.
- IAM identities/policies used for artifact upload and deployment orchestration.

This separates infrequently changing foundational infrastructure from frequently changing application stack resources.

## Ownership model (required end state)

### Bootstrap-owned resources

Bootstrap Terraform owns:

- Artifact S3 buckets used to store Lambda/build artifacts.
- Bucket policies, encryption/lifecycle/public-access controls for those buckets.
- Deploy role identities (and supporting IAM policies/attachments) required for artifact upload/deploy workflows.

### Website-stack-owned resources

Website/service stack Terraform owns:

- Runtime application resources for the website stack (compute, routing, app-integrated resources).
- References to bootstrap outputs (for example bucket names/ARNs and deploy-role ARNs), but **not** creation of those bootstrap resources.

### Ownership rule

No resource may be managed by both states. If a resource is bootstrap-owned, website stack code must reference it as an input/data dependency only.

## Branching and PR targeting expectations

For implementation issues in this redesign stream:

- Start from latest `main`.
- Create branch names with `agent/` prefix.
- Open implementation PRs targeting `main`.

## HCP/Terraform authentication workflow

Implementations should standardize a documented auth flow for bootstrap and stack roots:

1. Authenticate operator/CI to HCP Terraform (or configured remote backend/workspace context).
2. Authenticate to AWS using approved role/credential path for the target environment.
3. Select correct Terraform workspace/backend for the root being operated (`bootstrap` vs `website`/deploy root).
4. Run `terraform init` and `terraform plan` before any apply/import/state operation.

Guardrails:

- Never run live import/apply/deploy verification without explicit maintainer approval.
- Prefer least-privilege credentials per root.
- Keep backend/workspace boundaries explicit to avoid cross-state writes.

## Migration runbook (import-first)

Existing live resources must be adopted without recreation.

1. **Inventory and map**
   - Enumerate existing artifact buckets and deploy IAM identities currently used.
   - Map each live resource to its intended bootstrap Terraform address.

2. **Define bootstrap configuration first**
   - Add Terraform resource blocks (and module structure if needed) for every mapped resource.
   - Ensure configuration matches current live settings as closely as possible before import.

3. **Import into bootstrap state (no recreate)**
   - Use import-first workflow to attach live resources to bootstrap state.
   - Run plan until diff is zero or intentionally understood.

4. **Decouple from website stack ownership**
   - Remove conflicting resource ownership from website stack root.
   - Replace with consumed inputs/remote-state/module outputs from bootstrap.

5. **Validate ownership transition**
   - Verify bootstrap plan reflects ownership.
   - Verify website stack no longer proposes create/destroy for bootstrap-owned resources.

6. **Document completion**
   - Record migrated resource list, import commands/addresses, and post-migration validation notes.

## Rollback and safety notes for state ownership changes

- Snapshot/backup state before any import or state surgery.
- Use state locking and serialize changes; avoid concurrent operations on same resources.
- If migration step yields unexpected destructive plan, stop and restore prior state snapshot before continuing.
- Prefer reversible steps: import into new owner first, then remove old ownership references.
- Require peer review of plan output for ownership-transfer PRs.

## Testing expectations

- Add or update **failing tests first** to encode new ownership boundaries and behavior before implementing functional changes.
- Minimum test intent for this initiative:
  - Detect that bootstrap root owns artifact buckets/deploy identities.
  - Detect that website stack consumes but does not define bootstrap-owned resources.
  - Detect migration guardrails/documented workflow artifacts where applicable.
- Keep tests green after implementation updates.

## Repo artifact synchronization requirements

Each implementation PR in this redesign stream must keep these artifacts synchronized with branch state relative to `main`:

- `docs/SPEC.md`
- `CHANGELOG.md`
- Matching `dev/PR/PR_<branch>.md`

When creating/updating `dev/PR` files, use `.github/pull_request_template.md` as the baseline template.

## Task ordering and dependencies

Recommended execution order (with known blockers):

1. **DAV-56** — Add initial failing repo tests for bootstrap ownership model.
2. **DAV-57** — Add Terraform bootstrap root and ownership wiring.
3. **Migration implementation tasks** — Import-first adoption of existing live resources into bootstrap state.
4. **Consumer stack cleanup tasks** — Remove old ownership in website stack and consume bootstrap outputs.
5. **Validation/docs tasks** — Final test stabilization and artifact synchronization (`SPEC`, `CHANGELOG`, `dev/PR`).

Dependency rationale:

- Tests first enforce behavior contracts before infrastructure refactor.
- Bootstrap root must exist before imports can safely transfer ownership.
- Ownership cleanup in consumer stacks depends on bootstrap outputs being available.

## Definition of done for this exec plan

This plan is complete when implementation PRs can follow it to deliver:

- Clear bootstrap-vs-website ownership boundaries.
- Import-first migration with safety/rollback controls.
- `main`-targeted PR flow from `agent/*` branches.
- Failing-tests-first implementation discipline.
- Synchronized repo artifacts for design, changelog, and PR documentation.
