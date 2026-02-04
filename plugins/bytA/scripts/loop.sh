#!/bin/bash
# bytA Hybrid Loop - Boomerang + Ralph
#
# Usage:
#   ./loop.sh plan <issue>     # Planning mode - erstellt PLAN.md
#   ./loop.sh build [max]      # Building mode - arbeitet Tasks ab
#   ./loop.sh status           # Zeigt aktuellen Status

set -e

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Konfiguration
PLAN_FILE=".workflow/PLAN.md"
PROMPT_DIR="${CLAUDE_PLUGIN_ROOT}/prompts"
MAX_ITERATIONS="${2:-50}"

log() {
    echo -e "${BLUE}[bytA]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[bytA]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[bytA]${NC} $1"
}

log_error() {
    echo -e "${RED}[bytA]${NC} $1"
}

# Prüfe ob PLAN.md existiert
plan_exists() {
    [ -f "$PLAN_FILE" ]
}

# Zähle offene Tasks
count_open_tasks() {
    if plan_exists; then
        grep -c "^\- \[ \]" "$PLAN_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Zähle erledigte Tasks
count_done_tasks() {
    if plan_exists; then
        grep -c "^\- \[x\]" "$PLAN_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Status anzeigen
show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  bytA Hybrid Loop - Status"
    echo "═══════════════════════════════════════════════════════"

    if plan_exists; then
        local open=$(count_open_tasks)
        local done=$(count_done_tasks)
        local total=$((open + done))

        echo ""
        echo "  Plan:    $PLAN_FILE"
        echo "  Tasks:   $done / $total erledigt"
        echo "  Offen:   $open"
        echo ""

        if [ "$open" -eq 0 ]; then
            log_success "Alle Tasks erledigt!"
        else
            echo "  Nächste offene Tasks:"
            grep "^\- \[ \]" "$PLAN_FILE" | head -3 | sed 's/^/    /'
        fi
    else
        log_warn "Kein PLAN.md gefunden. Starte mit: ./loop.sh plan <issue>"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════"
}

# Planning Mode
run_planning() {
    local issue="$1"

    if [ -z "$issue" ]; then
        log_error "Usage: ./loop.sh plan <issue-number>"
        exit 1
    fi

    log "Starting Planning Mode für Issue #$issue..."

    mkdir -p .workflow

    # Erstelle Planning-Prompt
    cat > .workflow/PROMPT_plan.md << EOF
# bytA Planning Mode

## Deine Aufgabe

Erstelle einen Implementation Plan für Issue #$issue.

## Schritte

1. Lade das Issue: \`gh issue view $issue --json title,body,labels\`
2. Analysiere was implementiert werden muss
3. Erstelle den Plan in \`.workflow/PLAN.md\`

## PLAN.md Format

\`\`\`markdown
# Implementation Plan: Issue #$issue - [TITLE]

## Status: PLANNING

## Tasks

### API Design
- [ ] Task 1
- [ ] Task 2

### Database
- [ ] Task 1

### Backend
- [ ] Task 1
- [ ] Task 2

### Frontend
- [ ] Task 1

### E2E Tests
- [ ] Task 1

## Completion Criteria
- [ ] All tasks checked
- [ ] All tests pass
\`\`\`

## Wichtig

- Jeder Task sollte KLEIN und FOKUSSIERT sein
- Nutze die Kategorien: API Design, Database, Backend, Frontend, E2E Tests
- Schreibe NUR den Plan, implementiere NICHTS
EOF

    log "Starte Claude für Planning..."

    # Rufe Claude auf
    cat .workflow/PROMPT_plan.md | claude -p --model sonnet

    if plan_exists; then
        log_success "Plan erstellt: $PLAN_FILE"
        show_status

        echo ""
        log "Prüfe den Plan und starte dann: ./loop.sh build"
    else
        log_error "Plan wurde nicht erstellt. Prüfe die Ausgabe."
    fi
}

# Building Mode - Eine Iteration
run_build_iteration() {
    local iteration="$1"

    log "Iteration $iteration - Suche nächsten Task..."

    local open=$(count_open_tasks)

    if [ "$open" -eq 0 ]; then
        log_success "Alle Tasks erledigt!"
        return 1
    fi

    # Erstelle Build-Prompt
    cat > .workflow/PROMPT_build.md << EOF
# bytA Build Mode - Iteration $iteration

## Deine Aufgabe

1. Lies \`.workflow/PLAN.md\`
2. Finde den ERSTEN Task der noch offen ist (\`- [ ]\`)
3. Implementiere NUR DIESEN EINEN Task
4. Markiere ihn als erledigt (\`- [x]\`)
5. Committe die Änderung

## Agent-Routing

Basierend auf der Task-Kategorie, nutze den passenden Agent:

| Kategorie | Agent |
|-----------|-------|
| API Design | byt8:api-architect |
| Database | byt8:postgresql-architect |
| Backend | bytA-auto-backend-dev |
| Frontend | bytA-auto-frontend-dev |
| E2E Tests | bytA-auto-test-engineer |

## Workflow

1. \`Task(AGENT, "Implementiere: [TASK_DESCRIPTION]")\`
2. Nach Implementation: Tests laufen lassen
3. Wenn Tests OK: Task in PLAN.md als \`[x]\` markieren
4. Commit: \`git commit -m "feat: [task description]"\`

## WICHTIG

- NUR EINEN Task pro Iteration
- Tests MÜSSEN passieren bevor Commit
- Wenn Tests fehlschlagen: Fixe es in dieser Iteration
- Update PLAN.md NACH erfolgreicher Implementation

## Backpressure

Nach Code-Änderungen:
- Backend: \`cd backend && ./mvnw test\`
- Frontend: \`cd frontend && npm test\`
- E2E: \`cd frontend && npm run e2e\`

Nur wenn Tests passieren → Commit → Exit
EOF

    log "Starte Claude für Build-Iteration..."

    # Rufe Claude auf
    cat .workflow/PROMPT_build.md | claude -p --model sonnet --dangerously-skip-permissions

    return 0
}

# Building Mode - Loop
run_building() {
    local max="${1:-$MAX_ITERATIONS}"

    if ! plan_exists; then
        log_error "Kein PLAN.md gefunden. Starte zuerst: ./loop.sh plan <issue>"
        exit 1
    fi

    log "Starting Building Mode (max $max Iterationen)..."
    show_status

    local iteration=1

    while [ $iteration -le $max ]; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        if ! run_build_iteration $iteration; then
            break
        fi

        show_status

        iteration=$((iteration + 1))

        # Kurze Pause zwischen Iterationen
        sleep 2
    done

    echo ""
    if [ $(count_open_tasks) -eq 0 ]; then
        log_success "Building abgeschlossen! Alle Tasks erledigt."
        echo ""
        log "Nächster Schritt: Security Audit & Code Review"
    else
        log_warn "Max Iterationen erreicht. $(count_open_tasks) Tasks noch offen."
    fi
}

# Main
case "${1:-status}" in
    plan)
        run_planning "$2"
        ;;
    build)
        run_building "$2"
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: ./loop.sh [plan|build|status] [args]"
        echo ""
        echo "Commands:"
        echo "  plan <issue>   - Erstelle Implementation Plan"
        echo "  build [max]    - Arbeite Tasks ab (default: 50 max)"
        echo "  status         - Zeige aktuellen Status"
        exit 1
        ;;
esac
