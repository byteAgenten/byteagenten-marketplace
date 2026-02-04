#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# bytA Agent Done Script (SubagentStop Hook)
# ═══════════════════════════════════════════════════════════════════════════
# 1. APPROVAL GATES: Erzwingt User-Approval nach bestimmten Agents
# 2. WIP-COMMITS: Erstellt Commits nach Implementation-Agents
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Read hook input from stdin
INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"' 2>/dev/null || echo "unknown")

# Log für Debugging
mkdir -p .workflow 2>/dev/null || true
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] AgentDone: $AGENT_TYPE" >> .workflow/hooks.log

# ═══════════════════════════════════════════════════════════════════════════
# APPROVAL GATES
# ═══════════════════════════════════════════════════════════════════════════
# Diese Agents erfordern User-Approval bevor es weitergeht

case "$AGENT_TYPE" in
  bytA-architect|bytA-orchestrator-architect)
    # Phase 0: Technical Spec - User muss Spec approven
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ ✅ PHASE 0 COMPLETE: Technical Specification                        │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    echo "│ Agent: $AGENT_TYPE                                                  │"
    echo "│                                                                     │"
    echo "│ APPROVAL REQUIRED:                                                  │"
    echo "│ Lies .workflow/phase-0-result.md und frage den User:               │"
    echo "│ \"Spec OK? Fortfahren mit der Implementierung?\"                     │"
    echo "└─────────────────────────────────────────────────────────────────────┘"
    echo ""

    # decision:block erzwingt dass Claude weitermacht mit unserer Anweisung
    jq -n '{
      "decision": "block",
      "reason": "APPROVAL GATE Phase 0: Zeige dem User eine Zusammenfassung der Spec aus .workflow/phase-0-result.md und frage: Spec OK? Fortfahren?"
    }'
    exit 0
    ;;

  bytA-ui-designer)
    # Phase 1: Wireframes - User muss UI approven
    jq -n '{
      "decision": "block",
      "reason": "APPROVAL GATE Phase 1: Zeige dem User die Wireframes aus .workflow/phase-1-result.md und frage: UI Design OK? Fortfahren?"
    }'
    exit 0
    ;;

  bytA-security)
    # Phase 7: Security Audit - User muss Findings approven
    jq -n '{
      "decision": "block",
      "reason": "APPROVAL GATE Phase 7: Zeige dem User die Security Findings aus .workflow/phase-7-result.md und frage: Security OK? Fortfahren oder Fixes nötig?"
    }'
    exit 0
    ;;

  bytA-reviewer)
    # Phase 8: Code Review - User muss Review approven
    jq -n '{
      "decision": "block",
      "reason": "APPROVAL GATE Phase 8: Zeige dem User das Review-Ergebnis aus .workflow/phase-8-result.md und frage: Code OK? PR erstellen oder Fixes nötig?"
    }'
    exit 0
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════
# WIP-COMMITS für Implementation-Agents
# ═══════════════════════════════════════════════════════════════════════════

case "$AGENT_TYPE" in
  bytA-backend-dev|bytA-frontend-dev|bytA-db-architect|bytA-test-engineer)
    # Check if there are changes to commit
    if ! git diff --quiet || ! git diff --cached --quiet; then
      # Get issue number from state
      ISSUE_NUM="?"
      if [ -f ".workflow/state.json" ]; then
        ISSUE_NUM=$(jq -r '.issue // "?"' .workflow/state.json 2>/dev/null || echo "?")
      fi

      # Create WIP commit
      git add -A 2>/dev/null || true
      git commit -m "wip(#${ISSUE_NUM}): ${AGENT_TYPE} changes" --no-verify 2>/dev/null || true

      echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] WIP-Commit: $AGENT_TYPE for #$ISSUE_NUM" >> .workflow/hooks.log
    fi
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════
# AUTO-ADVANCE für andere Agents (Phasen 2-6)
# Kein decision:block → Orchestrator kann automatisch weitermachen
# ═══════════════════════════════════════════════════════════════════════════

exit 0
