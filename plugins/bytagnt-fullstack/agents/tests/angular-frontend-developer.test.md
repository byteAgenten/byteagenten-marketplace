# Angular Frontend Developer Agent - Test Suite

## Version History
| Version | Date | Status |
|---------|------|--------|
| v2.0.0 | 2025-12-30 | Baseline (vor Verbesserungen) |
| v3.0.0 | 2025-12-31 | + API Contract Verification |
| v3.1.0 | 2025-12-31 | + Reinforced Inline Template Constraint |

---

## Test Categories

### 1. Golden Path Scenarios (Erfolgreiche Standard-Fälle)

#### TC-1.1: Neue Komponente erstellen
```
Prompt: "Erstelle eine neue UserCard Komponente die einen User anzeigt"

Expected:
- [ ] Erstellt user-card.component.html ZUERST
- [ ] Erstellt user-card.component.scss
- [ ] Erstellt user-card.component.ts mit templateUrl + styleUrl
- [ ] Erstellt user-card.component.spec.ts
- [ ] Verwendet ChangeDetectionStrategy.OnPush
- [ ] Verwendet input() statt @Input()
- [ ] Verwendet inject() statt Constructor
```

#### TC-1.2: Service mit HTTP-Call erstellen
```
Prompt: "Erstelle einen UserService mit einer Methode zum Laden eines Users"

Expected:
- [ ] LIEST Backend-Controller zuerst
- [ ] HTTP-Methode stimmt mit Backend überein
- [ ] Interface stimmt mit Backend-DTO überein
- [ ] withCredentials: true verwendet
- [ ] Error Handling implementiert
```

#### TC-1.3: Bestehende Komponente erweitern
```
Prompt: "Füge der SettingsComponent eine neue Sektion für Notifications hinzu"

Expected:
- [ ] Liest bestehende Komponente zuerst
- [ ] Erweitert .html Datei (nicht inline)
- [ ] Erweitert .scss Datei (nicht inline)
- [ ] Behält OnPush bei
- [ ] Fügt Tests hinzu
```

---

### 2. Previously Failed Scenarios (Regressions-Tests)

#### TC-2.1: POST vs PUT Mismatch (Issue #142)
```
Prompt: "Implementiere einen Service-Call zum Ändern des Passworts"
Backend: PUT /api/users/me/password

Expected:
- [ ] Agent LIEST Backend-Controller
- [ ] Verwendet http.put() (nicht http.post())
- [ ] Interface passt zu PasswordChangeResponse { message, hasPassword }

FAIL Criteria:
- ❌ Verwendet POST statt PUT
- ❌ Interface hat falsches Feld (z.B. success statt hasPassword)
```

#### TC-2.2: Inline Template trotz Verbot
```
Prompt: "Erstelle eine einfache Badge-Komponente"

Expected:
- [ ] Erstellt .html Datei
- [ ] Erstellt .scss Datei
- [ ] Verwendet templateUrl + styleUrl

FAIL Criteria:
- ❌ template: `...` im Component Decorator
- ❌ styles: [`...`] im Component Decorator
```

#### TC-2.3: Interface Mismatch
```
Prompt: "Erstelle Model und Service für Feature X"
Backend-DTO: { fieldA: string, fieldB: number }

Expected:
- [ ] Interface hat exakt fieldA: string, fieldB: number

FAIL Criteria:
- ❌ Andere Feldnamen
- ❌ Andere Typen
- ❌ Zusätzliche nicht-existente Felder
```

---

### 3. Edge Cases

#### TC-3.1: Sehr kleine Komponente
```
Prompt: "Erstelle eine Komponente die nur einen Text anzeigt"

Expected:
- [ ] Trotzdem externe .html + .scss Dateien
- [ ] Keine Ausnahme für "kleine" Komponenten

FAIL Criteria:
- ❌ Inline weil "zu klein für separate Datei"
```

#### TC-3.2: Komponente ohne Styles
```
Prompt: "Erstelle eine Komponente ohne eigene Styles"

Expected:
- [ ] Leere .scss Datei trotzdem erstellen
- [ ] styleUrl trotzdem angeben

FAIL Criteria:
- ❌ styleUrl weglassen
- ❌ styles: [] verwenden
```

#### TC-3.3: Kein Backend vorhanden
```
Prompt: "Erstelle einen Service für Feature Y" (Backend existiert noch nicht)

Expected:
- [ ] Agent FRAGT nach Backend-Spezifikation
- [ ] Oder: Agent weist darauf hin, dass Backend fehlt
- [ ] Implementiert NICHT einfach nach Annahme

FAIL Criteria:
- ❌ Rät HTTP-Methode
- ❌ Erfindet Interface ohne Backend-Basis
```

---

### 4. Stress Tests (Komplexe Multi-Step Tasks)

#### TC-4.1: Vollständiges Feature mit mehreren Komponenten
```
Prompt: "Implementiere eine Projekt-Verwaltung mit Liste, Detail-Ansicht und Form"

Expected:
- [ ] Alle Komponenten mit externen Templates
- [ ] Alle Services mit Backend-Verifikation
- [ ] Alle Tests geschrieben
- [ ] File-Size Limits eingehalten (< 400 Zeilen)
```

#### TC-4.2: Refactoring einer großen Komponente
```
Prompt: "Die SettingsComponent ist zu groß, refactore sie in Sub-Komponenten"

Expected:
- [ ] Erstellt Sub-Komponenten mit externen Templates
- [ ] Extrahiert logische Einheiten
- [ ] Behält Funktionalität bei
```

---

## Evaluation Metrics

### Task-Level Metrics
| Metric | Beschreibung | Gewichtung |
|--------|--------------|------------|
| Inline Template Violation | template: oder styles: verwendet | CRITICAL (auto-fail) |
| HTTP Method Mismatch | Falsche Methode für Endpoint | HIGH |
| Interface Mismatch | Felder stimmen nicht mit Backend | HIGH |
| Missing Tests | Keine Tests geschrieben | MEDIUM |
| Missing OnPush | ChangeDetection nicht OnPush | LOW |
| Legacy Syntax | *ngIf, *ngFor verwendet | LOW |

### Quality Score Berechnung
```
Score = 100
- Inline Template: -100 (auto-fail, Score = 0)
- HTTP Method Mismatch: -30
- Interface Mismatch: -25
- Missing Tests: -20
- Missing OnPush: -10
- Legacy Syntax: -5

Pass Threshold: >= 70
Excellent: >= 90
```

---

## Baseline Metrics (v2.0.0)

### Codebase Scan (2025-12-31)

| Metric | Count | Percentage |
|--------|-------|------------|
| Total Komponenten | 21 | 100% |
| Mit Inline Templates | 10+ | **~48%** ❌ |
| Mit externen Templates | ~11 | ~52% |

### Komponenten mit Inline-Violations:
1. `login-error-not-registered.component.ts`
2. `login-error-pending.component.ts`
3. `oauth-callback.component.ts`
4. `login.component.ts`
5. `time-entry-form.component.ts`
6. `project-members.component.ts`
7. `projects.component.ts`
8. `user-dialog.component.ts`
9. `user-management.component.ts`
10. `dashboard.component.ts`

### Issue #142 Session Metrics:

| Metric | v2.0.0 Result | Notes |
|--------|---------------|-------|
| Inline Template Violations | **10+** | 48% der Codebase! |
| HTTP Method Mismatches | 1 | POST statt PUT für /password |
| Interface Mismatches | 1 | success vs hasPassword |
| Missing Tests | 0 | Tests wurden geschrieben |
| Missing OnPush | 0 | OnPush war vorhanden |
| Legacy Syntax | 0 | Moderne Syntax verwendet |
| **Quality Score** | **0** | Auto-fail durch Inline Violations |

### Root Cause Analysis:
Das Constraint wurde nicht durchgesetzt weil:
1. Es war zu weit unten im Dokument (Constraint #3)
2. Keine Self-Verification nach dem Schreiben
3. Keine klare Reihenfolge (HTML vor TS)
4. Keine "Failure Language"

---

## Success Criteria für v3.1.0

### Für NEUE Implementierungen (ab v3.1.0):

| Metric | Target | Measurement | Threshold |
|--------|--------|-------------|-----------|
| Inline Template Violations | **0** | grep check | ZERO TOLERANCE |
| HTTP Method Accuracy | **100%** | Backend comparison | >= 95% |
| Interface Accuracy | **100%** | DTO comparison | >= 95% |
| Test Coverage | **85%+** | npm test coverage | >= 80% |
| Quality Score | **>= 90** | Calculated | >= 70 |

### Für BESTEHENDE Violations (Legacy Cleanup):

| Metric | Current | Target (3 Monate) | Notes |
|--------|---------|-------------------|-------|
| Inline Violations | 10 | 0 | Schrittweise beheben |
| Violation Rate | 48% | 0% | Priorität: neue Features |

### Verification Commands:

```bash
# Nach JEDER Frontend-Phase:
cd frontend

# 1. Inline Check (MUSS leer sein für neue Dateien)
git diff --name-only HEAD~1 | grep "\.component\.ts$" | xargs grep -l "template:\s*\`\|styles:\s*\[" || echo "✅ Keine neuen Inline-Violations"

# 2. Full Codebase Check
grep -r "template:\s*\`\|styles:\s*\[" src/app --include="*.ts" | wc -l
# Sollte <= 10 sein (bestehende) und NICHT steigen!
```

### Agent Improvement Success:

| Kriterium | Beschreibung | Status |
|-----------|--------------|--------|
| Keine neuen Inline-Violations | Nächste 5 Features ohne Inline | ⏳ Pending |
| HTTP Method korrekt | Nächste 5 API-Calls ohne Mismatch | ⏳ Pending |
| Interface Match | Nächste 5 DTOs ohne Fehler | ⏳ Pending |
| Self-Verification | Agent führt grep-Check aus | ⏳ Pending |

---

## Test Execution Log

### Test Run: [DATE]
| Test Case | Result | Notes |
|-----------|--------|-------|
| TC-1.1 | | |
| TC-1.2 | | |
| TC-2.1 | | |
| TC-2.2 | | |
| ... | | |

---

## Continuous Improvement

Nach jedem Feature-Implementation:
1. Prüfe gegen Test Cases
2. Dokumentiere Violations
3. Update Agent wenn nötig
4. Track Quality Score über Zeit
