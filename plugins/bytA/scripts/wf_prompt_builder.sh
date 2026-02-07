#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Deterministic Prompt Builder (Boomerang Principle)
# ═══════════════════════════════════════════════════════════════════════════
# Baut Agent-Prompts deterministisch aus workflow-state.json.
# KEIN LLM beteiligt — der Prompt wird aus State + Templates gebaut.
#
# Usage: wf_prompt_builder.sh <phase_number> [hotfix_feedback]
# Output: Prompt-Text auf stdout
# ═══════════════════════════════════════════════════════════════════════════
# BASH 3.x KOMPATIBEL (macOS default)
# ═══════════════════════════════════════════════════════════════════════════

set -e

PHASE=$1
HOTFIX_FEEDBACK="${2:-}"
WORKFLOW_FILE=".workflow/workflow-state.json"

# Source phase configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../config/phases.conf"

# ═══════════════════════════════════════════════════════════════════════════
# STATE LESEN
# ═══════════════════════════════════════════════════════════════════════════
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE")
TARGET_COV=$(jq -r '.targetCoverage // 70' "$WORKFLOW_FILE")

# Spec-Pfade extrahieren (File Reference Protocol)
TECH_SPEC=$(jq -r '.context.technicalSpec.specFile // ""' "$WORKFLOW_FILE")
API_SPEC=$(jq -r '.context.apiDesign.apiDesignFile // ""' "$WORKFLOW_FILE")
DB_SPEC=$(jq -r '.context.migrations.databaseFile // ""' "$WORKFLOW_FILE")
WIREFRAMES=$(jq -r '.context.wireframes.paths // [] | join(", ")' "$WORKFLOW_FILE" 2>/dev/null || echo "")

PHASE_NAME=$(get_phase_name "$PHASE")
RETRY_COUNT=$(jq -r ".recovery.phase_${PHASE}_attempts // 0" "$WORKFLOW_FILE" 2>/dev/null || echo "0")

# ═══════════════════════════════════════════════════════════════════════════
# HOTFIX-KONTEXT (wenn Rollback)
# ═══════════════════════════════════════════════════════════════════════════
HOTFIX_SECTION=""
if [ -n "$HOTFIX_FEEDBACK" ]; then
  HOTFIX_SECTION="

## HOTFIX CONTEXT
This is a hotfix iteration (attempt $RETRY_COUNT). Fix the following issues:
$HOTFIX_FEEDBACK
"
fi

# ═══════════════════════════════════════════════════════════════════════════
# RETRY-KONTEXT (wenn Agent schon mal lief)
# ═══════════════════════════════════════════════════════════════════════════
RETRY_SECTION=""
if [ "$RETRY_COUNT" -gt 0 ] && [ -z "$HOTFIX_FEEDBACK" ]; then
  RETRY_SECTION="

## RETRY NOTICE
Previous attempt ($RETRY_COUNT) did not complete successfully. Check existing work and complete the missing parts.
"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PROMPT-TEMPLATE PRO PHASE
# ═══════════════════════════════════════════════════════════════════════════
case $PHASE in
  0)
    cat << EOF
Phase 0: Create Technical Specification for Issue #$ISSUE_NUM: $ISSUE_TITLE

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## YOUR TASK
Create a Technical Specification. Apply 5x Warum root cause analysis. Use MCP tools for current docs.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  1)
    cat << EOF
Phase 1: Create Wireframes for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## YOUR TASK
Create HTML wireframes with Angular Material components. Include data-testid on ALL interactive elements.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  2)
    cat << EOF
Phase 2: Design API for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE

## YOUR TASK
Design REST API endpoints. Create concise API sketch (no full OpenAPI YAML). Save to .workflow/specs/ and update workflow-state.json.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  3)
    cat << EOF
Phase 3: Create Database Migrations for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
- API Design: $API_SPEC

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE

## YOUR TASK
Create Flyway SQL migrations. Normalize schema (3NF). Add indexes and constraints.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  4)
    cat << EOF
Phase 4: Implement Backend for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
- API Design: $API_SPEC
- Database Design: $DB_SPEC

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## YOUR TASK
Implement Spring Boot 4 REST controllers, services, repositories. Add Swagger annotations. Run mvn verify before completing. MANDATORY: Load current docs via Context7 BEFORE coding.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  5)
    cat << EOF
Phase 5: Implement Frontend for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
- API Design: $API_SPEC
- Wireframes: $WIREFRAMES

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## YOUR TASK
Implement Angular 21+ components, services, routing. Use Signals, inject(). Add data-testid on ALL interactive elements. Run npm test before completing. MANDATORY: Load current docs via Context7 + Angular CLI MCP BEFORE coding.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  6)
    cat << EOF
Phase 6: Write E2E and Integration Tests for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## YOUR TASK
Write comprehensive tests: JUnit 5 + Mockito (backend), Jasmine + TestBed (frontend), Playwright E2E. Set context.testResults.allPassed = true ONLY if ALL tests pass. Run mvn verify + npm test + npx playwright test.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  7)
    cat << EOF
Phase 7: Security Audit for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE

## YOUR TASK
Perform OWASP Top 10 (2021) security audit. Check A01-A10. Report findings with severity levels. Save audit report to .workflow/specs/.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  8)
    cat << EOF
Phase 8: Code Review for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
- API Design: $API_SPEC

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## YOUR TASK
Independent code quality review. Verify coverage targets. Check SOLID, DRY, KISS. Set context.reviewFeedback with status (APPROVED/CHANGES_REQUESTED). Include affected file paths in fixes[].file for deterministic rollback routing.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  *)
    echo "Phase $PHASE: Unknown phase for Issue #$ISSUE_NUM"
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════
# RETURN PROTOCOL (an JEDEN Prompt angehängt)
# ═══════════════════════════════════════════════════════════════════════════
# Der Orchestrator verifiziert extern via wf_verify.sh (Dateien, State).
# Er liest deine Summary NICHT. Minimaler Return = weniger Context-Verbrauch.
# ═══════════════════════════════════════════════════════════════════════════
cat << 'RETURN_EOF'

## RETURN PROTOCOL
Your last message to the orchestrator MUST be exactly one line:
  Done.
All your output goes to disk (spec files, workflow-state.json, code).
The orchestrator does NOT read your summary — it verifies externally.
Do NOT include a detailed summary. Just: Done.
RETURN_EOF
