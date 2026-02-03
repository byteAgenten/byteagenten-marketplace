#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Session Recovery Script
# ═══════════════════════════════════════════════════════════════════════════
# Feuert bei SessionStart nach Context Overflow.
# Wenn aktiver Workflow existiert → Vollständigen Recovery-Prompt ausgeben.
# Auch: Auto-Setup der Project Hooks falls nicht vorhanden.
# ═══════════════════════════════════════════════════════════════════════════

set -e

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"
CONTEXT_DIR="${WORKFLOW_DIR}/context"
RECOVERY_DIR="${WORKFLOW_DIR}/recovery"

# ═══════════════════════════════════════════════════════════════════════════
# PRÜFEN: Aktiver Workflow vorhanden?
# ═══════════════════════════════════════════════════════════════════════════

if [ ! -f "$WORKFLOW_FILE" ]; then
  # Kein aktiver Workflow - nichts zu tun
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

if [ "$STATUS" != "active" ] && [ "$STATUS" != "paused" ] && [ "$STATUS" != "awaiting_approval" ]; then
  # Workflow nicht aktiv - nichts zu tun
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# RECOVERY MODE: Kontext sammeln und ausgeben
# ═══════════════════════════════════════════════════════════════════════════

CURRENT_PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE")
ISSUE_NUMBER=$(jq -r '.issue.number // "?"' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title // "Unbekannt"' "$WORKFLOW_FILE")
PAUSE_REASON=$(jq -r '.pauseReason // ""' "$WORKFLOW_FILE")

# Recovery-Prompt Header
cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║  ⛔ WORKFLOW RECOVERY - LIES DIESEN GESAMTEN BLOCK SORGFÄLTIG!               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  Du hast einen Context Overflow erlebt. Dein Wissen aus der vorherigen       ║
║  Session ist VERLOREN. Alles was du brauchst steht HIER.                     ║
║                                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "📋 AKTUELLER STATUS"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "  Issue:         #${ISSUE_NUMBER} - ${ISSUE_TITLE}"
echo "  Phase:         ${CURRENT_PHASE}"
echo "  Status:        ${STATUS}"

if [ -n "$PAUSE_REASON" ] && [ "$PAUSE_REASON" != "null" ]; then
  echo "  Pause-Grund:   ${PAUSE_REASON}"
fi

# Retry-Status
if [ -f "${RECOVERY_DIR}/retry-tracker.json" ]; then
  RETRY_COUNT=$(jq -r ".phase_${CURRENT_PHASE} // 0" "${RECOVERY_DIR}/retry-tracker.json" 2>/dev/null || echo "0")
  echo "  Retry-Status:  ${RETRY_COUNT}/3 Versuche"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# KONTEXT AUS ABGESCHLOSSENEN PHASEN
# ═══════════════════════════════════════════════════════════════════════════

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "📚 KONTEXT AUS VORHERIGEN PHASEN"
echo "═══════════════════════════════════════════════════════════════════════════════"

PHASE_NAMES=("Tech Spec" "Wireframes" "API Design" "Migrations" "Backend" "Frontend" "E2E Tests" "Security Audit" "Code Review" "Push & PR")
PHASE_FILES=("spec" "wireframes" "api" "migrations" "backend" "frontend" "tests" "security" "review" "pr")

for i in $(seq 0 $((CURRENT_PHASE - 1))); do
  PHASE_FILE="${CONTEXT_DIR}/phase-${i}-${PHASE_FILES[$i]}.json"
  
  if [ -f "$PHASE_FILE" ]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────────────────"
    echo "Phase ${i} (${PHASE_NAMES[$i]}):"
    echo "───────────────────────────────────────────────────────────────────────────────"
    
    # Phase-spezifische Summary extrahieren
    case $i in
      0) # Tech Spec
        jq -r '
          .summary |
          "  Affected Layers: \(.affectedLayers | join(", "))",
          "  New Entities: \(.newEntities | map(.name) | join(", "))",
          "  Modified Entities: \(.modifiedEntities | join(", "))",
          "  Risks: \(.risks | join("; "))",
          "  Decisions: \(.decisions | join("; "))"
        ' "$PHASE_FILE" 2>/dev/null || echo "  [Keine Details verfügbar]"
        ;;
      1) # Wireframes
        jq -r '
          .summary |
          "  Wireframes: \(.wireframes | join(", "))",
          "  Components: \(.components | join(", "))"
        ' "$PHASE_FILE" 2>/dev/null || echo "  [Keine Details verfügbar]"
        ;;
      2) # API Design
        echo "  Endpoints:"
        jq -r '.summary.endpoints[] | "    \(.method) \(.path) → \(.responseDto)"' "$PHASE_FILE" 2>/dev/null || echo "    [Keine]"
        echo "  DTOs:"
        jq -r '.summary.dtos[] | "    \(.name): \(.fields | join(", "))"' "$PHASE_FILE" 2>/dev/null || echo "    [Keine]"
        ;;
      3) # Migrations
        jq -r '
          .summary |
          "  Migration Files: \(.migrationFiles | join(", "))",
          "  Tables: \(.tables | join(", "))"
        ' "$PHASE_FILE" 2>/dev/null || echo "  [Keine Details verfügbar]"
        ;;
      4) # Backend
        jq -r '
          .summary |
          "  Created Classes: \(.createdClasses | join(", "))",
          "  Test Coverage: \(.testCoverage // "unbekannt")"
        ' "$PHASE_FILE" 2>/dev/null || echo "  [Keine Details verfügbar]"
        ;;
      5) # Frontend
        jq -r '
          .summary |
          "  Components: \(.components | join(", "))",
          "  Services: \(.services | join(", "))"
        ' "$PHASE_FILE" 2>/dev/null || echo "  [Keine Details verfügbar]"
        ;;
      6) # E2E Tests
        jq -r '
          .summary |
          "  Test Status: \(.testStatus)",
          "  Tests Passed: \(.testsPassed // "unbekannt")"
        ' "$PHASE_FILE" 2>/dev/null || echo "  [Keine Details verfügbar]"
        ;;
      7) # Security Audit
        jq -r '
          .summary |
          "  Findings: Critical=\(.severity.critical // 0) High=\(.severity.high // 0) Medium=\(.severity.medium // 0) Low=\(.severity.low // 0)",
          "  Hotfix Required: \(.hotfixRequired // false)"
        ' "$PHASE_FILE" 2>/dev/null || echo "  [Keine Details verfügbar]"
        ;;
      8) # Code Review
        jq -r '
          .summary |
          "  Review Status: \(.status)",
          "  Feedback: \(.feedback)"
        ' "$PHASE_FILE" 2>/dev/null || echo "  [Keine Details verfügbar]"
        ;;
    esac
    
    # forNextPhases für aktuelle Phase
    NEXT_HINT=$(jq -r ".forNextPhases[\"${CURRENT_PHASE}\"] // empty" "$PHASE_FILE" 2>/dev/null)
    if [ -n "$NEXT_HINT" ]; then
      echo "  → Für Phase ${CURRENT_PHASE}: ${NEXT_HINT}"
    fi
  fi
done

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# NÄCHSTER SCHRITT
# ═══════════════════════════════════════════════════════════════════════════

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "🎯 NÄCHSTER SCHRITT"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""

NEXT_ACTION=$(jq -r '.nextStep.action // "CONTINUE"' "$WORKFLOW_FILE")
NEXT_AGENT=$(jq -r '.nextStep.agent // ""' "$WORKFLOW_FILE")
NEXT_DESC=$(jq -r '.nextStep.description // ""' "$WORKFLOW_FILE")

echo "  Action:       ${NEXT_ACTION}"
if [ -n "$NEXT_AGENT" ] && [ "$NEXT_AGENT" != "null" ]; then
  echo "  Agent:        ${NEXT_AGENT}"
fi
if [ -n "$NEXT_DESC" ] && [ "$NEXT_DESC" != "null" ]; then
  echo "  Beschreibung: ${NEXT_DESC}"
fi

echo ""

# Phasen-spezifische Regeln
case $CURRENT_PHASE in
  0)
    cat << 'EOF'
  REGELN FÜR PHASE 0 (Tech Spec):
  - Erstelle Technical Spec mit architect-planner
  - Definiere affected layers, entities, risks
  - User-Approval erforderlich vor Phase 1
EOF
    ;;
  1)
    cat << 'EOF'
  REGELN FÜR PHASE 1 (Wireframes):
  - Erstelle HTML Wireframes mit ui-designer
  - data-testid Attribute für alle interaktiven Elemente
  - User-Approval erforderlich vor Phase 2
EOF
    ;;
  4)
    cat << 'EOF'
  REGELN FÜR PHASE 4 (Backend):
  - mvn test MUSS PASS sein vor Phase 5
  - WIP-Commit nach erfolgreichem Test
  - Bei FAIL: Hotfix und erneut versuchen
EOF
    ;;
  5)
    cat << 'EOF'
  REGELN FÜR PHASE 5 (Frontend):
  - npm test MUSS PASS sein vor Phase 6
  - WIP-Commit nach erfolgreichem Test
  - Bei FAIL: Hotfix und erneut versuchen
EOF
    ;;
  6)
    cat << 'EOF'
  REGELN FÜR PHASE 6 (E2E Tests):
  - Playwright Tests MÜSSEN PASS sein
  - Bei FAIL: Hotfix und erneut versuchen
  - Auto-Advance zu Phase 7 (Security Audit) wenn Tests grün
EOF
    ;;
  7)
    cat << 'EOF'
  REGELN FÜR PHASE 7 (Security Audit):
  - Security-Auditor prüft Backend und Frontend
  - Findings werden im Approval Gate angezeigt
  - User entscheidet: Fixen oder akzeptieren
  - Max 3 Fix-Iterationen (securityFixCount)
  - User-Approval erforderlich vor Phase 8
EOF
    ;;
  8)
    cat << 'EOF'
  REGELN FÜR PHASE 8 (Code Review):
  - Code-Reviewer prüft alle Änderungen
  - Bei APPROVED: Weiter zu Phase 9 (Push & PR)
  - Bei CHANGES_REQUESTED: Dynamischer Rollback zum frühesten Fix-Typ
    (database→3, backend→4, frontend→5, tests→6), dann Auto-Advance bis Phase 8
  - Max 3 Review-Iterationen, danach Pause
EOF
    ;;
  9)
    cat << 'EOF'
  REGELN FÜR PHASE 9 (Push & PR):
  ⛔ APPROVAL GATE - NICHTS AUTOMATISCH PUSHEN!
  1. User fragen: "In welchen Branch mergen? (Default: fromBranch)"
  2. PR-Body generieren aus allen context.* Keys
  3. PR-Body dem User ZEIGEN und FRAGEN: "Soll ich pushen und PR erstellen?"
  4. NUR bei explizitem Ja: git push + gh pr create
  5. State updaten: status = "completed"
  6. Workflow-Zusammenfassung mit Dauer anzeigen
EOF
    ;;
esac

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# ESCAPE COMMANDS
# ═══════════════════════════════════════════════════════════════════════════

if [ "$STATUS" == "paused" ]; then
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo "⚠️  WORKFLOW IST PAUSIERT"
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo ""
  echo "  Verfügbare Commands:"
  echo "  → /wf:resume        Workflow fortsetzen"
  echo "  → /wf:retry-reset   Retry-Counter zurücksetzen"
  echo "  → /wf:status        Detaillierten Status anzeigen"
  echo ""
fi

if [ "$STATUS" == "awaiting_approval" ]; then
  APPROVAL_PHASE=$(jq -r '.awaitingApprovalFor // .currentPhase' "$WORKFLOW_FILE" 2>/dev/null)
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo "⛔ APPROVAL GATE AKTIV - WARTE AUF USER!"
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo ""
  echo "  Phase ${APPROVAL_PHASE} wartet auf User-Approval."
  echo "  ⛔ NICHTS eigenständig ausführen! User MUSS zuerst bestätigen."
  echo "  → /byt8:wf-resume oder User antwortet direkt"
  echo ""
fi

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "⛔⛔⛔ PFLICHT-AKTION - KEINE EIGENSTÄNDIGEN AKTIONEN! ⛔⛔⛔"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "  Du hast einen Context Overflow erlebt. Du MUSST den Workflow neu betreten:"
echo ""
echo "  → Rufe /byt8:full-stack-feature auf!"
echo ""
echo "  ⛔ Du DARFST NICHT eigenständig handeln:"
echo "    - KEIN git push (durch PreToolUse-Hook BLOCKIERT)"
echo "    - KEIN gh pr create (durch PreToolUse-Hook BLOCKIERT)"
echo "    - KEIN eigenständiger git commit"
echo "    - KEINE Code-Änderungen ohne Workflow"
echo ""
echo "  NUR /byt8:full-stack-feature aufrufen. Sonst NICHTS."
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
