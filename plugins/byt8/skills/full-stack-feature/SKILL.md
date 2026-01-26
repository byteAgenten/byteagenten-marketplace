---
name: full-stack-feature
description: Orchestrates full-stack feature development with hook-based automation.
version: 5.0.0
author: byteagent - Hans Pickelmann
---

# Full-Stack Feature Development Skill

**When to use:** GitHub Issues, new features, bugfixes spanning multiple layers (DB → Backend → Frontend).

---

## ⚠️ WICHTIG: Ralph Wiggum Pattern

> **EINE Phase pro Aufruf!**
>
> Der Stop-Hook kontrolliert den Workflow. Nach JEDER Phase:
> 1. Claude beendet seine Antwort
> 2. Stop-Hook feuert und validiert
> 3. Hook gibt Anweisungen für nächsten Schritt
> 4. User gibt Approval (oder Feedback)
> 5. Nächster Aufruf macht nächste Phase

**Claude darf NICHT mehrere Phasen hintereinander ausführen!**

---

## Ablauf bei Aufruf

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Lies .workflow/workflow-state.json                          │
│  2. Prüfe status und currentPhase                               │
│  3. Führe GENAU EINE Phase aus (den passenden Agent aufrufen)   │
│  4. STOPP - Antwort beenden                                     │
│  5. Stop-Hook übernimmt (Validierung, State-Update, Output)     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Startup (nur bei neuem Workflow)

### 1. Check Project
```bash
cat CLAUDE.md 2>/dev/null | head -10 || echo "NOT FOUND"
```
If no CLAUDE.md → Ask user: "No CLAUDE.md found. Should I run /init?"

### 2. Workflow Directory + .gitignore
```bash
mkdir -p .workflow
grep -q "^\.workflow/" .gitignore 2>/dev/null || echo ".workflow/" >> .gitignore
```
⚠️ `.workflow/` must NEVER be committed!

### 3. Check Workflow State
```bash
cat .workflow/workflow-state.json 2>/dev/null || echo "NEW"
```

| Status | Action |
|--------|--------|
| `"active"` | Führe `currentPhase` aus |
| `"paused"` | Zeige Pause-Grund, warte auf User |
| `"awaiting_approval"` | Prüfe User-Input (siehe Approval-Handling) |
| Not found | Starte neuen Workflow (siehe unten) |

### Approval-Handling (bei status = "awaiting_approval")

Wenn der User den Skill aufruft während `status = "awaiting_approval"`:

1. **Prüfe User-Input** (die Nachricht VOR dem Skill-Aufruf):
   - Enthält "Ja", "OK", "Approve", "Weiter", "Yes", "LGTM"? → **APPROVAL**
   - Enthält Feedback/Änderungswünsche? → **ITERATION**

2. **Bei APPROVAL:**
   ```bash
   # State updaten: status = active, currentPhase++
   jq '.status = "active" | .currentPhase = (.currentPhase + 1)' \
     .workflow/workflow-state.json > .workflow/workflow-state.json.tmp && \
     mv .workflow/workflow-state.json.tmp .workflow/workflow-state.json
   ```
   Dann: Führe die NEUE Phase aus.

3. **Bei ITERATION (Feedback):**
   ```bash
   # State updaten: status = active (Phase bleibt gleich)
   jq '.status = "active"' \
     .workflow/workflow-state.json > .workflow/workflow-state.json.tmp && \
     mv .workflow/workflow-state.json.tmp .workflow/workflow-state.json
   ```
   Dann: Führe die GLEICHE Phase nochmal aus mit dem Feedback.

### 4. Argument Handling (nur bei neuem Workflow)
```
/full-stack-feature                    → Prompt for feature
/full-stack-feature #42                → Load GitHub Issue
/full-stack-feature #42 --from=develop → Issue + Branch
/full-stack-feature "Description"      → Inline feature
```

### 5. Create Branch (nur bei neuem Workflow)
```bash
git fetch --prune
git branch -r | grep -v HEAD | sed 's/origin\///' | head -10
```
Let user choose → then:
```bash
git checkout <fromBranch> && git pull
git checkout -b feature/issue-{N}-{slug}
```

### 6. Ask Test Coverage (nur bei neuem Workflow)
```
"What test coverage level should be targeted?"
1. 50% (Basic)
2. 70% (Standard)
3. 85% (High)
4. 95% (Critical)
```

### 7. Initialize State (nur bei neuem Workflow)

Create `.workflow/workflow-state.json`:

```json
{
  "workflow": "full-stack-feature",
  "status": "active",
  "issue": { "number": 42, "title": "...", "url": "..." },
  "branch": "feature/issue-42-...",
  "fromBranch": "develop",
  "targetCoverage": 70,
  "currentPhase": 0,
  "startedAt": "[ISO-TIMESTAMP]",
  "phases": {},
  "context": {}
}
```

**Dann: Führe Phase 0 aus (siehe unten)**

---

## Phase Übersicht

| Phase | Agent | Approval Gate? |
|-------|-------|----------------|
| 0 | `byt8:architect-planner` | ⏸️ Ja |
| 1 | `byt8:ui-designer` | ⏸️ Ja |
| 2 | `byt8:api-architect` | Nein |
| 3 | `byt8:postgresql-architect` | Nein |
| 4 | `byt8:spring-boot-developer` | 🧪 Tests |
| 5 | `byt8:angular-frontend-developer` | 🧪 Tests |
| 6 | `byt8:test-engineer` + `byt8:security-auditor` | ⏸️ Ja |
| 7 | `byt8:code-reviewer` | ⏸️ Ja |
| 8 | Claude direkt (Push & PR) | ⏸️ Ja |

---

## Phase Ausführung

### Bei jedem Aufruf:

1. **Lies State:**
   ```bash
   cat .workflow/workflow-state.json
   ```

2. **Prüfe Status:**
   - `"active"` → Weiter zu Schritt 3
   - `"paused"` → Zeige Grund, STOPP
   - `"awaiting_approval"` → Zeige was approved werden soll, STOPP
   - `"completed"` → Workflow fertig, STOPP

3. **Führe EINE Phase aus:**

   Basierend auf `currentPhase`, rufe den entsprechenden Agent auf:

---

### Phase 0: Tech Spec
```
Agent: byt8:architect-planner
Task: Create Technical Specification for Issue #${issue.number}: ${issue.title}

Kontext: Issue-Beschreibung, vorhandene Codebase
Output: Speichere Ergebnis in context.technicalSpec
```
**Nach Agent-Aufruf: STOPP. Hook validiert.**

---

### Phase 1: Wireframes
```
Agent: byt8:ui-designer
Task: Create wireframes based on Tech Spec.

Kontext: context.technicalSpec
Output: wireframes/*.html, speichere Summary in context.wireframes
```
**Nach Agent-Aufruf: STOPP. Hook validiert.**

---

### Phase 2: API Design
```
Agent: byt8:api-architect
Task: Define REST API based on Tech Spec and Wireframes.

Kontext: context.technicalSpec, context.wireframes
Output: Speichere in context.apiDesign
```
**Nach Agent-Aufruf: STOPP. Hook validiert und advanced automatisch.**

---

### Phase 3: Migrations
```
Agent: byt8:postgresql-architect
Task: Create Flyway migrations based on Tech Spec.

Kontext: context.technicalSpec, context.apiDesign
Output: backend/src/main/resources/db/migration/V*.sql
```
**Nach Agent-Aufruf: STOPP. Hook validiert und advanced automatisch.**

---

### Phase 4: Backend
```
Agent: byt8:spring-boot-developer
Task: Implement backend based on Tech Spec, API Design, and Migrations.

Kontext: context.technicalSpec, context.apiDesign, Migrations
Output: Entity, Repository, Service, Controller + Unit Tests
```
**Nach Agent-Aufruf: STOPP. Hook führt `mvn test` aus.**

---

### Phase 5: Frontend
```
Agent: byt8:angular-frontend-developer
Task: Implement frontend based on Wireframes and API Design.

Kontext: context.wireframes, context.apiDesign
Output: Components, Services, Routing + Unit Tests
```
**Nach Agent-Aufruf: STOPP. Hook führt `npm test` aus.**

---

### Phase 6: E2E + Security
```
Agent: byt8:test-engineer
Task: Create Playwright E2E tests.

Dann:

Agent: byt8:security-auditor
Task: Perform security audit.

Output: E2E Tests, Security Report
```
**Nach Agent-Aufrufen: STOPP. Hook validiert.**

---

### Phase 7: Review
```
Agent: byt8:code-reviewer
Task: Code review all changes.

Output: Review mit APPROVED oder CHANGES_REQUESTED
```
**Nach Agent-Aufruf: STOPP. Hook prüft Review-Status.**

---

### Phase 8: Push & PR

Diese Phase führt Claude direkt aus (kein Agent):

1. Frage Ziel-Branch:
   ```
   "Which branch should the PR target? (Default: ${fromBranch})"
   ```

2. Zeige PR-Preview:
   - Title: `feat(#${issue.number}): ${issue.title}`
   - Body: Zusammenfassung aus allen context Keys

3. Frage Bestätigung:
   ```
   "Should I push and create PR? [Yes/No]"
   ```

4. Bei "Yes":
   ```bash
   git push -u origin ${branch}
   gh pr create --base ${intoBranch} --title "${title}" --body "${body}"
   ```

5. Setze `status: "completed"`

---

## Context Keys

Jeder Agent speichert sein Ergebnis in `context.<key>`:

| Phase | Key | Inhalt |
|-------|-----|--------|
| 0 | `technicalSpec` | Architektur, Entities, Risiken |
| 1 | `wireframes` | Datei-Pfade, Komponenten |
| 2 | `apiDesign` | Endpoints, DTOs, Error Codes |
| 3 | `migrations` | SQL-Dateien, Tabellen |
| 4 | `backendImpl` | Java-Klassen, Test-Coverage |
| 5 | `frontendImpl` | Komponenten, Services |
| 6 | `testResults` | E2E-Status, Security-Findings |
| 7 | `reviewFeedback` | Status (APPROVED/CHANGES_REQUESTED) |

**Format:** Agent gibt am Ende aus:
```
CONTEXT_UPDATE: <key>
{ ...summary JSON... }
```

---

## Escape Commands

| Command | Function |
|---------|----------|
| `/byt8:wf-status` | Zeige aktuellen Status |
| `/byt8:wf-pause` | Workflow pausieren |
| `/byt8:wf-resume` | Pausierten Workflow fortsetzen |
| `/byt8:wf-retry-reset` | Retry-Counter zurücksetzen |
| `/byt8:wf-skip` | Phase überspringen (Notfall) |

---

## Checkliste für Claude

**Bei JEDEM Aufruf:**

1. ✅ Lies `.workflow/workflow-state.json`
2. ✅ Prüfe `status` - bei "paused"/"awaiting_approval"/"completed" → STOPP
3. ✅ Lies `currentPhase`
4. ✅ Rufe den Agent für diese EINE Phase auf
5. ✅ **STOPP** - Beende deine Antwort
6. ✅ Stop-Hook übernimmt: Validierung, Commit, State-Update

**Claude macht NICHT:**
- ❌ Mehrere Phasen hintereinander ausführen
- ❌ State manuell updaten (Hook macht das)
- ❌ Commits erstellen (Hook macht das)
- ❌ Zur nächsten Phase wechseln (Hook macht das)
- ❌ Approval Gates prüfen (Hook macht das)

---

## Hook-Workflow (zur Info)

Nach jeder Phase feuert der Stop-Hook:

```
┌─────────────────────────────────────────────────────────────────┐
│  Stop-Hook (wf_engine.sh)                                       │
├─────────────────────────────────────────────────────────────────┤
│  1. Lies currentPhase                                           │
│  2. check_done() für diese Phase                                │
│  3. PASS?                                                       │
│     → Approval-Gate Phase? → status = "awaiting_approval"       │
│     → Sonst? → currentPhase++, status = "active"                │
│     → WIP-Commit erstellen                                      │
│  4. FAIL?                                                       │
│     → Test-Phase? → Retry-Counter++, Fehlermeldung              │
│     → Sonst? → Warnung ausgeben                                 │
│  5. Output: Klare Anweisung was als nächstes passiert           │
└─────────────────────────────────────────────────────────────────┘
```

Der User sieht den Hook-Output und weiß was zu tun ist.
