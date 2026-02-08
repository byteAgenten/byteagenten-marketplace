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

# Spec-Pfade extrahieren (File Reference Protocol — alle Agents schreiben MD-Dateien)
TECH_SPEC=$(jq -r '.context.technicalSpec.specFile // ""' "$WORKFLOW_FILE")
API_SPEC=$(jq -r '.context.apiDesign.apiDesignFile // ""' "$WORKFLOW_FILE")
DB_SPEC=$(jq -r '.context.migrations.databaseFile // ""' "$WORKFLOW_FILE")
WIREFRAMES=$(jq -r '.context.wireframes.paths // [] | join(", ")' "$WORKFLOW_FILE" 2>/dev/null || echo "")
BACKEND_SPEC=$(jq -r '.context.backendImpl.specFile // ""' "$WORKFLOW_FILE")
FRONTEND_SPEC=$(jq -r '.context.frontendImpl.specFile // ""' "$WORKFLOW_FILE")
TEST_REPORT=$(jq -r '.context.testResults.reportFile // ""' "$WORKFLOW_FILE")
SECURITY_REPORT=$(jq -r '.context.securityAudit.specFile // ""' "$WORKFLOW_FILE")

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

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph00-architect-planner.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.technicalSpec = {"specFile":".workflow/specs/issue-${ISSUE_NUM}-ph00-architect-planner.md"}

## YOUR TASK
Create a Technical Specification. Apply 5x Warum root cause analysis. Use MCP tools for current docs.

## PHASE SKIPPING (PFLICHT bei nicht benoetigten Phasen!)
Wenn bestimmte Phasen fuer dieses Issue NICHT benoetigt werden, MUSST du sie JETZT pre-skippen.
Fuehre fuer JEDE nicht benoetigte Phase einen jq-Befehl aus:

Beispiel (Phase 3 skippen — keine DB-Aenderungen):
  jq '.phases["3"] = {"name":"postgresql-architect","status":"skipped","reason":"Keine DB-Aenderungen"} | .context.migrations = {"skipped":true,"reason":"Keine DB-Aenderungen"}' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json

Skip-Referenz:
| Phase | Agent | context-Key | Wann skippen? |
|-------|-------|-------------|---------------|
| 1 | ui-designer | wireframes | Keine UI-Aenderungen noetig |
| 2 | api-architect | apiDesign | Kein neues/geaendertes API |
| 3 | postgresql-architect | migrations | Keine DB-Aenderungen |
| 4 | spring-boot-developer | backendImpl | Kein Backend betroffen |
| 5 | angular-frontend-developer | frontendImpl | Kein Frontend betroffen |

NIEMALS skippen: Phase 0, 6 (Tests), 7 (Security), 8 (Review), 9 (Push & PR).
Nur Phasen skippen die WIRKLICH nicht benoetigt werden. Der Orchestrator ueberspringt pre-geskippte Phasen automatisch.
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

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
wireframes/issue-${ISSUE_NUM}-[slug].html
(Ersetze [slug] durch einen kurzen Slug des Issue-Titels, z.B. issue-${ISSUE_NUM}-login-form.html)
WICHTIG: Die Datei MUSS eine .html Datei sein, KEIN Markdown!

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.wireframes = {"paths":["wireframes/issue-${ISSUE_NUM}-[slug].html"]}

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

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph02-api-architect.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.apiDesign = {"apiDesignFile":".workflow/specs/issue-${ISSUE_NUM}-ph02-api-architect.md"}

## YOUR TASK
Design REST API endpoints. Create concise API sketch (no full OpenAPI YAML).
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

## OUTPUT FILE (Flyway-Migration — Namensformat beachten!)
backend/src/main/resources/db/migration/V[timestamp]__[description].sql

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.migrations = {"databaseFile":"backend/src/main/resources/db/migration/V[timestamp]__[description].sql"}

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

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph04-spring-boot-developer.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.backendImpl = {"specFile":".workflow/specs/issue-${ISSUE_NUM}-ph04-spring-boot-developer.md"}

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

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph05-angular-frontend-developer.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.frontendImpl = {"specFile":".workflow/specs/issue-${ISSUE_NUM}-ph05-angular-frontend-developer.md"}

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
$([ -n "$BACKEND_SPEC" ] && echo "- Backend Report: $BACKEND_SPEC")
$([ -n "$FRONTEND_SPEC" ] && echo "- Frontend Report: $FRONTEND_SPEC")

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph06-test-engineer.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.testResults = {"reportFile":".workflow/specs/issue-${ISSUE_NUM}-ph06-test-engineer.md","allPassed":true}
WICHTIG: allPassed MUSS true sein! NUR setzen wenn ALLE Tests bestanden haben!

## YOUR TASK
Write comprehensive tests: JUnit 5 + Mockito (backend), Jasmine + TestBed (frontend), Playwright E2E. Run mvn verify + npm test + npx playwright test.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  7)
    cat << EOF
Phase 7: Security Audit for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
$([ -n "$BACKEND_SPEC" ] && echo "- Backend Report: $BACKEND_SPEC")
$([ -n "$FRONTEND_SPEC" ] && echo "- Frontend Report: $FRONTEND_SPEC")

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph07-security-auditor.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.securityAudit = {"specFile":".workflow/specs/issue-${ISSUE_NUM}-ph07-security-auditor.md"}

## YOUR TASK
Perform OWASP Top 10 (2021) security audit. Check A01-A10. Report findings with severity levels.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  8)
    cat << EOF
Phase 8: Code Review for Issue #$ISSUE_NUM: $ISSUE_TITLE

## SPEC FILES (LIES DIESE ZUERST mit dem Read-Tool!)
- Technical Spec: $TECH_SPEC
- API Design: $API_SPEC
$([ -n "$BACKEND_SPEC" ] && echo "- Backend Report: $BACKEND_SPEC")
$([ -n "$FRONTEND_SPEC" ] && echo "- Frontend Report: $FRONTEND_SPEC")
$([ -n "$TEST_REPORT" ] && echo "- Test Report: $TEST_REPORT")
$([ -n "$SECURITY_REPORT" ] && echo "- Security Audit: $SECURITY_REPORT")

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Target Coverage: ${TARGET_COV}%

## OUTPUT FILE (EXAKTER PFAD — NICHT AENDERN!)
.workflow/specs/issue-${ISSUE_NUM}-ph08-code-reviewer.md

## CONTEXT KEY (workflow-state.json — EXAKT SO SETZEN!)
context.reviewFeedback = {"reviewFile":".workflow/specs/issue-${ISSUE_NUM}-ph08-code-reviewer.md","status":"APPROVED"}
(Oder "CHANGES_REQUESTED" bei Aenderungswuenschen. Bei CHANGES_REQUESTED: fixes[].file mit betroffenen Dateipfaden fuer deterministisches Rollback-Routing.)

## YOUR TASK
Independent code quality review. Verify coverage targets. Check SOLID, DRY, KISS.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  9)
    BRANCH=$(jq -r '.branch // "unknown"' "$WORKFLOW_FILE")
    FROM_BRANCH=$(jq -r '.fromBranch // "main"' "$WORKFLOW_FILE")
    cat << EOF
Phase 9: Push & PR for Issue #$ISSUE_NUM: $ISSUE_TITLE

## WORKFLOW CONTEXT
- Issue: #$ISSUE_NUM - $ISSUE_TITLE
- Branch: $BRANCH
- Target Branch: $FROM_BRANCH

## YOUR TASK (KEIN SUBAGENT — wird direkt vom Orchestrator ausgefuehrt)
Phase 9 wird durch den UserPromptSubmit-Hook gesteuert.
Sage "Done." und folge den Anweisungen des Hooks.
$RETRY_SECTION$HOTFIX_SECTION
EOF
    ;;

  *)
    echo "Phase $PHASE: Unknown phase for Issue #$ISSUE_NUM"
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════
# ACCEPTANCE CRITERIA + RETURN PROTOCOL (an JEDEN Prompt angehaengt)
# ═══════════════════════════════════════════════════════════════════════════
# Die Akzeptanzkriterien werden DIREKT aus phases.conf gelesen.
# Single Source of Truth: phases.conf definiert, Prompt transportiert,
# wf_verify.sh prueft. Keine Drift moeglich.
# ═══════════════════════════════════════════════════════════════════════════

CRITERION=$(get_phase_criterion "$PHASE")

# Akzeptanzkriterium menschenlesbar aufbereiten
case "$CRITERION" in
  *+*)
    # Compound-Kriterium: criterion1+criterion2 (ALL must pass)
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
