#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 User Prompt Context Injection (UserPromptSubmit Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert bei JEDEM User-Prompt. stdout wird in Claudes Kontext injiziert.
#
# Zweck:
# 1. Workflow-Status in Claudes Kontext halten (auch nach Compaction)
# 2. Approval-Gate-Anweisungen injizieren (Rollback-Regeln!)
# 3. stopHookBlockCount zurücksetzen (Loop-Prevention Reset)
#
# Output:
#   stdout → wird zu Claudes Kontext hinzugefügt (UserPromptSubmit Spezial!)
#   Log    → .workflow/logs/hooks.log
#
# WICHTIG: stdout wird immer injiziert! Nur ausgeben wenn nötig.
# ═══════════════════════════════════════════════════════════════════════════
# BASH 3.x KOMPATIBEL (macOS default)
# ═══════════════════════════════════════════════════════════════════════════

set -e

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
LOGS_DIR="${WORKFLOW_DIR}/logs"

# ═══════════════════════════════════════════════════════════════════════════
# KEIN WORKFLOW → NICHTS TUN
# ═══════════════════════════════════════════════════════════════════════════
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

# Inaktive Workflows → kein Output
if [ "$STATUS" = "completed" ] || [ "$STATUS" = "idle" ] || [ "$STATUS" = "unknown" ]; then
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# STOP HOOK BLOCK COUNTER ZURÜCKSETZEN
# Bei jedem User-Prompt wird der Counter auf 0 gesetzt,
# damit Auto-Advance nach User-Interaktion wieder funktioniert.
# ═══════════════════════════════════════════════════════════════════════════
if jq -e '.stopHookBlockCount > 0' "$WORKFLOW_FILE" > /dev/null 2>&1; then
  jq '.stopHookBlockCount = 0' "$WORKFLOW_FILE" > "${WORKFLOW_FILE}.tmp" 2>/dev/null && \
    mv "${WORKFLOW_FILE}.tmp" "$WORKFLOW_FILE"
fi

# ═══════════════════════════════════════════════════════════════════════════
# STATE LESEN
# ═══════════════════════════════════════════════════════════════════════════
PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE" 2>/dev/null || echo "0")
ISSUE_NUM=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE" 2>/dev/null || echo "?")
ISSUE_TITLE=$(jq -r '.issue.title // "Feature"' "$WORKFLOW_FILE" 2>/dev/null || echo "Feature")

# Phase-Namen (Bash 3.x kompatibel)
get_phase_name() {
  case $1 in
    0) echo "Tech Spec" ;; 1) echo "Wireframes" ;; 2) echo "API Design" ;;
    3) echo "Migrations" ;; 4) echo "Backend" ;; 5) echo "Frontend" ;;
    6) echo "E2E Tests" ;; 7) echo "Security Audit" ;; 8) echo "Code Review" ;;
    9) echo "Push & PR" ;; *) echo "Unknown" ;;
  esac
}

PHASE_NAME=$(get_phase_name $PHASE)
NEXT_PHASE=$((PHASE + 1))

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════
mkdir -p "$LOGS_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] UserPromptSubmit: Phase $PHASE ($PHASE_NAME) | Status: $STATUS" >> "$LOGS_DIR/hooks.log" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
# KONTEXT-INJECTION (stdout → Claudes Kontext)
# ═══════════════════════════════════════════════════════════════════════════

if [ "$STATUS" = "paused" ]; then
  PAUSE_REASON=$(jq -r '.pauseReason // "unbekannt"' "$WORKFLOW_FILE" 2>/dev/null)

  echo "<user-prompt-submit-hook>"
  echo "WORKFLOW PAUSIERT | Phase $PHASE ($PHASE_NAME) | Issue #$ISSUE_NUM"
  echo "Grund: $PAUSE_REASON"
  echo "Optionen: /byt8:wf-resume | /byt8:wf-retry-reset | /byt8:wf-skip"
  echo "</user-prompt-submit-hook>"
  exit 0
fi

if [ "$STATUS" = "awaiting_approval" ]; then
  echo "<user-prompt-submit-hook>"
  echo "WORKFLOW APPROVAL GATE | Phase $PHASE ($PHASE_NAME) | Issue #$ISSUE_NUM: $ISSUE_TITLE"
  echo ""

  case $PHASE in
    0)
      echo "Der User antwortet auf die Technical Specification (Phase 0)."
      echo ""
      echo "BEI APPROVAL (Ja/OK/Weiter):"
      echo "  1. jq '.status = \"active\" | .currentPhase = 1' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Task(byt8:ui-designer, 'Phase 1 (Wireframes) fuer Issue #$ISSUE_NUM: $ISSUE_TITLE')"
      echo ""
      echo "BEI FEEDBACK (Aenderungswuensche):"
      echo "  1. jq '.status = \"active\"' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Task(byt8:architect-planner, 'Revise Phase 0 based on feedback: {USER_FEEDBACK}')"
      ;;

    1)
      echo "Der User antwortet auf die Wireframes (Phase 1)."
      echo ""
      echo "BEI APPROVAL (Ja/OK/Weiter):"
      echo "  1. jq '.status = \"active\" | .currentPhase = 2' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Task(byt8:api-architect, 'Phase 2 (API Design) fuer Issue #$ISSUE_NUM: $ISSUE_TITLE')"
      echo "  3. Auto-Advance laeuft durch Phasen 2-6 bis Phase 7 (Approval Gate)"
      echo ""
      echo "BEI FEEDBACK (Aenderungswuensche):"
      echo "  1. jq '.status = \"active\"' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Task(byt8:ui-designer, 'Revise Phase 1 based on feedback: {USER_FEEDBACK}')"
      ;;

    7)
      echo "Der User antwortet auf das Security Audit Ergebnis (Phase 7)."
      echo ""
      echo "BEI APPROVAL (Weiter/OK):"
      echo "  1. jq '.status = \"active\" | .currentPhase = 8 | del(.securityFixCount)' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Task(byt8:code-reviewer, 'Phase 8 (Code Review) fuer Issue #$ISSUE_NUM: $ISSUE_TITLE')"
      echo ""
      echo "BEI SECURITY-FIXES:"
      echo "  1. ZUERST State updaten:"
      echo "     jq '.currentPhase = 6 | .status = \"active\" | del(.context.securityAudit) | del(.context.testResults) | .securityFixCount = (.securityFixCount // 0) + 1' \\"
      echo "       .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. DANN Fix-Agent starten:"
      echo "     Backend (.java) → Task(byt8:spring-boot-developer, 'Security Fix: {FINDINGS}')"
      echo "     Frontend (.ts/.html) → Task(byt8:angular-frontend-developer, 'Security Fix: {FINDINGS}')"
      echo "  3. Auto-Advance: Phase 6 (Tests) → Phase 7 (Re-Audit)"
      echo ""
      echo "BEI ALLGEMEINEN AENDERUNGEN (UI, Backend, Frontend, etc.):"
      echo "  PFLICHT-Reihenfolge fuer Rueckdelegation:"
      echo "  1. Ziel-Phase bestimmen:"
      echo "     Wireframes/UI=1 | API=2 | DB=3 | Backend=4 | Frontend=5 | Tests=6"
      echo "  2. ZUERST State updaten (ZIEL = ermittelte Phase-Nummer):"
      echo "     jq '.currentPhase = ZIEL | .status = \"active\" | del(.context.securityAudit) | del(.context.testResults)' \\"
      echo "       .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "     Wenn ZIEL <= 5: zusaetzlich del(.context.frontendImpl)"
      echo "     Wenn ZIEL <= 4: zusaetzlich del(.context.backendImpl)"
      echo "     Wenn ZIEL <= 3: zusaetzlich del(.context.migrations)"
      echo "  3. DANN Ziel-Agent starten:"
      echo "     Task(byt8:AGENT, 'Phase ZIEL (Hotfix): {USER_FEEDBACK}')"
      echo "  4. Auto-Advance laeuft automatisch bis Phase 7 (Re-Audit)"
      echo "  NIEMALS Agent aufrufen OHNE vorher currentPhase zu setzen!"
      ;;

    8)
      echo "Der User antwortet auf das Code Review Ergebnis (Phase 8)."
      echo ""
      echo "BEI APPROVAL (Weiter/OK):"
      echo "  1. jq '.status = \"active\" | .currentPhase = 9' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Phase 9: User fragen 'PR erstellen? Ziel-Branch?' (Default: fromBranch)"
      echo ""
      echo "BEI FEEDBACK (Aenderungswuensche an aktueller Phase):"
      echo "  1. jq '.status = \"active\"' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Task(byt8:code-reviewer, 'Revise Phase 8 based on feedback: {USER_FEEDBACK}')"
      ;;

    9)
      echo "Der User antwortet auf Push & PR (Phase 9)."
      echo ""
      echo "BEI APPROVAL (Ja, pushen):"
      echo "  1. jq '.pushApproved = true' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. git push -u origin BRANCH"
      echo "  3. gh pr create --base INTO_BRANCH --title 'feat(#$ISSUE_NUM): $ISSUE_TITLE' --body PR_BODY"
      echo "  4. jq '.status = \"completed\"' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      ;;
  esac

  echo "</user-prompt-submit-hook>"
  exit 0
fi

if [ "$STATUS" = "active" ]; then
  echo "<user-prompt-submit-hook>"
  echo "AKTIVER WORKFLOW | Phase $PHASE ($PHASE_NAME) | Issue #$ISSUE_NUM | Status: active"
  echo "Workflow laeuft. Bei Phase-Aktionen: lies .workflow/workflow-state.json fuer aktuellen State."
  echo "</user-prompt-submit-hook>"
  exit 0
fi

exit 0
