#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA User Prompt Context Injection (UserPromptSubmit Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert bei JEDEM User-Prompt. stdout wird in Claudes Kontext injiziert.
#
# Zweck:
# 1. Workflow-Status in Claudes Kontext halten
# 2. Approval-Gate-Anweisungen injizieren (Option C: Heuristik + User-Wahl)
# 3. stopHookBlockCount zuruecksetzen (Loop-Prevention Reset)
# ═══════════════════════════════════════════════════════════════════════════
# BASH 3.x KOMPATIBEL (macOS default)
# ═══════════════════════════════════════════════════════════════════════════

# Hook CWD fix: cd ins Projekt-Root aus Hook-Input
_HOOK_INPUT=$(cat)
_HOOK_CWD=$(echo "$_HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$_HOOK_CWD" ] && [ -d "$_HOOK_CWD" ] && cd "$_HOOK_CWD"

set -e

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
LOGS_DIR="${WORKFLOW_DIR}/logs"

# Source phase configuration (CLAUDE_PLUGIN_ROOT bevorzugt)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
source "${SCRIPT_DIR}/../config/phases.conf"

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
# STOP HOOK BLOCK COUNTER ZURUECKSETZEN
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
PHASE_NAME=$(get_phase_name "$PHASE")

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════
mkdir -p "$LOGS_DIR" 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] UserPromptSubmit: Phase $PHASE ($PHASE_NAME) | Status: $STATUS" >> "$LOGS_DIR/hooks.log" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
# ROLLBACK-HILFSFUNKTION (deterministisch)
# ═══════════════════════════════════════════════════════════════════════════
print_rollback_instructions() {
  local from_phase=$1
  echo ""
  echo "  BEI AENDERUNGSWUENSCHEN (Rollback):"
  echo "  Der User kann ein Rollback-Ziel angeben:"
  echo "  → 0 = Tech Spec (architect-planner)"
  echo "  → 1 = Wireframes (ui-designer)"
  echo "  → 2 = API Design (api-architect)"
  echo "  → 3 = Database (postgresql-architect)"
  echo "  → 4 = Backend (spring-boot-developer)"
  echo "  → 5 = Frontend (angular-frontend-developer)"
  echo "  → 6 = Tests (test-engineer)"
  echo ""
  echo "  ABLAUF bei Rollback (REIHENFOLGE PFLICHT!):"
  echo "  1. Ziel-Phase aus User-Antwort bestimmen"
  echo "  2. ZUERST State updaten:"
  echo "     jq '.currentPhase = ZIEL | .status = \"active\" | del(.context.securityAudit) | del(.context.testResults)' \\"
  echo "       .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
  echo "     Wenn ZIEL <= 5: zusaetzlich del(.context.frontendImpl)"
  echo "     Wenn ZIEL <= 4: zusaetzlich del(.context.backendImpl)"
  echo "     Wenn ZIEL <= 3: zusaetzlich del(.context.migrations)"
  echo "     Wenn ZIEL <= 2: zusaetzlich del(.context.apiDesign)"
  echo "     Wenn ZIEL <= 1: zusaetzlich del(.context.wireframes)"
  echo "  3. DANN Spec-Dateien ab Rollback-Ziel loeschen (PFLICHT — verhindert stale GLOB-Matches!):"
  echo "     for p in \$(seq ZIEL 8); do pf=\$(printf '%02d' \$p); rm -f .workflow/specs/issue-*-ph\${pf}-*.md; done"
  echo "  4. DANN Agent starten mit User-Feedback im Prompt:"
  echo "     Task(bytA:AGENT, 'Phase ZIEL (Hotfix): {USER_FEEDBACK}')"
  echo "  5. Auto-Advance laeuft automatisch bis zum naechsten Approval Gate"
  echo "  NIEMALS Agent aufrufen OHNE vorher currentPhase zu setzen!"
}

# ═══════════════════════════════════════════════════════════════════════════
# KONTEXT-INJECTION (stdout → Claudes Kontext)
# ═══════════════════════════════════════════════════════════════════════════

if [ "$STATUS" = "paused" ]; then
  PAUSE_REASON=$(jq -r '.pauseReason // "unbekannt"' "$WORKFLOW_FILE" 2>/dev/null)
  echo "<user-prompt-submit-hook>"
  echo "WORKFLOW PAUSIERT | Phase $PHASE ($PHASE_NAME) | Issue #$ISSUE_NUM"
  echo "Grund: $PAUSE_REASON"
  echo "Optionen: /bytA:wf-resume | /bytA:wf-retry-reset | /bytA:wf-skip"
  echo "</user-prompt-submit-hook>"
  exit 0
fi

if [ "$STATUS" = "awaiting_approval" ]; then
  echo "<user-prompt-submit-hook>"
  echo "WORKFLOW APPROVAL GATE | Phase $PHASE ($PHASE_NAME) | Issue #$ISSUE_NUM: $ISSUE_TITLE"
  echo ""

  case $PHASE in
    0)
      NEXT_PHASE=$(get_next_active_phase "$PHASE" "$WORKFLOW_FILE")
      NEXT_NAME=$(get_phase_name "$NEXT_PHASE")
      NEXT_AGENT=$(get_phase_agent "$NEXT_PHASE")
      echo "Der User antwortet auf die Technical Specification (Phase 0)."
      echo ""
      echo "BEI APPROVAL (Ja/OK/Weiter):"
      echo "  1. State updaten:"
      echo "     jq '.status = \"active\" | .currentPhase = $NEXT_PHASE' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Prompt bauen (Bash-Befehl ausfuehren, Output merken):"
      echo "     ${CLAUDE_PLUGIN_ROOT}/scripts/wf_prompt_builder.sh $NEXT_PHASE"
      echo "  3. Agent starten mit dem KOMPLETTEN Output von Schritt 2:"
      echo "     Task(bytA:$NEXT_AGENT, '<output>')"
      echo ""
      echo "BEI FEEDBACK (Aenderungswuensche):"
      echo "  1. jq '.status = \"active\"' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Prompt bauen mit Feedback (Bash-Befehl ausfuehren):"
      echo "     ${CLAUDE_PLUGIN_ROOT}/scripts/wf_prompt_builder.sh 0 'USER_FEEDBACK_HIER_EINFUEGEN'"
      echo "  3. Task(bytA:architect-planner, '<output>')"
      ;;

    1)
      NEXT_PHASE=$(get_next_active_phase "$PHASE" "$WORKFLOW_FILE")
      NEXT_NAME=$(get_phase_name "$NEXT_PHASE")
      NEXT_AGENT=$(get_phase_agent "$NEXT_PHASE")
      echo "Der User antwortet auf die Wireframes (Phase 1)."
      echo ""
      echo "BEI APPROVAL (Ja/OK/Weiter):"
      echo "  1. State updaten:"
      echo "     jq '.status = \"active\" | .currentPhase = $NEXT_PHASE' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Prompt bauen (Bash-Befehl ausfuehren, Output merken):"
      echo "     ${CLAUDE_PLUGIN_ROOT}/scripts/wf_prompt_builder.sh $NEXT_PHASE"
      echo "  3. Agent starten mit dem KOMPLETTEN Output von Schritt 2:"
      echo "     Task(bytA:$NEXT_AGENT, '<output>')"
      echo "  4. Auto-Advance laeuft durch AUTO-Phasen bis zum naechsten Approval Gate"
      echo ""
      echo "BEI FEEDBACK (Aenderungswuensche):"
      echo "  1. jq '.status = \"active\"' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Prompt bauen mit Feedback (Bash-Befehl ausfuehren):"
      echo "     ${CLAUDE_PLUGIN_ROOT}/scripts/wf_prompt_builder.sh 1 'USER_FEEDBACK_HIER_EINFUEGEN'"
      echo "  3. Task(bytA:ui-designer, '<output>')"
      ;;

    7)
      NEXT_PHASE=$(get_next_active_phase "$PHASE" "$WORKFLOW_FILE")
      NEXT_NAME=$(get_phase_name "$NEXT_PHASE")
      NEXT_AGENT=$(get_phase_agent "$NEXT_PHASE")
      echo "Der User antwortet auf das Security Audit Ergebnis (Phase 7)."
      echo ""
      echo "BEI APPROVAL (Weiter/OK):"
      echo "  1. State updaten:"
      echo "     jq '.status = \"active\" | .currentPhase = $NEXT_PHASE' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Prompt bauen (Bash-Befehl ausfuehren, Output merken):"
      echo "     ${CLAUDE_PLUGIN_ROOT}/scripts/wf_prompt_builder.sh $NEXT_PHASE"
      echo "  3. Agent starten mit dem KOMPLETTEN Output von Schritt 2:"
      echo "     Task(bytA:$NEXT_AGENT, '<output>')"
      echo ""
      echo "BEI SECURITY-FIXES:"
      echo "  1. ZUERST State updaten:"
      echo "     jq '.currentPhase = 6 | .status = \"active\" | del(.context.securityAudit) | del(.context.testResults)' \\"
      echo "       .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Spec-Dateien ab Phase 6 loeschen (PFLICHT — verhindert stale GLOB-Matches!):"
      echo "     for p in \$(seq 6 8); do pf=\$(printf '%02d' \$p); rm -f .workflow/specs/issue-*-ph\${pf}-*.md; done"
      echo "  3. DANN Fix-Agent starten:"
      echo "     Backend (.java) → Task(bytA:spring-boot-developer, 'Security Fix: {FINDINGS}')"
      echo "     Frontend (.ts/.html) → Task(bytA:angular-frontend-developer, 'Security Fix: {FINDINGS}')"
      echo "  4. Auto-Advance: Phase 6 (Tests) → Phase 7 (Re-Audit)"
      print_rollback_instructions 7
      ;;

    8)
      echo "Der User antwortet auf das Code Review Ergebnis (Phase 8)."
      echo ""
      echo "BEI APPROVAL (Weiter/OK):"
      echo "  1. jq '.status = \"awaiting_approval\" | .currentPhase = 9 | .context.reviewFeedback.userApproved = true' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Phase 9: User fragen 'PR erstellen? Ziel-Branch?' (Default: fromBranch)"
      echo ""
      echo "BEI FEEDBACK:"
      echo "  1. jq '.status = \"active\"' .workflow/workflow-state.json > tmp && mv tmp .workflow/workflow-state.json"
      echo "  2. Prompt bauen mit Feedback (Bash-Befehl ausfuehren):"
      echo "     ${CLAUDE_PLUGIN_ROOT}/scripts/wf_prompt_builder.sh 8 'USER_FEEDBACK_HIER_EINFUEGEN'"
      echo "  3. Task(bytA:code-reviewer, '<output>')"

      # Option C: Dateipfad-basierte Heuristik + User-Wahl
      FIX_FILES=$(jq -r '.context.reviewFeedback.fixes[]?.file // empty' "$WORKFLOW_FILE" 2>/dev/null || echo "")
      if [ -n "$FIX_FILES" ]; then
        SUGGESTED=6
        if echo "$FIX_FILES" | grep -q '\.sql'; then SUGGESTED=3; fi
        if echo "$FIX_FILES" | grep -q '\.java'; then SUGGESTED=4; fi
        if echo "$FIX_FILES" | grep -q -E '\.(ts|html|scss)'; then SUGGESTED=5; fi
        SUGGESTED_NAME=$(get_phase_name "$SUGGESTED")
        echo ""
        echo "  OPTION C - VORGESCHLAGENES ROLLBACK-ZIEL:"
        echo "  → Phase $SUGGESTED ($SUGGESTED_NAME) basierend auf betroffenen Dateien:"
        echo "    $FIX_FILES"
        echo "  User kann bestaetigen oder anderes Ziel waehlen."
      fi
      print_rollback_instructions 8
      ;;

    9)
      echo "Der User antwortet auf Push & PR (Phase 9)."
      echo ""
      echo "PRE-PUSH BUILD GATE (PFLICHT!):"
      echo "  BEVOR du pushst, MUSST du sicherstellen dass alle Tests gruen sind:"
      echo "  1. cd backend && mvn verify (Backend Tests)"
      echo "  2. cd frontend && npm test -- --no-watch --browsers=ChromeHeadless (Frontend Tests)"
      echo "  3. cd frontend && npm run build (Build pruefen)"
      echo "  Bei FEHLERN: NICHT pushen! Zurueck zu Phase 6 (test-engineer)."
      echo ""
      echo "BEI APPROVAL (Ja, pushen) UND GRUENEN TESTS:"
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
