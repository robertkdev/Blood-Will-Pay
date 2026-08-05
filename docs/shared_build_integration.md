# Shared Build Integration

The shared playable line is `origin/main`. Individual Codex tasks work on retained `codex/*` branches; finishing a task does not make it part of the shared build.

## One integration owner

The existing `project-continuity-monitor` nightly automation is the integration owner. It may inspect every task and worktree read-only, but it must not checkpoint, stage, autosave, merge, or otherwise touch an active task checkout.

Each run follows one lane:

1. Capture a sanitized Codex thread snapshot containing only task id, status, cwd, and update time.
2. Run `Update-ProjectTaskLedger.ps1` through `Monitor-ProjectContinuity.ps1 -PreQueueSnapshot`. Active work is recorded as `active-not-queued`; terminal work gets a persistent receipt in `%USERPROFILE%\.codex\continuity\integration-queue`.
3. Treat `ready-for-review`, `awaiting-validation`, `awaiting-durability`, and overdue receipts as integration risk. Clearing the old checkpoint queue never clears the integration receipt.
4. Review the branch diff and its validation receipt. Record product holds with `Set-ProjectIntegrationReceipt.ps1`; do not hide an undecided branch.
5. Only an exact `state=approved` entry in `%USERPROFILE%\.codex\continuity\integration-plan.json` authorizes `Invoke-ProjectIntegration.ps1 -Apply`. The entry pins source/target branches and SHAs plus passed validation evidence.
6. The controller uses its own staging worktree, requires a fast-forward, verifies a recovery ref, pushes without force, verifies the remote target SHA, and retains every source branch/worktree.
7. Record `integrated-reviewed` only after remote verification. Conflicts, product alternatives, stale validation, and non-fast-forward work remain visible decisions.

The ledger and receipt are review artifacts, not merge authorization.

## Task completion receipt

A merge-ready task checkpoint must include:

- the exact `codex/*` branch and local/remote commit;
- remote SHA verification;
- validation status and concise evidence bound to that commit;
- target branch observed by the ledger;
- integration state, blockers, owner, queue time, and overdue state.

Use `Checkpoint-ProjectTask.ps1 -Final -ValidationStatus passed -ValidationEvidence <evidence>` or `Finish-ProjectTask.ps1` with the same validation arguments. Missing or stale evidence remains an explicit blocker.

## Refresh a clean playable checkout

Never pull, reset, clean, or stash the user's dirty historical checkout. Create a separate clean clone once and refresh it only by fast-forward:

```powershell
.\tools\Refresh-SharedBuildCheckout.ps1 `
  -Destination 'C:\Users\Flipm\Documents\Blood-Will-Pay-shared' `
  -AsJson
```

The helper marks the clone inside its Git directory. Later runs refuse unknown destinations, local changes, branch switches, non-fast-forward updates, and remote-SHA mismatches. It never modifies the source checkout. Validate the contract with:

```powershell
.\tools\Test-RefreshSharedBuildCheckout.ps1
```
