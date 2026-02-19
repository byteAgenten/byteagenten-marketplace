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

# Source phase configuration (CLAUDE_PLUGIN_ROOT bevorzugt)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
source "${SCRIPT_DIR}/../config/phases.conf"

# ═══════════════════════════════════════════════════════════════════════════
# STATE LESEN
# ═══════════════════════════════════════════════════════════════════════════
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE")
TARGET_COV=$(jq -r '.targetCoverage // 70' "$WORKFLOW_FILE")

# Spec-Pfade extrahieren (File Reference Protocol — alle Agents schreiben MD-Dateien)
TECH_SPEC=$(jq -r '.context.technicalSpec.specFile // ""' "$WORKFLOW_FILE")
DB_SPEC=$(jq -r '.context.migrations.databaseFile // ""' "$WORKFLOW_FILE")
WIREFRAMES=$(jq -r '.context.wireframes.paths // [] | join(", ")' "$WORKFLOW_FILE" 2>/dev/null || echo "")
BACKEND_SPEC=$(jq -r '.context.backendImpl.specFile // ""' "$WORKFLOW_FILE")
FRONTEND_SPEC=$(jq -r '.context.frontendImpl.specFile // ""' "$WORKFLOW_FILE")
TEST_REPORT=$(jq -r '.context.testResults.reportFile // ""' "$WORKFLOW_FILE")
SECURITY_REPORT=$(jq -r '.context.securityAudit.specFile // ""' "$WORKFLOW_FILE")

PHASE_NAME=$(get_phase_name "$PHASE")
RETRY_COUNT=$(jq -r ".recovery.phase_${PHASE}_attempts // 0" "$WORKFLOW_FILE" 2>/dev/null || echo "0")

# ═══════════════════════════════════════════════════════════════════════════
# USER HINTS (persistenter Kontext fuer alle Agents)
# ═══════════════════════════════════════════════════════════════════════════
HINTS_SECTION=""
_HINTS_RAW=$(jq -r '.hints // [] | .[]' "$WORKFLOW_FILE" 2>/dev/null || echo "")
if [ -n "$_HINTS_RAW" ]; then
  HINTS_SECTION="

## USER HINTS (vom User fuer diesen Workflow gesetzt)
"
  _HINT_IDX=1
  while IFS= read -r _HINT_LINE; do
    HINTS_SECTION="${HINTS_SECTION}${_HINT_IDX}. ${_HINT_LINE}
"
    _HINT_IDX=$((_HINT_IDX + 1))
  done <<< "$_HINTS_RAW"
fi

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
# DOWNSTREAM-KONTEXT (wenn Phase NACH einem Rollback-Target laeuft)
# ═══════════════════════════════════════════════════════════════════════════
DOWNSTREAM_SECTION=""
if [ -z "$HOTFIX_FEEDBACK" ]; then
  # Nur wenn KEIN direktes Hotfix-Feedback (dann ist es die Ziel-Phase selbst)
  ROLLBACK_FB=$(jq -r '.recovery.rollbackContext.feedback // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
  ROLLBACK_TGT=$(jq -r '.recovery.rollbackContext.targetPhase // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
  ROLLBACK_FINDINGS=$(jq -r '.recovery.rollbackContext.findingsPreview // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
  if [ -n "$ROLLBACK_FB" ] && [ -n "$ROLLBACK_TGT" ] && [ "$PHASE" -gt "$ROLLBACK_TGT" ] 2>/dev/null; then
    DOWNSTREAM_SECTION="

## ROLLBACK CONTEXT (upstream change)
Phase $ROLLBACK_TGT was re-run due to the following feedback:
$ROLLBACK_FB
Your phase runs AFTER this fix. Pay special attention to changes that may affect your work.
"
    if [ -n "$ROLLBACK_FINDINGS" ]; then
      DOWNSTREAM_SECTION="${DOWNSTREAM_SECTION}
### Review Findings (from approval phase)
$ROLLBACK_FINDINGS
"
    fi
  fi
fi

# Findings-Preview auch fuer direkte Hotfix-Phase (Rollback-Ziel selbst)
if [ -n "$HOTFIX_FEEDBACK" ]; then
  _HOTFIX_FINDINGS=$(jq -r '.recovery.rollbackContext.findingsPreview // ""' "$WORKFLOW_FILE" 2>/dev/null || echo "")
  if [ -n "$_HOTFIX_FINDINGS" ]; then
    HOTFIX_SECTION="${HOTFIX_SECTION}
### Review Findings (from approval phase)
$_HOTFIX_FINDINGS
"
  fi
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
    # ═══════════════════════════════════════════════════════════════════════
    # PHASE 0: Team Planning Protocol (Hub-and-Spoke)
    # ═══════════════════════════════════════════════════════════════════════
    # Lese Team-Konfiguration aus workflow-state.json
    MODEL_TIER=$(jq -r '.modelTier // "fast"' "$WORKFLOW_FILE")
    UI_DESIGNER_OPT=$(jq -r '.uiDesigner // false' "$WORKFLOW_FILE")
    SCOPE=$(jq -r '.scope // "full-stack"' "$WORKFLOW_FILE")

    # Model bestimmen
    if [ "$MODEL_TIER" = "quality" ]; then
      MODEL="opus"
    else
      MODEL="sonnet"
    fi

    # ─── Specialist Count berechnen (Basis: quality ist immer dabei) ─────
    SPECIALIST_COUNT=1
    [ "$SCOPE" != "frontend-only" ] && SPECIALIST_COUNT=$((SPECIALIST_COUNT + 1))  # backend
    [ "$SCOPE" != "backend-only" ] && SPECIALIST_COUNT=$((SPECIALIST_COUNT + 1))   # frontend

    # ─── Backend Specialist (nicht bei frontend-only) ────────────────────
    BACKEND_BLOCK=""
    BACKEND_PLAN_READ=""
    BACKEND_PLAN_VERIFY=""
    BACKEND_SHUTDOWN=""
    if [ "$SCOPE" != "frontend-only" ]; then
      BACKEND_BLOCK="
--- SPECIALIST: backend ---
Agent: bytA:spring-boot-developer
Name: backend
Prompt: |
  ROUND 1: PLAN for Issue #${ISSUE_NUM} - ${ISSUE_TITLE}.
  Target Coverage: ${TARGET_COV}%.
  Analyze the codebase. Plan: DB schema changes, new/modified entities, services, controllers, endpoint signatures, Flyway migrations, test approach.

  OUTPUT PROTOCOL (Reihenfolge EINHALTEN!):
  1. ERST: Write full plan to .workflow/specs/issue-${ISSUE_NUM}-plan-backend.md
     Die Datei auf Disk ist die Single Source of Truth. OHNE Datei kein Fortschritt!
  2. DANN: Send SHORT SUMMARY (max 20 lines) to teammate \"architect\" via SendMessage.
     Summary must include: entity count, endpoint count, migration version.
  3. After sending, say 'Done.'
"
      BACKEND_PLAN_READ="
     - .workflow/specs/issue-${ISSUE_NUM}-plan-backend.md"
      BACKEND_PLAN_VERIFY="
  .workflow/specs/issue-${ISSUE_NUM}-plan-backend.md"
      BACKEND_SHUTDOWN="backend, "
    fi

    # ─── Frontend Specialist (nicht bei backend-only) ────────────────────
    FRONTEND_BLOCK=""
    FRONTEND_PLAN_READ=""
    FRONTEND_PLAN_VERIFY=""
    FRONTEND_SHUTDOWN=""
    if [ "$SCOPE" != "backend-only" ]; then
      FRONTEND_BLOCK="
--- SPECIALIST: frontend ---
Agent: bytA:angular-frontend-developer
Name: frontend
Prompt: |
  ROUND 1: PLAN for Issue #${ISSUE_NUM} - ${ISSUE_TITLE}.
  Target Coverage: ${TARGET_COV}%.
  Analyze the codebase. Plan: new/modified components, services, routing, state management, data-testid attributes.

  OUTPUT PROTOCOL (Reihenfolge EINHALTEN!):
  1. ERST: Write full plan to .workflow/specs/issue-${ISSUE_NUM}-plan-frontend.md
     Die Datei auf Disk ist die Single Source of Truth. OHNE Datei kein Fortschritt!
  2. DANN: Send SHORT SUMMARY (max 20 lines) to teammate \"architect\" via SendMessage.
     Summary must include: component count, new routes, service count.
  3. After sending, say 'Done.'
"
      FRONTEND_PLAN_READ="
     - .workflow/specs/issue-${ISSUE_NUM}-plan-frontend.md"
      FRONTEND_PLAN_VERIFY="
  .workflow/specs/issue-${ISSUE_NUM}-plan-frontend.md"
      FRONTEND_SHUTDOWN="frontend, "
    fi

    # ─── UI Designer (nur wenn aktiviert UND Frontend dabei) ─────────────
    UI_DESIGNER_BLOCK=""
    UI_PLAN_READ=""
    UI_SHUTDOWN=""
    WIREFRAME_SECTION=""
    if [ "$UI_DESIGNER_OPT" = "true" ] && [ "$SCOPE" != "backend-only" ]; then
      SPECIALIST_COUNT=$((SPECIALIST_COUNT + 1))
      UI_DESIGNER_BLOCK="
--- SPECIALIST: ui ---
Agent: bytA:ui-designer
Name: ui
Prompt: |
  ROUND 1: PLAN (Wireframe) for Issue #${ISSUE_NUM} - ${ISSUE_TITLE}.
  IMPORTANT: Follow your PRE-IMPLEMENTATION CHECKLIST FIRST. Search for existing design tokens
  (Glob frontend/src/**/*tokens*) and read existing SCSS/styles BEFORE creating the wireframe.
  Use ONLY actual project token values — never hardcode colors or spacing.
  Create HTML wireframe with Angular Material components matching the project's design system.
  Include data-testid on ALL interactive elements.

  OUTPUT PROTOCOL (Reihenfolge EINHALTEN!):
  1. ERST: Write wireframe to wireframes/issue-${ISSUE_NUM}-plan-ui.html
     Write plan summary to .workflow/specs/issue-${ISSUE_NUM}-plan-ui.md
     Die Dateien auf Disk sind die Single Source of Truth. OHNE Dateien kein Fortschritt!
  2. DANN: Send SHORT SUMMARY (max 20 lines) to teammate \"architect\" via SendMessage.
     Summary must include: number of data-testid attributes, Material components used.
  3. After sending, say 'Done.'
"
      UI_PLAN_READ="
     - .workflow/specs/issue-${ISSUE_NUM}-plan-ui.md"
      UI_SHUTDOWN="ui, "
      WIREFRAME_SECTION="
     - ## Wireframe Reference (path to wireframe HTML)"
    fi

    # ─── Phase-Skipping Block (scope-bedingt) ────────────────────────────
    case "$SCOPE" in
      "frontend-only")
        PHASE_SKIP_BLOCK="
## PHASE SKIPPING
Phase 1 (DB) und Phase 2 (Backend) sind bereits uebersprungen (Scope: frontend-only).
Pruefe ob WEITERE Phasen uebersprungen werden koennen.
NIEMALS skippen: Phase 0, 3 (Frontend), 4 (Tests), 5 (Security), 6 (Review), 7 (Push & PR)."
        ;;
      "backend-only")
        PHASE_SKIP_BLOCK="
## PHASE SKIPPING
Phase 3 (Frontend) ist bereits uebersprungen (Scope: backend-only).
Pruefe ob Phase 1 (DB) uebersprungen werden kann (keine DB-Aenderungen?).

Beispiel (Phase 1 skippen):
  jq '.phases[\"1\"] = {\"name\":\"postgresql-architect\",\"status\":\"skipped\",\"reason\":\"Keine DB-Aenderungen\"} | .context.migrations = {\"skipped\":true,\"reason\":\"Keine DB-Aenderungen\"}' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json

NIEMALS skippen: Phase 0, 2 (Backend), 4 (Tests), 5 (Security), 6 (Review), 7 (Push & PR)."
        ;;
      *)
        PHASE_SKIP_BLOCK="
## PHASE SKIPPING (PFLICHT bei nicht benoetigten Phasen!)
Wenn bestimmte Phasen fuer dieses Issue NICHT benoetigt werden, MUSST du sie pre-skippen.
Fuehre fuer JEDE nicht benoetigte Phase einen jq-Befehl aus:

Beispiel (Phase 1 skippen — keine DB-Aenderungen):
  jq '.phases[\"1\"] = {\"name\":\"postgresql-architect\",\"status\":\"skipped\",\"reason\":\"Keine DB-Aenderungen\"} | .context.migrations = {\"skipped\":true,\"reason\":\"Keine DB-Aenderungen\"}' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json

Skip-Referenz:
| Phase | Agent | context-Key | Wann skippen? |
|-------|-------|-------------|---------------|
| 1 | postgresql-architect | migrations | Keine DB-Aenderungen |
| 2 | spring-boot-developer | backendImpl | Kein Backend betroffen |
| 3 | angular-frontend-developer | frontendImpl | Kein Frontend betroffen |

NIEMALS skippen: Phase 0, 4 (Tests), 5 (Security), 6 (Review), 7 (Push & PR)."
        ;;
    esac

    cat << TEAM_EOF
=== PHASE 0: TEAM PLANNING PROTOCOL ===

TEAM_NAME: bytA-plan-${ISSUE_NUM}
MODEL: ${MODEL}
SCOPE: ${SCOPE}
SPECIALIST_COUNT: ${SPECIALIST_COUNT}
${BACKEND_BLOCK}${FRONTEND_BLOCK}
--- SPECIALIST: quality ---
Agent: bytA:test-engineer
Name: quality
Prompt: |
  ROUND 1: PLAN for Issue #${ISSUE_NUM} - ${ISSUE_TITLE}.
  Target Coverage: ${TARGET_COV}%.
  Start with Existing Test Impact Analysis (see your agent instructions!).
  Plan E2E scenarios, unit test strategy, integration test strategy.

  OUTPUT PROTOCOL (Reihenfolge EINHALTEN!):
  1. ERST: Write full plan to .workflow/specs/issue-${ISSUE_NUM}-plan-quality.md
     MUST include section: ## Existing Tests to Update
     Die Datei auf Disk ist die Single Source of Truth. OHNE Datei kein Fortschritt!
  2. DANN: Send SHORT SUMMARY (max 20 lines) to teammate "architect" via SendMessage.
     Summary must include: count of existing tests that will break, new test count, coverage estimate.
  3. After sending, say 'Done.'
${UI_DESIGNER_BLOCK}
--- HUB: architect ---
Agent: bytA:architect-planner
Name: architect
Prompt: |
  ROUND 1: PLAN (Consolidator) for Issue #${ISSUE_NUM} - ${ISSUE_TITLE}.
  Target Coverage: ${TARGET_COV}%.
  Scope: ${SCOPE}

  You are the HUB in a Hub-and-Spoke planning team.
  You will receive ${SPECIALIST_COUNT} plan summaries via SendMessage from teammates.
  WAIT for ALL ${SPECIALIST_COUNT} summaries before proceeding.

  After receiving all summaries:
  1. Read full plans from disk INCREMENTALLY (one at a time):${BACKEND_PLAN_READ}${FRONTEND_PLAN_READ}
     - .workflow/specs/issue-${ISSUE_NUM}-plan-quality.md${UI_PLAN_READ}

     RECOVERY bei fehlenden Dateien:
     Wenn eine Plan-Datei NICHT existiert obwohl die Summary empfangen wurde:
     a) SendMessage an den betroffenen Spezialisten:
        "Deine Plan-Datei [Pfad] fehlt auf Disk. Bitte schreibe sie JETZT."
     b) Warte auf Bestaetigung, dann lies die Datei.
     c) Wenn nach 2 Nachrichten keine Datei: Nutze den Summary-Inhalt aus der
        empfangenen SendMessage als Fallback und fahre fort.

  2. Validate CONSISTENCY (between existing plans):
     - Endpoints match between backend and frontend (field names, types, URLs)
     - DTOs match (same field names, same types)
     - data-testid from wireframe match E2E test selectors
  3. If CONFLICTS found: SendMessage to affected specialist, wait for correction
  4. Write CONSOLIDATED SPEC to .workflow/specs/issue-${ISSUE_NUM}-plan-consolidated.md
     MUST contain appropriate sections for scope "${SCOPE}":
     - ## Architecture Overview
     - ## Implementation Scope (${SCOPE})
     - ## Existing Tests to Update (from quality plan)$([ "$SCOPE" != "frontend-only" ] && echo "
     - ## API Contract
     - ## Data Model")$([ "$SCOPE" != "backend-only" ] && echo "
     - ## Frontend Structure")${WIREFRAME_SECTION}
  5. Set context key:
     jq '.context.technicalSpec = {"specFile":".workflow/specs/issue-${ISSUE_NUM}-plan-consolidated.md","scope":"${SCOPE}"}$([ "$UI_DESIGNER_OPT" = "true" ] && [ "$SCOPE" != "backend-only" ] && echo " | .context.wireframes = {\"paths\":[\"wireframes/issue-${ISSUE_NUM}-plan-ui.html\"]}")' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json
  6. Execute Phase Skipping:
${PHASE_SKIP_BLOCK}
  After writing consolidated spec and executing phase skipping, say 'Done.'

--- VERIFY ---
Files that MUST exist after team completes:
  .workflow/specs/issue-${ISSUE_NUM}-plan-consolidated.md${BACKEND_PLAN_VERIFY}${FRONTEND_PLAN_VERIFY}
  .workflow/specs/issue-${ISSUE_NUM}-plan-quality.md

--- CLEANUP ---
After architect says 'Done.':
1. Send shutdown_request to ALL teammates (${BACKEND_SHUTDOWN}${FRONTEND_SHUTDOWN}quality, ${UI_SHUTDOWN}architect)
2. TeamDelete (ignore errors — agents may already be gone)
3. Say "Done."
$HINTS_SECTION$RETRY_SECTION$HOTFIX_SECTION$DOWNSTREAM_SECTION
TEAM_EOF
    ;;

  1)
    cat << EOF
Phase 1: Create Database Migrations for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE

## OUTPUT FILE (Flyway-Migration — Namensformat beachten!)
backend/src/main/resources/db/migration/V[timestamp]__[description].sql

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.migrations = {"databaseFile":"backend/src/main/resources/db/migration/V[timestamp]__[description].sql"}

## YOUR TASK
Create Flyway SQL migrations. Normalize schema (3NF). Add indexes and constraints.
$HINTS_SECTION$RETRY_SECTION$HOTFIX_SECTION$DOWNSTREAM_SECTION
EOF
    ;;

  2)
    cat << EOF
Phase 2: Implement Backend for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
- Database Design: $DB_SPEC

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph02-spring-boot-developer.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.backendImpl = {"specFile":".workflow/specs/issue-${ISSUE_NUM}-ph02-spring-boot-developer.md"}

## YOUR TASK
Implement Spring Boot 4 REST controllers, services, repositories. Add Swagger annotations. Run mvn verify before completing. MANDATORY: Load current docs via Context7 BEFORE coding.
$HINTS_SECTION$RETRY_SECTION$HOTFIX_SECTION$DOWNSTREAM_SECTION
EOF
    ;;

  3)
    cat << EOF
Phase 3: Implement Frontend for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
$([ -n "$WIREFRAMES" ] && echo "- Wireframes: $WIREFRAMES")

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph03-angular-frontend-developer.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.frontendImpl = {"specFile":".workflow/specs/issue-${ISSUE_NUM}-ph03-angular-frontend-developer.md"}

## YOUR TASK
Implement ALL functional requirements from the Technical Spec. Use Angular 21+, Signals, inject(). Add data-testid on ALL interactive elements. Run npm test before completing. MANDATORY: Load current docs via Context7 + Angular CLI MCP BEFORE coding.
$HINTS_SECTION$RETRY_SECTION$HOTFIX_SECTION$DOWNSTREAM_SECTION
EOF
    ;;

  4)
    cat << EOF
Phase 4: Write E2E and Integration Tests for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
$([ -n "$BACKEND_SPEC" ] && echo "- Backend Report: $BACKEND_SPEC")
$([ -n "$FRONTEND_SPEC" ] && echo "- Frontend Report: $FRONTEND_SPEC")

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph04-test-engineer.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.testResults = {"reportFile":".workflow/specs/issue-${ISSUE_NUM}-ph04-test-engineer.md","allPassed":true}
WICHTIG: allPassed MUSS true sein! NUR setzen wenn ALLE Tests bestanden haben!

## YOUR TASK
Write comprehensive tests: JUnit 5 + Mockito (backend), Jasmine + TestBed (frontend), Playwright E2E. Run mvn verify + npm test + npx playwright test.
$HINTS_SECTION$RETRY_SECTION$HOTFIX_SECTION$DOWNSTREAM_SECTION
EOF
    ;;

  5)
    cat << EOF
Phase 5: Security Audit for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
$([ -n "$BACKEND_SPEC" ] && echo "- Backend Report: $BACKEND_SPEC")
$([ -n "$FRONTEND_SPEC" ] && echo "- Frontend Report: $FRONTEND_SPEC")

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph05-security-auditor.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.securityAudit = {"specFile":".workflow/specs/issue-${ISSUE_NUM}-ph05-security-auditor.md"}

## YOUR TASK
Perform OWASP Top 10 (2021) security audit. Check A01-A10. Report findings with severity levels.
$HINTS_SECTION$RETRY_SECTION$HOTFIX_SECTION$DOWNSTREAM_SECTION
EOF
    ;;

  6)
    cat << EOF
Phase 6: Code Review for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
$([ -n "$BACKEND_SPEC" ] && echo "- Backend Report: $BACKEND_SPEC")
$([ -n "$FRONTEND_SPEC" ] && echo "- Frontend Report: $FRONTEND_SPEC")
$([ -n "$TEST_REPORT" ] && echo "- Test Report: $TEST_REPORT")
$([ -n "$SECURITY_REPORT" ] && echo "- Security Audit: $SECURITY_REPORT")

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph06-code-reviewer.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.reviewFeedback = {"reviewFile":".workflow/specs/issue-${ISSUE_NUM}-ph06-code-reviewer.md","status":"APPROVED"}
(Oder "CHANGES_REQUESTED" bei Aenderungswuenschen. Bei CHANGES_REQUESTED: fixes[] Array mit betroffenen Dateien fuer den User am Approval-Gate.)

## YOUR TASK
Independent code quality review. Verify coverage targets. Check SOLID, DRY, KISS.
$HINTS_SECTION$RETRY_SECTION$HOTFIX_SECTION$DOWNSTREAM_SECTION
EOF
    ;;

  7)
    BRANCH=$(jq -r '.branch // "unknown"' "$WORKFLOW_FILE")
    FROM_BRANCH=$(jq -r '.fromBranch // "main"' "$WORKFLOW_FILE")
    cat << EOF
Phase 7: Push & PR for Issue #$ISSUE_NUM: $ISSUE_TITLE

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Branch: $BRANCH
- Target Branch: $FROM_BRANCH

## YOUR TASK (KEIN SUBAGENT — wird direkt vom Orchestrator ausgefuehrt)
Phase 7 wird durch den UserPromptSubmit-Hook gesteuert.
Sage "Done." und folge den Anweisungen des Hooks.
$HINTS_SECTION$RETRY_SECTION$HOTFIX_SECTION$DOWNSTREAM_SECTION
EOF
    ;;

  *)
    echo "Phase $PHASE: Unknown phase for Issue #$ISSUE_NUM"
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════
# ACCEPTANCE CRITERIA + RETURN PROTOCOL (an JEDEN Prompt angehaengt)
# ═══════════════════════════════════════════════════════════════════════════
CRITERION=$(get_phase_criterion "$PHASE")

# Akzeptanzkriterium menschenlesbar aufbereiten
case "$CRITERION" in
  *+*)
    HUMAN_CRITERION="ALL of these must be true:"
    OLD_IFS="$IFS"
    IFS='+'
    for PART in $CRITERION; do
      case "$PART" in
        GLOB:*) HUMAN_CRITERION="$HUMAN_CRITERION
  - File must exist: ${PART#GLOB:}" ;;
        STATE:*) HUMAN_CRITERION="$HUMAN_CRITERION
  - workflow-state.json must have: ${PART#STATE:}" ;;
        VERIFY:*) HUMAN_CRITERION="$HUMAN_CRITERION
  - Command must succeed: ${PART#VERIFY:}" ;;
      esac
    done
    IFS="$OLD_IFS"
    ;;
  GLOB:*)
    HUMAN_CRITERION="File must exist: ${CRITERION#GLOB:}"
    ;;
  STATE:*)
    EXPR="${CRITERION#STATE:}"
    if echo "$EXPR" | grep -q '=='; then
      HUMAN_CRITERION="workflow-state.json must have: $EXPR"
    else
      HUMAN_CRITERION="workflow-state.json must contain key: $EXPR"
    fi
    ;;
  VERIFY:*)
    HUMAN_CRITERION="Command must succeed: ${CRITERION#VERIFY:}"
    ;;
  *)
    HUMAN_CRITERION="Phase must be marked completed"
    ;;
esac

cat << ACCEPTANCE_EOF

## ACCEPTANCE CRITERIA (auto-generated from phases.conf)
Your work is verified EXTERNALLY. You are done when:
  $HUMAN_CRITERION
This is checked automatically. If this criterion is not met, you will be re-spawned.

## RETURN PROTOCOL
Your last message MUST be exactly: Done.
The orchestrator does NOT read your summary — it verifies externally.
ACCEPTANCE_EOF
