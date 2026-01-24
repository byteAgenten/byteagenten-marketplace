---
name: ux-review
description: UX Heuristics Review - Evaluiert Wireframes gegen Nielsen's 10 Usability-Heuristiken. Findet UX-Probleme BEVOR implementiert wird.
---

# UX Heuristics Review

Evaluiert Wireframes und UI-Designs gegen etablierte Usability-Prinzipien (Nielsen's 10 Heuristiken). Findet potenzielle UX-Probleme **bevor** sie implementiert werden.

## Wann verwenden?

- Nach Wireframe-Erstellung (Phase 1)
- Vor Implementation (Phase 5)
- Bei UI-Änderungen oder Redesigns

## Workflow

### Step 1: Wireframe laden

```
Read: wireframes/issue-{N}-{feature}.html
```

### Step 2: Gegen Heuristiken prüfen

Jede der 10 Heuristiken systematisch durchgehen:

---

## Nielsen's 10 Usability-Heuristiken

### 1. Sichtbarkeit des Systemstatus

**Prinzip:** Das System informiert den User immer darüber, was gerade passiert.

**Prüffragen:**
- [ ] Gibt es Loading-Indikatoren bei asynchronen Aktionen?
- [ ] Zeigt das System Erfolgs-/Fehlermeldungen nach Aktionen?
- [ ] Ist der aktuelle Zustand sichtbar (z.B. aktiver Tab, ausgewählte Zeile)?
- [ ] Gibt es Progress-Indikatoren bei mehrstufigen Prozessen?

**Typische Verstöße:**
- Button klicken → keine Reaktion sichtbar
- Formular absenden → unklar ob gespeichert
- Lange Ladezeit ohne Feedback

---

### 2. Übereinstimmung zwischen System und realer Welt

**Prinzip:** Das System spricht die Sprache des Users, nicht Entwickler-Jargon.

**Prüffragen:**
- [ ] Sind Labels und Begriffe für die Zielgruppe verständlich?
- [ ] Folgt die Reihenfolge der Felder einer logischen/natürlichen Ordnung?
- [ ] Werden bekannte Metaphern und Icons verwendet?
- [ ] Sind Datumsformate, Währungen etc. lokalisiert?

**Typische Verstöße:**
- Technische IDs statt lesbarer Namen
- "Entity erstellen" statt "Neuen Kunden anlegen"
- Amerikanisches Datumsformat in deutscher App

---

### 3. Benutzerkontrolle und Freiheit

**Prinzip:** User machen Fehler. Sie brauchen einen "Notausgang" ohne langen Dialog.

**Prüffragen:**
- [ ] Gibt es "Abbrechen" bei allen Dialogen/Formularen?
- [ ] Kann der User Aktionen rückgängig machen (Undo)?
- [ ] Kann er aus Wizards/Flows jederzeit aussteigen?
- [ ] Gibt es "Zurück"-Navigation wo sinnvoll?

**Typische Verstöße:**
- Modal ohne Schließen-Button
- Wizard ohne "Zurück" oder "Abbrechen"
- Löschen ohne Bestätigung oder Undo

---

### 4. Konsistenz und Standards

**Prinzip:** Gleiche Dinge sehen gleich aus und verhalten sich gleich.

**Prüffragen:**
- [ ] Sehen alle primären Buttons gleich aus?
- [ ] Ist die Navigation auf allen Seiten identisch?
- [ ] Werden Material Design Patterns korrekt verwendet?
- [ ] Sind Icons konsistent (nicht mal Papierkorb, mal X für Löschen)?

**Typische Verstöße:**
- Verschiedene Button-Styles für gleiche Aktionen
- Tabelle hier, Karten dort für gleiche Daten
- "Speichern" links auf einer Seite, rechts auf anderer

---

### 5. Fehlervermeidung

**Prinzip:** Besser als gute Fehlermeldungen: Fehler gar nicht erst zulassen.

**Prüffragen:**
- [ ] Sind destruktive Aktionen (Löschen) durch Bestätigung geschützt?
- [ ] Gibt es Inline-Validierung bei Formularen?
- [ ] Werden ungültige Eingaben verhindert (z.B. Date-Picker statt Freitext)?
- [ ] Sind Pflichtfelder klar markiert?

**Typische Verstöße:**
- Datumsfeld als Freitext (User tippt "morgen")
- Löschen mit einem Klick ohne Warnung
- Pflichtfeld-Fehler erst nach Submit sichtbar

---

### 6. Wiedererkennen statt Erinnern

**Prinzip:** Optionen sichtbar machen, nicht User zwingen sich zu erinnern.

**Prüffragen:**
- [ ] Sind alle verfügbaren Aktionen sichtbar (nicht in versteckten Menüs)?
- [ ] Gibt es Autovervollständigung bei Suchfeldern?
- [ ] Werden kürzlich verwendete Einträge angezeigt?
- [ ] Sind Formularfelder mit sinnvollen Defaults vorbelegt?

**Typische Verstöße:**
- Wichtige Aktionen nur über Rechtsklick erreichbar
- Leeres Suchfeld ohne Vorschläge
- User muss Kunden-ID auswendig wissen

---

### 7. Flexibilität und Effizienz

**Prinzip:** Shortcuts für Power-User, ohne Anfänger zu überfordern.

**Prüffragen:**
- [ ] Gibt es Keyboard-Shortcuts für häufige Aktionen?
- [ ] Können Listen gefiltert/sortiert werden?
- [ ] Gibt es Bulk-Aktionen für mehrere Einträge?
- [ ] Sind häufige Workflows optimiert (wenige Klicks)?

**Typische Verstöße:**
- 5 Klicks für häufigste Aktion
- Keine Möglichkeit mehrere Einträge gleichzeitig zu bearbeiten
- Kein Keyboard-Support in Formularen

---

### 8. Ästhetisches und minimalistisches Design

**Prinzip:** Kein visuelles Rauschen. Nur relevante Information zeigen.

**Prüffragen:**
- [ ] Ist der Fokus auf der Hauptaktion klar?
- [ ] Gibt es unnötige Elemente die entfernt werden könnten?
- [ ] Ist die visuelle Hierarchie klar (was ist wichtig)?
- [ ] Ist genug Whitespace vorhanden?

**Typische Verstöße:**
- 10 gleichwertige Buttons in einer Toolbar
- Informationsüberflutung auf Dashboard
- Kein visueller Unterschied zwischen Haupt- und Nebenaktionen

---

### 9. Hilfe beim Erkennen und Beheben von Fehlern

**Prinzip:** Fehlermeldungen in klarer Sprache, mit Lösungsvorschlag.

**Prüffragen:**
- [ ] Sind Fehlermeldungen verständlich (nicht "Error 500")?
- [ ] Zeigen sie WAS falsch ist und WIE man es behebt?
- [ ] Erscheinen Fehler direkt beim betroffenen Feld?
- [ ] Sind Fehler visuell klar erkennbar (rot, Icon)?

**Typische Verstöße:**
- "Ungültige Eingabe" ohne zu sagen was ungültig ist
- Fehler nur oben auf der Seite, nicht beim Feld
- Technische Fehlercodes statt Klartext

---

### 10. Hilfe und Dokumentation

**Prinzip:** Idealerweise selbsterklärend, aber Hilfe verfügbar wenn nötig.

**Prüffragen:**
- [ ] Gibt es Tooltips bei komplexen Feldern/Icons?
- [ ] Ist kontextsensitive Hilfe verfügbar?
- [ ] Gibt es eine Suche in der Hilfe?
- [ ] Sind Hilfe-Texte aufgabenorientiert (nicht Feature-orientiert)?

**Typische Verstöße:**
- Icon ohne Tooltip
- Hilfe nur als 50-Seiten-PDF
- Komplexes Feature ohne Erklärung

---

## Output-Format

```markdown
# UX Heuristics Review

**Wireframe:** wireframes/issue-{N}-{feature}.html
**Datum:** [Datum]

## Zusammenfassung

| Schweregrad | Anzahl |
|-------------|--------|
| 🔴 Kritisch | X |
| 🟠 Hoch     | X |
| 🟡 Mittel   | X |
| 🟢 Niedrig  | X |

## Befunde

### 🔴 Kritisch: [Heuristik-Name]

**Problem:** [Beschreibung]
**Ort:** [Element/Bereich im Wireframe]
**Empfehlung:** [Konkrete Lösung]

### 🟠 Hoch: [Heuristik-Name]

...

## Positiv

- [Was gut umgesetzt ist]
- [Welche Heuristiken erfüllt sind]

## Nächste Schritte

1. Kritische Befunde vor Implementation beheben
2. Hohe Befunde mit Product Owner priorisieren
3. Mittlere/Niedrige in Backlog aufnehmen
```

## Schweregrad-Skala

| Grad | Bedeutung | Aktion |
|------|-----------|--------|
| 🔴 Kritisch | User kann Aufgabe nicht abschließen | Muss vor Implementation gefixt werden |
| 🟠 Hoch | User wird stark behindert | Sollte vor Implementation gefixt werden |
| 🟡 Mittel | User ist irritiert, findet aber Weg | In Sprint einplanen |
| 🟢 Niedrig | Kosmetisch, Best Practice | Backlog |

## Integration im Workflow

Der Review passt zwischen **Phase 1** (Wireframe) und **Phase 2** (API Design):

```
Phase 1: UI Designer erstellt Wireframe
    ↓
/ux-review prüft gegen Heuristiken
    ↓
Befunde beheben (falls kritisch/hoch)
    ↓
Phase 2: API Architect beginnt
```
