#!/bin/bash
# bytM Task Verification (TaskCompleted)
# Verifies output files exist before a task can be marked completed.
# Uses exit 2 + stderr message (NOT JSON — TaskCompleted doesn't support JSON control).

INPUT=$(cat)
_HOOK_CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

WORKFLOW_FILE=".workflow/workflow-state.json"
[ -f "$WORKFLOW_FILE" ] || exit 0

# Ownership guard
WORKFLOW_TYPE=$(jq -r '.workflow // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
[ "$WORKFLOW_TYPE" = "bytM-feature" ] || exit 0

TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // ""' 2>/dev/null || echo "")
ISSUE_NUM=$(jq -r '.issue.number // ""' "$WORKFLOW_FILE" 2>/dev/null)

# Only verify bytM workflow tasks (PLAN:, VALIDATE:, IMPLEMENT:, VERIFY:)
case "$TASK_SUBJECT" in
  PLAN:*architect*)
    ls .workflow/specs/issue-${ISSUE_NUM}-plan-architect.md >/dev/null 2>&1 || \
      { echo "Architect plan file missing: .workflow/specs/issue-${ISSUE_NUM}-plan-architect.md" >&2; exit 2; }
    ;;
  PLAN:*[Bb]ackend*)
    ls .workflow/specs/issue-${ISSUE_NUM}-plan-backend.md >/dev/null 2>&1 || \
      { echo "Backend plan file missing" >&2; exit 2; }
    ;;
  PLAN:*[Ff]rontend*)
    ls .workflow/specs/issue-${ISSUE_NUM}-plan-frontend.md >/dev/null 2>&1 || \
      { echo "Frontend plan file missing" >&2; exit 2; }
    ;;
  PLAN:*[Qq]uality*)
    ls .workflow/specs/issue-${ISSUE_NUM}-plan-quality.md >/dev/null 2>&1 || \
      { echo "Quality plan file missing" >&2; exit 2; }
    ;;
  VALIDATE:*)
    ls .workflow/specs/issue-${ISSUE_NUM}-validation-*.md >/dev/null 2>&1 || \
      { echo "Validation report missing" >&2; exit 2; }
    ;;
  IMPLEMENT:*[Bb]ackend*)
    ls .workflow/specs/issue-${ISSUE_NUM}-impl-backend.md >/dev/null 2>&1 || \
      { echo "Backend implementation report missing" >&2; exit 2; }
    ;;
  IMPLEMENT:*[Ff]rontend*)
    ls .workflow/specs/issue-${ISSUE_NUM}-impl-frontend.md >/dev/null 2>&1 || \
      { echo "Frontend implementation report missing" >&2; exit 2; }
    ;;
  IMPLEMENT:*[Qq]uality*)
    ls .workflow/specs/issue-${ISSUE_NUM}-impl-quality.md >/dev/null 2>&1 || \
      { echo "Quality implementation report missing" >&2; exit 2; }
    ;;
  VERIFY:*architect*)
    ls .workflow/specs/issue-${ISSUE_NUM}-verify-architect.md >/dev/null 2>&1 || \
      { echo "Architect verification report missing" >&2; exit 2; }
    ;;
  VERIFY:*[Bb]ackend*)
    ls .workflow/specs/issue-${ISSUE_NUM}-verify-backend.md >/dev/null 2>&1 || \
      { echo "Backend verification report missing" >&2; exit 2; }
    ;;
  VERIFY:*[Ff]rontend*)
    ls .workflow/specs/issue-${ISSUE_NUM}-verify-frontend.md >/dev/null 2>&1 || \
      { echo "Frontend verification report missing" >&2; exit 2; }
    ;;
  "VERIFY: Full audit"*)
    # Quality Engineer must produce all 3 reports
    ls .workflow/specs/issue-${ISSUE_NUM}-verify-test-engineer.md >/dev/null 2>&1 || \
      { echo "Test report missing" >&2; exit 2; }
    ls .workflow/specs/issue-${ISSUE_NUM}-verify-security-auditor.md >/dev/null 2>&1 || \
      { echo "Security audit report missing" >&2; exit 2; }
    ls .workflow/specs/issue-${ISSUE_NUM}-verify-code-reviewer.md >/dev/null 2>&1 || \
      { echo "Code review report missing" >&2; exit 2; }
    TESTS_PASSED=$(jq -r '.context.testResults.allPassed // false' "$WORKFLOW_FILE" 2>/dev/null)
    [ "$TESTS_PASSED" = "true" ] || \
      { echo "testResults.allPassed is not true in workflow-state.json" >&2; exit 2; }
    ;;
esac

exit 0
