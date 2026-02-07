# Refactoring-Vorschlag: bytA Plugin — Boomerang + Ralph-Loop Architektur

**Datum:** 2026-02-07
**Basis:** byt8 v7.5.6 Full-Stack-Feature Workflow
**Ziel:** Deterministischer Umbau mit Boomerang-Orchestrierung und Ralph-Loop-Konvergenz

---

## 1. Zusammenfassung

Dieser Vorschlag beschreibt den Umbau des bestehenden byt8 Full-Stack-Feature Workflows
zu einer **absolut deterministischen** Architektur, die zwei bewährte Patterns kombiniert:

| Pattern | Kern-Idee | Anwendung im bytA |
|---------|-----------|-------------------|
| **Boomerang** (Roo Code) | Orchestrator delegiert isolierte Subtasks, erhält nur Summaries zurück | Phase-Agents laufen in völliger Kontext-Isolation, Orchestrator bleibt schlank |
| **Ralph Loop** (Geoffrey Huntley) | Bash-Loop mit externer Verifikation statt LLM-Selbstbewertung | Jede Phase wird in einer Retry-Loop ausgeführt, bis externe Done-Kriterien erfüllt sind |

**Kern-These:** Der Orchestrator trifft **keine** inhaltlichen Entscheidungen.
Er ist eine deterministische State Machine, die Agents dispatcht und deren Ergebnisse
extern verifiziert. Alle Entscheidungen sind entweder:

1. **Deterministisch** (Shell-Script prüft Dateien/State)
2. **Vom User getroffen** (Approval Gates)

---

## 2. Ist-Analyse: Probleme im aktuellen Design

### 2.1 Der Orchestrator ist zu smart

Das aktuelle Design vertraut dem Orchestrator (Claude) für:
- Interpretation von Agent-Outputs ("Ist Phase 4 wirklich fertig?")
- Rollback-Entscheidungen ("Welcher Agent muss fixen?")
- Context-Management ("Welche Spec-Pfade übergebe ich?")
- Phase-Transition-Logik ("Jetzt currentPhase hochsetzen")

**Problem:** Context Rot. Nach 5 Auto-Advance-Phasen (2-6) hat der Orchestrator ~300KB
Context gesehen. Seine Aufmerksamkeit auf die SKILL.md-Regeln nimmt ab. Fehler passieren
nicht wegen schlechter Regeln, sondern weil der LLM sie nach 30 Minuten vergisst.

### 2.2 Hooks kompensieren, aber fundamental

Die v7.0 Hook-Architektur kompensiert bereits viele LLM-Schwächen:
- `wf_engine.sh` erzwingt Auto-Advance via `decision:block`
- `block_orchestrator_code_edit.sh` verhindert Code-Edits
- `block_orchestrator_explore.sh` verhindert Exploration

Aber: Die Hooks **reagieren** auf LLM-Fehler, statt sie **strukturell unmöglich** zu machen.
Der Stop-Hook hat 15 Block-Iterationen als Safety Net — das zeigt, dass das System mit
LLM-Schleifen rechnet statt sie durch Design zu eliminieren.

### 2.3 Context-Bloat trotz File Reference Protocol

Das File Reference Protocol (v6.8.0) war ein wichtiger Schritt. Aber der Orchestrator
liest immer noch `workflow-state.json` und interpretiert es. Bei komplexen
Rollback-Szenarien (Phase 8 → Phase 4 → Auto-Advance → Phase 8) wächst der Context
trotzdem.

---

## 3. Ziel-Architektur: Boomerang + Ralph-Loop

### 3.1 Design-Prinzipien

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ABSOLUTE DETERMINISMUS-REGELN                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Der Orchestrator ist KEIN LLM.                                 │
│     Er ist ein Bash-Script (wf_orchestrator.sh).                   │
│                                                                     │
│  2. Phasen-Transitions passieren NUR in Shell-Scripts.             │
│     Claude setzt NIEMALS currentPhase.                             │
│                                                                     │
│  3. Done-Kriterien sind IMMER extern verifiziert.                  │
│     Shell-Scripts prüfen Dateien, Exit-Codes, JSON-Keys.           │
│     KEIN Agent entscheidet, ob er "fertig" ist.                    │
│                                                                     │
│  4. Jede Phase ist ein Ralph-Loop:                                 │
│     while !done; do spawn_agent; verify; done                      │
│                                                                     │
│  5. Agents erhalten NUR ihren Phase-Kontext.                       │
│     Kein Agent sieht den gesamten Workflow.                        │
│     (Boomerang: vollständige Kontext-Isolation)                    │
│                                                                     │
│  6. State lebt auf Disk, NIE im LLM-Kontext.                      │
│     (Ralph: "State management from memory to disk")                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Architektur-Diagramm

```
                    USER
                      │
                      ▼
              ┌───────────────┐
              │  /bytA:feature │  (Slash Command)
              └───────┬───────┘
                      │
                      ▼
        ┌─────────────────────────────┐
        │    wf_orchestrator.sh       │  ◄── DETERMINISTIC BASH LOOP
        │    (Outer Ralph Loop)       │
        │                             │
        │  while phase < MAX; do      │
        │    run_phase $phase         │
        │  done                       │
        └──────────┬──────────────────┘
                   │
                   ▼
        ┌─────────────────────────────┐
        │    run_phase()              │  ◄── INNER RALPH LOOP (per Phase)
        │                             │
        │  attempt=0                  │
        │  while !verify_done; do     │
        │    spawn_agent $phase       │
        │    attempt++                │
        │    if attempt >= MAX; then  │
        │      pause_for_user         │
        │    fi                       │
        │  done                       │
        │  transition_to_next         │
        └──────────┬──────────────────┘
                   │
                   ▼
        ┌─────────────────────────────┐
        │    spawn_agent()            │  ◄── BOOMERANG DELEGATION
        │                             │
        │  1. Build prompt from       │
        │     workflow-state.json     │
        │     (file paths only!)      │
        │                             │
        │  2. Task(byt8:agent,        │
        │     phase_prompt)           │
        │     → Agent in ISOLATION    │
        │     → Frischer Context      │
        │                             │
        │  3. Agent returns SUMMARY   │
        │     (max 10 Zeilen)         │
        │                             │
        │  4. Summary → /dev/null     │
        │     (State ist auf Disk!)   │
        └──────────┬──────────────────┘
                   │
                   ▼
        ┌─────────────────────────────┐
        │    verify_done()            │  ◄── EXTERNAL VERIFICATION
        │                             │
        │  Phase 0: file_exists       │
        │    specs/ph00-*.md          │
        │                             │
        │  Phase 4: exit_code == 0    │
        │    mvn verify               │
        │                             │
        │  Phase 6: allPassed==true   │
        │    + test exit codes         │
        │                             │
        │  Kein LLM beteiligt!        │
        └─────────────────────────────┘
```

### 3.3 Schlüssel-Innovation: Der Orchestrator wird zum Bash-Script

**Vorher (byt8 v7.5.6):**
```
Claude (LLM) → liest SKILL.md → interpretiert Regeln → ruft Task() auf → Hooks korrigieren Fehler
```

**Nachher (bytA):**
```
wf_orchestrator.sh (Bash) → deterministisch → ruft Task() via Claude auf → verifiziert extern
```

Die entscheidende Wende: Claude ist nicht mehr der Orchestrator. Claude ist nur noch
der **Transport-Layer** für Task()-Aufrufe. Die gesamte Workflow-Logik lebt in Shell-Scripts.

---

## 4. Detaillierter Phasen-Ablauf

### 4.1 Phase-Definitionen (identisch zu byt8, aber deterministisch gesteuert)

```bash
# phases.conf — Declarative Phase Configuration
PHASES=(
  "0|architect-planner|APPROVAL|specs/issue-*-ph00-architect-planner.md"
  "1|ui-designer|APPROVAL|wireframes/*.html"
  "2|api-architect|AUTO|specs/issue-*-ph02-api-architect.md"
  "3|postgresql-architect|AUTO|backend/src/main/resources/db/migration/V*.sql"
  "4|spring-boot-developer|AUTO|VERIFY:mvn verify"
  "5|angular-frontend-developer|AUTO|VERIFY:npm test -- --no-watch"
  "6|test-engineer|AUTO|STATE:context.testResults.allPassed==true"
  "7|security-auditor|APPROVAL|specs/issue-*-ph07-security-auditor.md"
  "8|code-reviewer|APPROVAL|STATE:context.reviewFeedback.userApproved==true"
  "9|ORCHESTRATOR|APPROVAL|STATE:phases.9.prUrl"
)
# Format: phase_num|agent|type|done_criterion
```

### 4.2 Done-Kriterien-Matrix (rein extern)

| Phase | Kriterium | Verifikations-Methode | LLM beteiligt? |
|-------|-----------|----------------------|----------------|
| 0 | Spec-Datei existiert | `ls .workflow/specs/*-ph00-*.md` | NEIN |
| 1 | Wireframe-Datei existiert | `ls wireframes/*.html` | NEIN |
| 2 | API-Spec existiert | `ls .workflow/specs/*-ph02-*.md` | NEIN |
| 3 | Migration-Datei existiert | `ls backend/.../V*.sql` | NEIN |
| 4 | Backend kompiliert + Tests gruen | `mvn verify` exit code | NEIN |
| 5 | Frontend Tests gruen | `npm test` exit code | NEIN |
| 6 | `allPassed == true` in State | `jq` auf workflow-state.json | NEIN |
| 7 | Audit-Datei existiert | `ls .workflow/specs/*-ph07-*.md` | NEIN |
| 8 | `userApproved == true` in State | `jq` auf workflow-state.json | NEIN |
| 9 | PR URL in State | `jq .phases["9"].prUrl` | NEIN |

### 4.3 Ralph-Loop pro Phase

```bash
run_phase() {
  local phase=$1
  local agent=$2
  local type=$3
  local done_criterion=$4
  local max_attempts=3
  local attempt=0

  # State updaten (deterministisch)
  update_state ".currentPhase = $phase | .status = \"active\""

  while true; do
    # === VERIFY (externe Pruefung) ===
    if verify_done "$phase" "$done_criterion"; then
      mark_phase_completed "$phase"

      if [ "$type" = "APPROVAL" ]; then
        update_state '.status = "awaiting_approval"'
        play_notification_sound
        # STOP: Warte auf User via UserPromptSubmit Hook
        return 0  # Signal: User muss approven
      else
        # AUTO: Naechste Phase (kein LLM beteiligt)
        create_wip_commit "$phase"
        return 1  # Signal: Weiter zur naechsten Phase
      fi
    fi

    # === RETRY LIMIT ===
    attempt=$((attempt + 1))
    if [ "$attempt" -gt "$max_attempts" ]; then
      update_state '.status = "paused" | .pauseReason = "max_retries_phase_'$phase'"'
      play_notification_sound
      return 0  # Signal: User muss eingreifen
    fi

    # === SPAWN AGENT (Boomerang) ===
    local prompt=$(build_phase_prompt "$phase" "$agent")

    # Hier wird Claude NUR als Transport genutzt:
    # Der Stop-Hook gibt ein decision:block JSON zurueck,
    # das Claude zwingt, den naechsten Task() aufzurufen.
    # Claude's "Entscheidung" ist vorbestimmt.
    output_block "RALPH-LOOP Phase $phase, Versuch $attempt/$max_attempts: Task(byt8:$agent, '$prompt')"
  done
}
```

### 4.4 Boomerang-Isolation pro Agent

```
┌─────────────────────────────────────────────────────────────┐
│  ORCHESTRATOR CONTEXT (minimal)                              │
│                                                              │
│  Sieht: workflow-state.json (Pfade, Phase-Nummer)           │
│  Sieht NICHT: Spec-Inhalte, Code, Test-Outputs              │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  AGENT CONTEXT (isoliert, frisch pro Aufruf)         │   │
│  │                                                       │   │
│  │  Liest selbst: Spec-Dateien (via Read Tool)          │   │
│  │  Liest selbst: Code (via Glob/Grep/Read)             │   │
│  │  Schreibt: Code, Specs, State-Updates                │   │
│  │  Returned: Summary (max 10 Zeilen) → Orchestrator    │   │
│  │                                                       │   │
│  │  ╔══════════════════════════════════════════════════╗ │   │
│  │  ║  KONTEXT-ISOLATION (Boomerang-Prinzip):          ║ │   │
│  │  ║                                                   ║ │   │
│  │  ║  - Kein Zugriff auf vorherige Agent-Outputs      ║ │   │
│  │  ║  - Kein Zugriff auf Orchestrator-Kontext         ║ │   │
│  │  ║  - Alle Infos via Disk (Specs, State)            ║ │   │
│  │  ║  - Frischer Context = keine Context Rot          ║ │   │
│  │  ╚══════════════════════════════════════════════════╝ │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  Agent fertig → Summary geht an Orchestrator                │
│  Orchestrator IGNORIERT Summary → prueft Disk-State          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Kritischer Punkt:** Der Orchestrator vertraut dem Agent-Summary NICHT.
Er verifiziert extern (Ralph-Prinzip: "External verification, not self-assessment").

---

## 5. Konkreter Umbau-Plan

### 5.1 Neue Datei-Struktur

```
plugins/bytA/
├── .claude-plugin/
│   └── plugin.json
├── agents/                        # Identisch zu byt8
│   ├── architect-planner.md
│   ├── ui-designer.md
│   ├── api-architect.md
│   ├── postgresql-architect.md
│   ├── spring-boot-developer.md
│   ├── angular-frontend-developer.md
│   ├── test-engineer.md
│   ├── security-auditor.md
│   ├── code-reviewer.md
│   └── architect-reviewer.md
├── commands/
│   └── feature.md                 # Einziger Einstiegspunkt
├── hooks/
│   └── hooks.json                 # Reduziert auf 4 Hooks
├── scripts/
│   ├── wf_orchestrator.sh         # NEU: Deterministischer Outer Loop
│   ├── wf_verify.sh               # NEU: Externe Done-Verifikation
│   ├── wf_prompt_builder.sh       # NEU: Baut Agent-Prompts deterministisch
│   ├── wf_user_prompt.sh          # Angepasst: Simpler, nur Approval-Kontext
│   ├── wf_cleanup.sh              # Unveraendert
│   ├── guard_git_push.sh          # Unveraendert
│   ├── block_orchestrator_code_edit.sh  # Unveraendert
│   ├── block_orchestrator_explore.sh    # Unveraendert
│   ├── subagent_start.sh          # Vereinfacht
│   └── subagent_done.sh           # Vereinfacht (WIP-Commits)
├── config/
│   └── phases.conf                # NEU: Deklarative Phase-Definition
├── skills/
│   └── feature/
│       └── SKILL.md               # Radikal vereinfacht
└── docs/
    └── architecture.md            # Dieses Dokument
```

### 5.2 Neue/Geaenderte Scripts

#### 5.2.1 `wf_orchestrator.sh` (NEU — Herzstück)

Dieses Script ersetzt die gesamte Orchestrator-Logik in SKILL.md.
Es wird vom **Stop Hook** aufgerufen und kontrolliert den gesamten Workflow.

```bash
#!/bin/bash
# wf_orchestrator.sh — Deterministischer Workflow-Orchestrator
# Implementiert: Outer Ralph Loop + Boomerang Dispatch

set -e

WORKFLOW_FILE=".workflow/workflow-state.json"
source "${CLAUDE_PLUGIN_ROOT}/config/phases.conf"

# ======================================================
# STATE LESEN
# ======================================================
PHASE=$(jq -r '.currentPhase' "$WORKFLOW_FILE")
STATUS=$(jq -r '.status' "$WORKFLOW_FILE")
ISSUE_NUM=$(jq -r '.issue.number' "$WORKFLOW_FILE")

# Nur bei status=active weiterverarbeiten
[ "$STATUS" != "active" ] && exit 0

# ======================================================
# PHASE-DATEN PARSEN (aus phases.conf)
# ======================================================
IFS='|' read -r PHASE_NUM AGENT PHASE_TYPE DONE_CRITERION <<< "${PHASES[$PHASE]}"

# ======================================================
# VERIFY: Ist die Phase fertig? (Externe Pruefung)
# ======================================================
if "${CLAUDE_PLUGIN_ROOT}/scripts/wf_verify.sh" "$PHASE" "$DONE_CRITERION"; then
  # Phase ist DONE
  mark_phase_done "$PHASE"

  if [ "$PHASE_TYPE" = "APPROVAL" ]; then
    # Approval Gate: Claude darf stoppen, User entscheidet
    jq '.status = "awaiting_approval"' "$WORKFLOW_FILE" > tmp && mv tmp "$WORKFLOW_FILE"
    exit 0
  else
    # Auto-Advance: Naechste Phase
    NEXT=$((PHASE + 1))
    jq ".currentPhase = $NEXT" "$WORKFLOW_FILE" > tmp && mv tmp "$WORKFLOW_FILE"
    create_wip_commit "$PHASE"

    # decision:block -> Claude MUSS Task() aufrufen
    jq -n --arg r "Phase $PHASE DONE. Starte Phase $NEXT: Task(byt8:$NEXT_AGENT, '...')" \
      '{"decision":"block","reason":$r}'
    exit 0
  fi
fi

# ======================================================
# RALPH LOOP: Phase nicht fertig -> Agent (re-)spawnen
# ======================================================
ATTEMPT=$(jq -r ".recovery.phase_${PHASE}_attempts // 0" "$WORKFLOW_FILE")
MAX=3

if [ "$ATTEMPT" -ge "$MAX" ]; then
  jq '.status = "paused" | .pauseReason = "max_attempts"' "$WORKFLOW_FILE" > tmp && mv tmp "$WORKFLOW_FILE"
  exit 0  # User muss eingreifen
fi

# Attempt zaehlen
jq ".recovery.phase_${PHASE}_attempts = $((ATTEMPT + 1))" "$WORKFLOW_FILE" > tmp && mv tmp "$WORKFLOW_FILE"

# Prompt deterministisch bauen (Shell, kein LLM!)
PROMPT=$("${CLAUDE_PLUGIN_ROOT}/scripts/wf_prompt_builder.sh" "$PHASE")

# decision:block -> Claude spawnt Agent
jq -n --arg r "RALPH-LOOP Phase $PHASE ($ATTEMPT/$MAX): Task(byt8:$AGENT, '$PROMPT')" \
  '{"decision":"block","reason":$r}'
```

#### 5.2.2 `wf_verify.sh` (NEU — Externe Verifikation)

```bash
#!/bin/bash
# wf_verify.sh — Externe Done-Verifikation (KEIN LLM!)
# Returncode: 0 = done, 1 = not done

PHASE=$1
CRITERION=$2
WORKFLOW_FILE=".workflow/workflow-state.json"

case "$CRITERION" in
  STATE:*)
    # JSON-State-Check: z.B. STATE:context.testResults.allPassed==true
    JQ_EXPR="${CRITERION#STATE:}"
    jq -e ".$JQ_EXPR" "$WORKFLOW_FILE" > /dev/null 2>&1
    ;;

  VERIFY:*)
    # Command-Execution: z.B. VERIFY:mvn verify
    CMD="${CRITERION#VERIFY:}"
    eval "$CMD" > /dev/null 2>&1
    ;;

  *)
    # Glob-Pattern: z.B. specs/issue-*-ph00-*.md
    ls $CRITERION > /dev/null 2>&1
    ;;
esac
```

#### 5.2.3 `wf_prompt_builder.sh` (NEU — Deterministischer Prompt-Bau)

```bash
#!/bin/bash
# wf_prompt_builder.sh — Baut Agent-Prompts deterministisch
# Kein LLM beteiligt! Prompt wird aus State + Templates gebaut.

PHASE=$1
WORKFLOW_FILE=".workflow/workflow-state.json"
TEMPLATE_DIR="${CLAUDE_PLUGIN_ROOT}/templates"

ISSUE_NUM=$(jq -r '.issue.number' "$WORKFLOW_FILE")
ISSUE_TITLE=$(jq -r '.issue.title' "$WORKFLOW_FILE")
TARGET_COV=$(jq -r '.targetCoverage' "$WORKFLOW_FILE")

# Spec-Pfade aus State extrahieren (File Reference Protocol)
TECH_SPEC=$(jq -r '.context.technicalSpec.specFile // ""' "$WORKFLOW_FILE")
API_SPEC=$(jq -r '.context.apiDesign.apiDesignFile // ""' "$WORKFLOW_FILE")
DB_SPEC=$(jq -r '.context.migrations.databaseFile // ""' "$WORKFLOW_FILE")

# Phase-spezifischer Prompt aus Template + State-Variablen
case $PHASE in
  0)
    echo "Phase 0: Create Technical Specification for Issue #$ISSUE_NUM: $ISSUE_TITLE. Target Coverage: $TARGET_COV%."
    ;;
  1)
    echo "Phase 1: Create Wireframes for Issue #$ISSUE_NUM: $ISSUE_TITLE. SPEC FILES: Tech Spec: $TECH_SPEC"
    ;;
  2)
    echo "Phase 2: Design API for Issue #$ISSUE_NUM. SPEC FILES: Tech Spec: $TECH_SPEC"
    ;;
  3)
    echo "Phase 3: Create DB Migrations for Issue #$ISSUE_NUM. SPEC FILES: Tech Spec: $TECH_SPEC, API: $API_SPEC"
    ;;
  4)
    echo "Phase 4: Implement Backend for Issue #$ISSUE_NUM. SPEC FILES: Tech Spec: $TECH_SPEC, API: $API_SPEC, DB: $DB_SPEC. Run mvn verify before completing."
    ;;
  5)
    WIREFRAMES=$(jq -r '.context.wireframes.paths // [] | join(", ")' "$WORKFLOW_FILE")
    echo "Phase 5: Implement Frontend for Issue #$ISSUE_NUM. SPEC FILES: Tech Spec: $TECH_SPEC, API: $API_SPEC, Wireframes: $WIREFRAMES. Run npm test before completing."
    ;;
  6)
    echo "Phase 6: Write E2E Tests for Issue #$ISSUE_NUM. SPEC FILES: Tech Spec: $TECH_SPEC. Target Coverage: $TARGET_COV%. Set allPassed=true ONLY if ALL tests pass."
    ;;
  7)
    echo "Phase 7: Security Audit for Issue #$ISSUE_NUM. SPEC FILES: Tech Spec: $TECH_SPEC. OWASP Top 10 check."
    ;;
  8)
    echo "Phase 8: Code Review for Issue #$ISSUE_NUM. SPEC FILES: Tech Spec: $TECH_SPEC, API: $API_SPEC. Target Coverage: $TARGET_COV%."
    ;;
esac
```

### 5.3 Vereinfachte SKILL.md

Die bisherige SKILL.md hat 270 Zeilen mit detaillierter Orchestrator-Logik.
Die neue SKILL.md wird auf ~40 Zeilen reduziert, weil die Logik in Shell lebt:

```markdown
---
description: Orchestrates full-stack feature development with deterministic Boomerang + Ralph-Loop automation.
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/block_orchestrator_code_edit.sh"
    - matcher: "Task"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/block_orchestrator_explore.sh"
---

# Full-Stack Feature Development (bytA)

## Deine Rolle

Du bist ein TRANSPORT-LAYER. Du fuehrst aus, was die Hooks dir sagen.

## Regeln

1. **Du triffst KEINE Entscheidungen.** Der Stop Hook sagt dir, was zu tun ist.
2. **Du schreibst KEINEN Code.** Hooks blockieren Edit/Write.
3. **Du aenderst NICHT den Workflow-State.** Nur Scripts aendern State.
4. **Du liest NUR workflow-state.json.** Keine Spec-Dateien.

## Startup

1. `${CLAUDE_PLUGIN_ROOT}/scripts/wf_cleanup.sh`
2. Falls kein Workflow: Frage User nach Issue und Branch, erstelle workflow-state.json
3. Starte Phase 0: `Task(byt8:architect-planner, ...)`
4. Ab hier uebernehmen die Hooks.

## Was bei Approval Gates passiert

Der UserPromptSubmit Hook injiziert dir Anweisungen.
Befolge sie woertlich. Interpretiere NICHTS.

## Was bei Auto-Advance passiert

Der Stop Hook gibt dir `decision:block` mit einer `reason`.
Die `reason` sagt dir exakt welchen Task() du starten sollst.
Fuehre ihn aus. Interpretiere NICHTS.
```

### 5.4 Reduzierte hooks.json

```json
{
  "description": "bytA Workflow Engine - Boomerang + Ralph-Loop (v8.0)",
  "version": "4.0.0",
  "hooks": {
    "UserPromptSubmit": [
      {
        "description": "Approval Gate Context Injection",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/wf_user_prompt.sh" }]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "description": "Guard: Block unauthorized git push",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/guard_git_push.sh" }]
      }
    ],
    "Stop": [
      {
        "description": "Deterministic Orchestrator (Ralph Loop + Verify)",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/wf_orchestrator.sh" }]
      }
    ],
    "SubagentStop": [
      {
        "description": "Deterministic WIP Commits",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/subagent_done.sh" }]
      }
    ]
  }
}
```

**Entfernt:**
- `SessionStart` Hook — Ralph-Loop braucht keine Session-Recovery, weil jeder Agent-Spawn ohnehin frisch ist. State ist auf Disk.
- `SubagentStart` Hook — Vereinfacht, Cleanup geschieht in `wf_cleanup.sh` beim Startup

---

## 6. Boomerang-Details: Kontext-Isolation

### 6.1 Informationsfluss (strikt unidirektional)

```
Orchestrator                    Agent
     │                            │
     │  ┌─── Phase-Prompt ────►  │  (nur Pfade, kein Inhalt)
     │  │                         │
     │  │                         │  Agent liest Specs selbst
     │  │                         │  Agent schreibt Code
     │  │                         │  Agent updatet State
     │  │                         │
     │  │  ◄── Summary (max 10z)  │  (Orchestrator IGNORIERT dies)
     │  │                         │
     │  ▼                         │
     │  wf_verify.sh prueft Disk  │  (externe Verifikation)
     │                            │
```

### 6.2 Was der Orchestrator NICHT sieht

| Information | Wo lebt sie? | Wer liest sie? |
|-------------|-------------|----------------|
| Spec-Inhalte | `.workflow/specs/*.md` | Nur Agents |
| Code-Aenderungen | `backend/`, `frontend/` | Nur Agents |
| Test-Outputs | Terminal (Agent-Context) | Nur Agents |
| Agent-Reasoning | Agent-Context (vergaenglich) | Niemand nach Termination |
| Fehler-Details | Agent-Context + Logs | Nur bei Retry der Agent selbst via Disk |

### 6.3 Was der Orchestrator SIEHT

| Information | Quelle | Wie |
|-------------|--------|-----|
| Aktuelle Phase | `workflow-state.json` | `jq .currentPhase` |
| Phase-Status | `workflow-state.json` | `jq .phases` |
| Done-Kriterium | `phases.conf` | Statisch definiert |
| Retry-Counter | `workflow-state.json` | `jq .recovery` |
| Approval-Status | `workflow-state.json` | `jq .status` |

---

## 7. Ralph-Loop-Details: Konvergenz-Garantien

### 7.1 Konvergenz-Eigenschaften

Der Ralph-Loop konvergiert, weil:

1. **Negative Feedback:** Fehler → Agent wird re-spawnt mit frischem Context
   - Kein Context Rot: Agent sieht nur aktuelle Disk-State
   - Jeder Retry ist ein "Clean Slate"

2. **Positive Feedback:** Erfolg → Done-Kriterium erfuellt → naechste Phase
   - Monotone Progression: Phasen gehen nur vorwaerts (ausser expliziter Rollback)

3. **Daempfung:** Max 3 Retries pro Phase
   - Verhindert endlose Schleifen
   - Nach 3 Fehlversuchen: User-Intervention (Pause)

4. **Persistenz:** State auf Disk, nicht im Context
   - Context Overflow ist irrelevant: State ueberlebt
   - Session Recovery wird trivial: Einfach workflow-state.json lesen

### 7.2 Failure Modes (deterministisch)

| Failure | Erkennung | Reaktion | Max Versuche |
|---------|-----------|----------|-------------|
| Agent schreibt keine Spec | `ls` findet keine Datei | Re-spawn Agent | 3 |
| Tests schlagen fehl | `mvn verify` exit != 0 | Re-spawn Agent mit "Fix tests" | 3 |
| Agent setzt State nicht | `jq` findet Key nicht | Re-spawn Agent | 3 |
| 3x fehlgeschlagen | Retry-Counter >= 3 | Workflow pausiert, User entscheidet | - |
| Context Overflow | SessionStart Hook | Liest Disk-State, faehrt fort | Unbegrenzt |
| Endlos-Loop | stopHookBlockCount >= 15 | Pause + User-Warnung | 15 |

### 7.3 Deterministic Context Allocation (Ralph-Prinzip)

```
Vorher (byt8):
  Orchestrator-Context waechst monoton:
  Phase 0 Summary + Phase 1 Summary + Phase 2 Summary + ...
  = Context Rot nach Phase 5

Nachher (bytA):
  Orchestrator-Context ist KONSTANT:
  workflow-state.json (2 KB) + Hook-Output (0.5 KB)
  = KEIN Context Rot, egal wie viele Phasen
```

---

## 8. Rollback-Mechanismus (deterministisch)

### 8.1 Rollback-Trigger

Rollbacks passieren NUR durch User-Entscheidung an Approval Gates:

| Gate | User sagt "Fix" | Rollback-Ziel |
|------|-----------------|---------------|
| Phase 7 (Security) | "Fix Security Issues" | Phase 4/5/6 (basierend auf Finding-Typ) |
| Phase 8 (Review) | "Changes Requested" | Phase 3/4/5/6 (basierend auf Fix-Typ) |

### 8.2 Rollback-Logik (Shell, kein LLM)

```bash
rollback_to() {
  local target=$1
  local reason=$2

  # 1. State bereinigen: Alles ab Ziel-Phase loeschen
  local clear_cmd=".currentPhase = $target | .status = \"active\""
  clear_cmd="$clear_cmd | del(.context.securityAudit) | del(.context.testResults)"
  [ "$target" -le 5 ] && clear_cmd="$clear_cmd | del(.context.frontendImpl)"
  [ "$target" -le 4 ] && clear_cmd="$clear_cmd | del(.context.backendImpl)"
  [ "$target" -le 3 ] && clear_cmd="$clear_cmd | del(.context.migrations)"

  jq "$clear_cmd" "$WORKFLOW_FILE" > tmp && mv tmp "$WORKFLOW_FILE"

  # 2. Retry-Counter fuer Rollback-Phase zuruecksetzen
  reset_retry "$target"

  # 3. Auto-Advance laeuft automatisch von target bis zum naechsten Approval Gate
}
```

### 8.3 Rollback-Ziel-Bestimmung (deterministisch)

```bash
determine_rollback_target() {
  local findings_json=$1

  # Deterministisch: Frueheste betroffene Phase gewinnt
  if echo "$findings_json" | jq -e '.[] | select(.type == "database")' > /dev/null 2>&1; then
    echo 3
  elif echo "$findings_json" | jq -e '.[] | select(.type == "backend")' > /dev/null 2>&1; then
    echo 4
  elif echo "$findings_json" | jq -e '.[] | select(.type == "frontend")' > /dev/null 2>&1; then
    echo 5
  else
    echo 6  # Default: Tests
  fi
}
```

---

## 9. Vergleich: byt8 vs. bytA

| Aspekt | byt8 (aktuell) | bytA (Vorschlag) |
|--------|---------------|-----------------|
| **Orchestrator** | Claude (LLM) mit SKILL.md Regeln | Bash-Script (wf_orchestrator.sh) |
| **Entscheidungen** | LLM interpretiert Regeln | Shell prueft deterministisch |
| **Done-Pruefung** | LLM liest Agent-Summary | Shell prueft Dateien/Exit-Codes |
| **Context-Wachstum** | Monoton steigend (Context Rot) | Konstant (~2.5 KB) |
| **Retry-Logik** | Stop Hook + Block Counter | Ralph Loop (explicit retry count) |
| **Rollback** | LLM fuehrt jq-Befehle aus | Shell-Script (deterministisch) |
| **Session Recovery** | Komplexer Recovery-Prompt | Trivial (State auf Disk) |
| **SKILL.md Groesse** | ~270 Zeilen Orchestrator-Logik | ~40 Zeilen ("Befolge Hooks") |
| **Fehlerklasse** | LLM vergisst Regeln | Shell hat keine Regeln zu vergessen |
| **Agents** | Identisch (10 spezialisierte) | Identisch (unveraendert) |
| **Hooks** | 6 (reagierend) | 4 (steuernd) |
| **Agent-Isolation** | File Reference Protocol | Vollstaendige Boomerang-Isolation |

---

## 10. Migrations-Strategie

### Phase 1: Shell-Orchestrator aufbauen (ohne bestehende Hooks zu brechen)

1. `wf_orchestrator.sh` als neuen Stop Hook schreiben
2. `wf_verify.sh` mit allen Done-Kriterien
3. `wf_prompt_builder.sh` mit allen Phase-Prompts
4. `phases.conf` als deklarative Konfiguration
5. Parallel zum bestehenden System testen

### Phase 2: SKILL.md vereinfachen

1. Orchestrator-Logik aus SKILL.md entfernen
2. SKILL.md auf "Transport-Layer"-Instruktionen reduzieren
3. Hooks umschalten (wf_engine.sh → wf_orchestrator.sh)

### Phase 3: Cleanup

1. `wf_engine.sh` entfernen (ersetzt durch `wf_orchestrator.sh`)
2. `session_recovery.sh` vereinfachen (nur noch "lies State, mach weiter")
3. `SubagentStart` Hook entfernen (nicht mehr noetig)
4. README und Dokumentation aktualisieren

### Phase 4: Validation

1. Vollstaendiger Workflow-Durchlauf mit neuem System
2. Edge Cases testen: Context Overflow, Rollbacks, Retries
3. Performance-Vergleich: Context-Verbrauch byt8 vs. bytA

---

## 11. Risiken und Mitigationen

| Risiko | Wahrscheinlichkeit | Mitigation |
|--------|-------------------|-----------|
| Stop Hook kann Claude nicht zuverlässig steuern | Niedrig (bewiesen in byt8 v7.0) | Bestehende decision:block Mechanik behalten |
| Agent-Prompts zu starr (Shell-Templates) | Mittel | Prompt-Templates koennen jq-Variablen nutzen |
| Rollback-Zielbestimmung zu simpel | Niedrig | User kann manuell Ziel angeben |
| Phase-Skip-Logik fehlt | Niedrig | phases.conf unterstuetzt "SKIP" Typ |
| Bestehende Agents muessen angepasst werden | NEIN | Agents bleiben 100% unveraendert |

---

## 12. Quellen

- [Boomerang Tasks — Roo Code Documentation](https://docs.roocode.com/features/boomerang-tasks)
- [Ralph Loop — Geoffrey Huntley](https://ghuntley.com/loop/)
- [Ralph Orchestrator — Research & Theory](https://mikeyobrien.github.io/ralph-orchestrator/research/)
- [From ReAct to Ralph Loop — Alibaba Cloud](https://www.alibabacloud.com/blog/from-react-to-ralph-loop-a-continuous-iteration-paradigm-for-ai-agents_602799)
- [AI Agent Orchestration Patterns — Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns)
- [Multi-Agent Loop Pattern — Google Cloud](https://docs.google.com/architecture/choose-design-pattern-agentic-ai-system)
- [Top AI Agentic Workflow Patterns — ByteByteGo](https://blog.bytebytego.com/p/top-ai-agentic-workflow-patterns)
- [Mastering Ralph Loops — LinearB Blog](https://linearb.io/blog/ralph-loop-agentic-engineering-geoffrey-huntley)
