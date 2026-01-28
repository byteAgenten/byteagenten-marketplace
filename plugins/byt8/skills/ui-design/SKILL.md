---
name: ui-design
description: UI Design Fachwissen für Wireframes. Enthält Greenfield-Fragen, Default-Tokens, UI-Patterns (Listen, Formulare, Navigation), Angular Material Snippets. Alle Templates haben data-testid für Playwright E2E-Tests.
---

# UI Design Skill

Fachwissen für den `ui-designer` Agent. Enthält Patterns, Fragen-Kataloge und Snippets für Wireframe-Erstellung.

**⚠️ ALLE Templates enthalten `data-testid` Attribute für Playwright E2E-Tests!**

## Wann diesen Skill laden?

- **Greenfield-Projekt** (keine Design Tokens vorhanden)
- **Neue UI-Komponente** ohne Referenz im Projekt
- **Pattern-Referenz** für Listen, Formulare, Dialoge

---

## 1. Greenfield Projekt-Fragen

### Einmalige Projekt-Fragen (bei Greenfield)

```markdown
Bevor ich das Wireframe erstelle, brauche ich ein paar Grundlagen:

1. **Branche/Kontext**: Was für eine Anwendung ist das?
   (z.B. Logistik, Healthcare, Finance, internes Tool)

2. **Zielgruppe**: Wer nutzt die Anwendung hauptsächlich?
   (z.B. Sachbearbeiter täglich 8h, Manager gelegentlich)

3. **Datendichte**: Wie datenintensiv?
   - [ ] Wenig Daten, viel Whitespace (Portal)
   - [ ] Mittlere Dichte (Standard Business App)
   - [ ] Hohe Dichte (Dashboard, Monitoring)

4. **Corporate Design vorhanden?**
   - Falls ja: Primärfarbe (Hex-Code)?
   - Falls nein: Welche Stimmung? (professionell/modern/freundlich)
```

---

## 2. Screen-spezifische Fragen

**Regel:** Nur fragen was NICHT aus Technical Spec ableitbar ist. Maximal 3-5 Fragen, immer mit Vorschlag + Begründung.

### Listen/Übersichten

| Wenn unklar... | Frage mit Vorschlag |
|----------------|---------------------|
| Layout | "Bei [X] Einträgen empfehle ich **Tabelle** (Sortierung, Vergleichbarkeit). Oder Karten?" |
| Spalten | "Wichtigste Spalten laut Tech Spec: [A, B, C]. Passt das?" |
| Zeilen-Aktionen | "Aktionen im **Overflow-Menü** (3 Punkte) – Standard bei >2 Aktionen. OK?" |
| Klick-Verhalten | "Zeilen-Klick → **Detail-Seite** (Standard). Oder Modal/Seitenleiste?" |
| Filter | "Filter für [Felder aus Tech Spec]? Oder reicht Textsuche?" |

### Formulare

| Wenn unklar... | Frage mit Vorschlag |
|----------------|---------------------|
| Layout | "Bei [X] Feldern: **[Empfehlung]**. Begründung: [...]" |
| Pflichtfelder | "Pflichtfelder? Mein Vorschlag: [aus Tech Spec]" |
| Validierung | "Live-Validierung (Standard) oder erst beim Speichern?" |

### Dialoge/Modals

| Wenn unklar... | Frage mit Vorschlag |
|----------------|---------------------|
| Größe | "Inhaltsmenge → **[Empfehlung]** Dialog" |
| Schließen | "Schließen bei Außen-Klick? (Standard: ja bei Info, nein bei Formular)" |

---

## 3. Default Design Tokens (Greenfield)

These CSS Custom Properties match the naming convention from `ui-theming` tokens.
Use these as defaults in wireframe HTML when no project tokens exist yet.

```css
:root {
  /* === COLORS (matches tokens/_colors.scss) === */
  --color-primary: #1976d2;
  --color-primary-light: #63a4ff;
  --color-primary-dark: #004ba0;
  --color-primary-contrast: #ffffff;

  --color-accent: #ff4081;
  --color-error: #f44336;
  --color-success: #4caf50;
  --color-warning: #ff9800;
  --color-info: #2196f3;

  /* Neutrals */
  --color-gray-50: #fafafa;
  --color-gray-100: #f5f5f5;
  --color-gray-200: #eeeeee;
  --color-gray-300: #e0e0e0;
  --color-gray-400: #bdbdbd;
  --color-gray-500: #9e9e9e;
  --color-gray-600: #757575;
  --color-gray-700: #616161;
  --color-gray-800: #424242;
  --color-gray-900: #212121;

  /* Surfaces */
  --color-background: #fafafa;
  --color-surface: #ffffff;
  --color-surface-variant: #f5f5f5;
  --color-text-primary: rgba(0, 0, 0, 0.87);
  --color-text-secondary: rgba(0, 0, 0, 0.6);
  --color-text-disabled: rgba(0, 0, 0, 0.38);
  --color-divider: rgba(0, 0, 0, 0.12);
  --color-border: rgba(0, 0, 0, 0.23);

  /* === TYPOGRAPHY (matches tokens/_typography.scss) === */
  --font-family-base: 'Roboto', -apple-system, BlinkMacSystemFont, sans-serif;
  --font-size-xs: 0.75rem;
  --font-size-sm: 0.875rem;
  --font-size-base: 1rem;
  --font-size-lg: 1.125rem;
  --font-size-xl: 1.25rem;
  --font-size-2xl: 1.5rem;
  --font-size-3xl: 1.875rem;
  --font-weight-regular: 400;
  --font-weight-medium: 500;
  --font-weight-bold: 700;
  --line-height-base: 1.5;

  /* === SPACING (matches tokens/_spacing.scss) === */
  --spacing-1: 0.25rem;
  --spacing-2: 0.5rem;
  --spacing-3: 0.75rem;
  --spacing-4: 1rem;
  --spacing-6: 1.5rem;
  --spacing-8: 2rem;
  --spacing-12: 3rem;

  /* Semantic Aliases */
  --spacing-card: var(--spacing-4);
  --spacing-inline: var(--spacing-2);
  --spacing-section: var(--spacing-8);

  /* === BORDER RADIUS === */
  --radius-sm: 0.125rem;
  --radius-md: 0.25rem;
  --radius-lg: 0.5rem;
  --radius-full: 9999px;

  /* === ELEVATION (matches tokens/_elevation.scss) === */
  --elevation-1: 0 2px 1px -1px rgba(0,0,0,.2), 0 1px 1px 0 rgba(0,0,0,.14), 0 1px 3px 0 rgba(0,0,0,.12);
  --elevation-2: 0 3px 1px -2px rgba(0,0,0,.2), 0 2px 2px 0 rgba(0,0,0,.14), 0 1px 5px 0 rgba(0,0,0,.12);
  --elevation-4: 0 2px 4px -1px rgba(0,0,0,.2), 0 4px 5px 0 rgba(0,0,0,.14), 0 1px 10px 0 rgba(0,0,0,.12);
  --elevation-8: 0 5px 5px -3px rgba(0,0,0,.2), 0 8px 10px 1px rgba(0,0,0,.14), 0 3px 14px 2px rgba(0,0,0,.12);

  /* Semantic Aliases */
  --shadow-card: var(--elevation-1);
  --shadow-dropdown: var(--elevation-4);

  /* === TRANSITIONS === */
  --transition-fast: 150ms ease-in-out;
  --transition-base: 250ms ease-in-out;

  /* === COMPONENT TOKENS === */
  --toolbar-height: 4rem;
  --sidenav-width: 16rem;
  --card-padding: var(--spacing-4);
  --card-radius: var(--radius-md);
  --button-radius: var(--radius-md);
  --input-radius: var(--radius-md);
}
```

---

## 4. Base Styles für Wireframes

```css
/* Reset + Base */
* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: var(--font-family-base);
  font-size: var(--font-size-sm);
  color: var(--color-text-primary);
  background: var(--color-background);
  line-height: var(--line-height-base);
}

/* Layout Utilities */
.flex { display: flex; }
.flex-col { flex-direction: column; }
.items-center { align-items: center; }
.justify-between { justify-content: space-between; }
.justify-end { justify-content: flex-end; }
.gap-2 { gap: var(--spacing-2); }
.gap-4 { gap: var(--spacing-4); }

.grid { display: grid; gap: var(--spacing-4); }
.grid-2 { grid-template-columns: repeat(2, 1fr); }
.grid-3 { grid-template-columns: repeat(3, 1fr); }
.grid-4 { grid-template-columns: repeat(4, 1fr); }

/* Spacing Utilities */
.p-2 { padding: var(--spacing-2); }
.p-4 { padding: var(--spacing-4); }
.p-6 { padding: var(--spacing-6); }
.mb-2 { margin-bottom: var(--spacing-2); }
.mb-4 { margin-bottom: var(--spacing-4); }
.mb-6 { margin-bottom: var(--spacing-6); }

/* Text Utilities */
.text-secondary { color: var(--color-text-secondary); }
.text-sm { font-size: var(--font-size-xs); }
.font-medium { font-weight: var(--font-weight-medium); }

/* Responsive */
@media (max-width: 960px) {
  .grid-2, .grid-3, .grid-4 { grid-template-columns: 1fr; }
}
```

---

## 5. Pattern-Referenzen

Detaillierte UI-Patterns mit data-testid in separaten Dateien:

| Pattern | Datei | Inhalt |
|---------|-------|--------|
| Listen | `references/patterns-list.md` | Tabellen, Karten, Master-Detail |
| Formulare | `references/patterns-form.md` | Layouts, Validierung, Wizard |
| Navigation | `references/patterns-navigation.md` | Dialoge, Tabs, Toasts, Leer-Zustände |

**Alle Pattern-Dateien enthalten:**
- Vollständige HTML-Templates mit `data-testid`
- CSS für Styling
- Playwright Test-Beispiele
- Checklisten für data-testid Naming

---

## 6. Checkliste vor Wireframe-Abschluss

- [ ] Technical Spec gelesen
- [ ] Modus erkannt (Standard/Greenfield)
- [ ] Bei Greenfield: Design System initialisiert
- [ ] Screen-Typ aus Tech Spec abgeleitet
- [ ] Nur notwendige Fragen gestellt (max 3-5)
- [ ] Wireframe in `wireframes/issue-{N}-{name}.html` gespeichert
- [ ] Context Store für angular-frontend-developer
- [ ] Approval Gate mit korrektem Output
