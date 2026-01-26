#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# byt8 Subagent Done Handler (SubagentStop Hook)
# ═══════════════════════════════════════════════════════════════════════════
# Feuert wenn ein Subagent fertig ist.
# Validiert die Outputs je nach Agent-Typ.
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════
LOG_DIR=".workflow/logs"
mkdir -p "$LOG_DIR"
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] SubagentStop Hook fired" >> "$LOG_DIR/hooks.log"

WORKFLOW_DIR=".workflow"
WORKFLOW_FILE="${WORKFLOW_DIR}/workflow-state.json"

# Prüfen ob Workflow aktiv
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

STATUS=$(jq -r '.status // "unknown"' "$WORKFLOW_FILE" 2>/dev/null || echo "unknown")

if [ "$STATUS" != "active" ]; then
  exit 0
fi

CURRENT_PHASE=$(jq -r '.currentPhase // 0' "$WORKFLOW_FILE")
CURRENT_AGENT=$(jq -r '.currentAgent // ""' "$WORKFLOW_FILE")

# ═══════════════════════════════════════════════════════════════════════════
# AGENT-SPEZIFISCHE VALIDIERUNG
# ═══════════════════════════════════════════════════════════════════════════

validate_output() {
  case "$CURRENT_AGENT" in
    *"architect-planner"*)
      # Tech Spec muss vorhanden sein
      if ! jq -e '.context.technicalSpec.data' "$WORKFLOW_FILE" > /dev/null 2>&1; then
        echo "⚠️  Architect-Planner: Technical Spec fehlt im Context!"
        return 1
      fi
      ;;
      
    *"ui-designer"*)
      # Mindestens eine Wireframe-Datei muss existieren
      if ! ls wireframes/*.html > /dev/null 2>&1 && ! ls wireframes/*.svg > /dev/null 2>&1; then
        echo "⚠️  UI-Designer: Keine Wireframe-Dateien gefunden!"
        return 1
      fi
      # data-testid Check
      if ls wireframes/*.html > /dev/null 2>&1; then
        local missing_testid=$(grep -L 'data-testid' wireframes/*.html 2>/dev/null | wc -l)
        if [ "$missing_testid" -gt 0 ]; then
          echo "⚠️  UI-Designer: $missing_testid Wireframes ohne data-testid Attribute!"
        fi
      fi
      ;;
      
    *"api-architect"*)
      # API Design muss vorhanden sein
      if ! jq -e '.context.apiDesign.data' "$WORKFLOW_FILE" > /dev/null 2>&1; then
        echo "⚠️  API-Architect: API Design fehlt im Context!"
        return 1
      fi
      ;;
      
    *"postgresql-architect"*)
      # Migration-Dateien müssen existieren
      if ! ls backend/src/main/resources/db/migration/V*.sql > /dev/null 2>&1; then
        echo "⚠️  PostgreSQL-Architect: Keine Migration-Dateien gefunden!"
        return 1
      fi
      ;;
      
    *"spring-boot-developer"*)
      # Java-Dateien müssen kompilieren
      if [ -d "backend" ]; then
        if ! (cd backend && mvn compile -q 2>/dev/null); then
          echo "⚠️  Spring-Boot-Developer: Code kompiliert nicht!"
          return 1
        fi
      fi
      ;;
      
    *"angular-frontend-developer"*)
      # TypeScript muss kompilieren
      if [ -d "frontend" ]; then
        if ! (cd frontend && npm run build --silent 2>/dev/null); then
          echo "⚠️  Angular-Developer: Build fehlgeschlagen!"
          return 1
        fi
      fi
      ;;
      
    *"test-engineer"*)
      # Test-Dateien müssen existieren
      local test_files_found=false
      if ls e2e/**/*.spec.ts > /dev/null 2>&1; then
        test_files_found=true
      fi
      if ls tests/**/*.spec.ts > /dev/null 2>&1; then
        test_files_found=true
      fi
      if [ "$test_files_found" = false ]; then
        echo "⚠️  Test-Engineer: Keine E2E Test-Dateien gefunden!"
        return 1
      fi
      ;;
      
    *"code-reviewer"*|*"security-auditor"*|*"architect-reviewer"*)
      # Review-Feedback muss im Context sein
      if ! jq -e '.context.reviewFeedback' "$WORKFLOW_FILE" > /dev/null 2>&1; then
        echo "⚠️  Reviewer: Review-Feedback fehlt im Context!"
        return 1
      fi
      ;;
  esac
  
  return 0
}

# ═══════════════════════════════════════════════════════════════════════════
# VALIDIERUNG AUSFÜHREN
# ═══════════════════════════════════════════════════════════════════════════

if [ -n "$CURRENT_AGENT" ] && [ "$CURRENT_AGENT" != "null" ]; then
  if validate_output; then
    echo ""
    echo "✅ Subagent $CURRENT_AGENT: Output validiert"
    echo ""
  else
    echo ""
    echo "───────────────────────────────────────────────────────────────────────────────"
    echo "⚠️  Subagent-Output Validierung fehlgeschlagen"
    echo "    Agent: $CURRENT_AGENT"
    echo "    Phase: $CURRENT_PHASE"
    echo "───────────────────────────────────────────────────────────────────────────────"
    echo ""
    # Nicht exit 1 - nur warnen, nicht blockieren
  fi
fi
