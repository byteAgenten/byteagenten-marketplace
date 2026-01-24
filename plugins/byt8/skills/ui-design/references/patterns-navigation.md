# Navigation & Dialog-Patterns

Angular Material Patterns für Dialoge, Navigation und Feedback.
**Alle Elemente haben `data-testid` für Playwright E2E-Tests.**

---

## Naming Convention für data-testid

```
[komponente]-[kontext]-[element]

Beispiele:
- dialog-confirm-delete        → Dialog Container
- dialog-title                 → Dialog Titel
- btn-dialog-confirm           → Bestätigen Button
- btn-dialog-cancel            → Abbrechen Button
- tab-overview                 → Tab
- snackbar-success             → Toast/Snackbar
- breadcrumb-home              → Breadcrumb Link
- sidenav-detail               → Seitenleiste
```

---

## Dialoge/Modals

### Standard-Dialog (Formular)

```html
<!-- dialog-edit.component.html -->
<div class="dialog-container" data-testid="dialog-edit-user">
  <h2 mat-dialog-title data-testid="dialog-title">Benutzer bearbeiten</h2>
  
  <mat-dialog-content data-testid="dialog-content">
    <form [formGroup]="form" data-testid="dialog-form">
      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Name</mat-label>
        <input matInput formControlName="name" cdkFocusInitial data-testid="input-name">
        <mat-error data-testid="error-name-required">Pflichtfeld</mat-error>
      </mat-form-field>
      
      <mat-form-field appearance="outline" class="full-width">
        <mat-label>E-Mail</mat-label>
        <input matInput formControlName="email" data-testid="input-email">
      </mat-form-field>
      
      <mat-form-field appearance="outline" class="full-width">
        <mat-label>Beschreibung</mat-label>
        <textarea matInput formControlName="description" rows="3" data-testid="textarea-description"></textarea>
      </mat-form-field>
    </form>
  </mat-dialog-content>
  
  <mat-dialog-actions align="end" data-testid="dialog-actions">
    <button mat-button mat-dialog-close data-testid="btn-dialog-cancel">
      Abbrechen
    </button>
    <button mat-raised-button 
            color="primary" 
            [disabled]="form.invalid"
            (click)="onSave()"
            data-testid="btn-dialog-save">
      Speichern
    </button>
  </mat-dialog-actions>
</div>
```

### Bestätigungs-Dialog (Destruktive Aktion)

```html
<div class="confirm-dialog" data-testid="dialog-confirm-delete">
  <div class="confirm-icon warn" data-testid="dialog-icon">
    <mat-icon>warning</mat-icon>
  </div>
  
  <h2 mat-dialog-title data-testid="dialog-title">Löschen bestätigen</h2>
  
  <mat-dialog-content data-testid="dialog-content">
    <p data-testid="dialog-message">
      Möchten Sie <strong data-testid="dialog-item-name">{{ data.name }}</strong> wirklich löschen?
    </p>
    <p class="text-secondary" data-testid="dialog-warning">
      Diese Aktion kann nicht rückgängig gemacht werden.
    </p>
  </mat-dialog-content>
  
  <mat-dialog-actions align="center" data-testid="dialog-actions">
    <button mat-button mat-dialog-close data-testid="btn-dialog-cancel">
      Abbrechen
    </button>
    <button mat-raised-button 
            color="warn" 
            [mat-dialog-close]="true"
            data-testid="btn-dialog-confirm">
      <mat-icon>delete</mat-icon> Löschen
    </button>
  </mat-dialog-actions>
</div>
```

### Info-Dialog

```html
<div class="info-dialog" data-testid="dialog-info">
  <div class="info-icon" data-testid="dialog-icon">
    <mat-icon>info</mat-icon>
  </div>
  
  <h2 mat-dialog-title data-testid="dialog-title">Information</h2>
  
  <mat-dialog-content data-testid="dialog-content">
    <p data-testid="dialog-message">{{ data.message }}</p>
  </mat-dialog-content>
  
  <mat-dialog-actions align="center" data-testid="dialog-actions">
    <button mat-raised-button 
            color="primary" 
            mat-dialog-close
            data-testid="btn-dialog-ok">
      Verstanden
    </button>
  </mat-dialog-actions>
</div>
```

### Dialog-CSS

```css
.confirm-dialog,
.info-dialog {
  text-align: center;
  padding: var(--spacing-4);
}

.confirm-icon,
.info-icon {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto var(--spacing-4);
}

.confirm-icon.warn { background: #fff3e0; color: #e65100; }
.confirm-icon.error { background: #ffebee; color: #c62828; }
.info-icon { background: #e3f2fd; color: #1565c0; }

.confirm-icon mat-icon,
.info-icon mat-icon {
  font-size: 32px;
  width: 32px;
  height: 32px;
}
```

### Dialog-Größen (TypeScript)

```typescript
// Klein (Bestätigung) - 400px
this.dialog.open(ConfirmDialogComponent, {
  width: '400px',
  data: { name: item.name },
  panelClass: 'dialog-small'
});

// Mittel (Formular) - 600px
this.dialog.open(EditDialogComponent, {
  width: '600px',
  maxHeight: '90vh',
  data: { item },
  panelClass: 'dialog-medium'
});

// Groß (Komplexe Ansicht) - 900px
this.dialog.open(DetailDialogComponent, {
  width: '900px',
  maxWidth: '95vw',
  maxHeight: '90vh',
  data: { item },
  panelClass: 'dialog-large'
});
```

---

## Slide-Over Panel (Seitenleiste)

```html
<mat-sidenav-container data-testid="sidenav-container">
  <mat-sidenav #detailPanel 
               position="end" 
               mode="over" 
               class="detail-sidenav"
               data-testid="sidenav-detail">
    <!-- Header -->
    <div class="sidenav-header" data-testid="sidenav-header">
      <h3 data-testid="sidenav-title">Details bearbeiten</h3>
      <button mat-icon-button 
              (click)="detailPanel.close()"
              data-testid="btn-sidenav-close">
        <mat-icon>close</mat-icon>
      </button>
    </div>
    
    <!-- Content -->
    <div class="sidenav-content" data-testid="sidenav-content">
      <form [formGroup]="form" data-testid="sidenav-form">
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Name</mat-label>
          <input matInput formControlName="name" data-testid="input-name">
        </mat-form-field>
        
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Beschreibung</mat-label>
          <textarea matInput formControlName="description" rows="4" data-testid="textarea-description"></textarea>
        </mat-form-field>
      </form>
    </div>
    
    <!-- Footer -->
    <div class="sidenav-footer" data-testid="sidenav-footer">
      <button mat-button 
              (click)="detailPanel.close()"
              data-testid="btn-sidenav-cancel">
        Abbrechen
      </button>
      <button mat-raised-button 
              color="primary" 
              (click)="onSave()"
              data-testid="btn-sidenav-save">
        Speichern
      </button>
    </div>
  </mat-sidenav>
  
  <mat-sidenav-content data-testid="main-content">
    <!-- Hauptinhalt -->
    <button mat-button 
            (click)="detailPanel.open()"
            data-testid="btn-open-sidenav">
      Details öffnen
    </button>
  </mat-sidenav-content>
</mat-sidenav-container>
```

---

## Tabs

### Standard-Tabs

```html
<mat-tab-group data-testid="tabs-detail">
  <mat-tab label="Übersicht" data-testid="tab-overview">
    <div class="tab-content" data-testid="tab-content-overview">
      <!-- Content -->
    </div>
  </mat-tab>
  
  <mat-tab label="Details" data-testid="tab-details">
    <div class="tab-content" data-testid="tab-content-details">
      <!-- Content -->
    </div>
  </mat-tab>
  
  <mat-tab label="Historie" data-testid="tab-history">
    <ng-template matTabContent>
      <div class="tab-content" data-testid="tab-content-history">
        <!-- Lazy loaded content -->
      </div>
    </ng-template>
  </mat-tab>
</mat-tab-group>
```

### Navigations-Tabs (URL-basiert)

```html
<nav mat-tab-nav-bar data-testid="nav-tabs">
  <a mat-tab-link 
     *ngFor="let link of navLinks"
     [routerLink]="link.path"
     routerLinkActive #rla="routerLinkActive"
     [active]="rla.isActive"
     [attr.data-testid]="'nav-tab-' + link.id">
    <mat-icon *ngIf="link.icon">{{ link.icon }}</mat-icon>
    {{ link.label }}
  </a>
</nav>
<router-outlet></router-outlet>
```

### Filter-Tabs (Toggle)

```html
<mat-button-toggle-group [value]="selectedFilter" 
                         (change)="onFilterChange($event)"
                         data-testid="filter-toggle-status">
  <mat-button-toggle value="all" data-testid="filter-all">
    Alle <mat-chip data-testid="count-all">{{ counts.all }}</mat-chip>
  </mat-button-toggle>
  <mat-button-toggle value="open" data-testid="filter-open">
    Offen <mat-chip data-testid="count-open">{{ counts.open }}</mat-chip>
  </mat-button-toggle>
  <mat-button-toggle value="done" data-testid="filter-done">
    Erledigt <mat-chip data-testid="count-done">{{ counts.done }}</mat-chip>
  </mat-button-toggle>
</mat-button-toggle-group>
```

---

## Snackbar/Toast

```typescript
// Success Toast
this.snackBar.open('Erfolgreich gespeichert', 'OK', {
  duration: 3000,
  horizontalPosition: 'end',
  verticalPosition: 'top',
  panelClass: ['snackbar-success']
});

// Error Toast
this.snackBar.open('Fehler beim Speichern', 'Erneut versuchen', {
  duration: 5000,
  horizontalPosition: 'center',
  verticalPosition: 'bottom',
  panelClass: ['snackbar-error']
});

// Mit Undo-Aktion
const snackBarRef = this.snackBar.open('3 Einträge gelöscht', 'Rückgängig', {
  duration: 5000,
  panelClass: ['snackbar-info']
});

snackBarRef.onAction().subscribe(() => {
  this.undoDelete();
});
```

### Snackbar-CSS (styles.scss)

```css
/* data-testid wird via panelClass gesetzt */
.snackbar-success {
  --mdc-snackbar-container-color: #4caf50;
  --mdc-snackbar-supporting-text-color: white;
}

.snackbar-error {
  --mdc-snackbar-container-color: #f44336;
  --mdc-snackbar-supporting-text-color: white;
}

.snackbar-warning {
  --mdc-snackbar-container-color: #ff9800;
  --mdc-snackbar-supporting-text-color: white;
}

.snackbar-info {
  --mdc-snackbar-container-color: #2196f3;
  --mdc-snackbar-supporting-text-color: white;
}
```

### Snackbar in Playwright testen

```typescript
// Snackbar erscheint
await expect(page.locator('.mat-mdc-snack-bar-container')).toBeVisible();
await expect(page.locator('.mat-mdc-snack-bar-label')).toContainText('Erfolgreich');

// Snackbar Action klicken
await page.locator('.mat-mdc-snack-bar-action button').click();
```

---

## Leer-Zustände (Empty States)

```html
<!-- Keine Daten -->
<div class="empty-state" data-testid="empty-state-no-data">
  <mat-icon data-testid="empty-state-icon">inbox</mat-icon>
  <h3 data-testid="empty-state-title">Keine Einträge vorhanden</h3>
  <p class="text-secondary" data-testid="empty-state-message">
    Erstellen Sie Ihren ersten Eintrag, um loszulegen.
  </p>
  <button mat-raised-button 
          color="primary"
          data-testid="btn-empty-state-action">
    <mat-icon>add</mat-icon> Neu erstellen
  </button>
</div>

<!-- Keine Suchergebnisse -->
<div class="empty-state" data-testid="empty-state-no-results">
  <mat-icon data-testid="empty-state-icon">search_off</mat-icon>
  <h3 data-testid="empty-state-title">Keine Treffer</h3>
  <p class="text-secondary" data-testid="empty-state-message">
    Versuchen Sie andere Suchbegriffe oder Filter.
  </p>
  <button mat-button 
          (click)="resetFilters()"
          data-testid="btn-reset-filters">
    Filter zurücksetzen
  </button>
</div>

<!-- Fehler -->
<div class="empty-state error" data-testid="empty-state-error">
  <mat-icon data-testid="empty-state-icon">error_outline</mat-icon>
  <h3 data-testid="empty-state-title">Fehler beim Laden</h3>
  <p class="text-secondary" data-testid="empty-state-message">
    Die Daten konnten nicht geladen werden.
  </p>
  <button mat-raised-button 
          color="primary" 
          (click)="reload()"
          data-testid="btn-retry">
    <mat-icon>refresh</mat-icon> Erneut versuchen
  </button>
</div>
```

---

## Lade-Zustände

### Spinner Overlay

```html
<div class="loading-overlay" *ngIf="loading" data-testid="loading-overlay">
  <mat-spinner diameter="48" data-testid="loading-spinner"></mat-spinner>
  <p *ngIf="loadingMessage" data-testid="loading-message">{{ loadingMessage }}</p>
</div>
```

### Progress Bar

```html
<mat-progress-bar *ngIf="loading" 
                  mode="indeterminate" 
                  class="top-progress"
                  data-testid="progress-bar"></mat-progress-bar>
```

### Skeleton Loading

```html
<div class="skeleton-list" *ngIf="loading" data-testid="skeleton-list">
  <div class="skeleton-item" 
       *ngFor="let i of [1,2,3,4,5]"
       [attr.data-testid]="'skeleton-item-' + i">
    <div class="skeleton-avatar" data-testid="skeleton-avatar"></div>
    <div class="skeleton-text">
      <div class="skeleton-line skeleton-line--title" data-testid="skeleton-title"></div>
      <div class="skeleton-line skeleton-line--subtitle" data-testid="skeleton-subtitle"></div>
    </div>
  </div>
</div>
```

---

## Breadcrumbs

```html
<nav class="breadcrumbs" aria-label="Breadcrumb" data-testid="breadcrumbs">
  <a routerLink="/dashboard" data-testid="breadcrumb-home">
    <mat-icon>home</mat-icon>
  </a>
  <mat-icon class="separator">chevron_right</mat-icon>
  
  <a routerLink="/customers" data-testid="breadcrumb-customers">Kunden</a>
  <mat-icon class="separator">chevron_right</mat-icon>
  
  <a routerLink="/customers/123" data-testid="breadcrumb-customer-detail">Acme GmbH</a>
  <mat-icon class="separator">chevron_right</mat-icon>
  
  <span class="current" data-testid="breadcrumb-current">Bearbeiten</span>
</nav>
```

---

## Playwright Test-Beispiele

```typescript
// Dialog testen
test('should confirm delete dialog', async ({ page }) => {
  await page.getByTestId('btn-delete-user-1').click();
  
  // Dialog erscheint
  await expect(page.getByTestId('dialog-confirm-delete')).toBeVisible();
  await expect(page.getByTestId('dialog-item-name')).toContainText('Max Mustermann');
  
  // Bestätigen
  await page.getByTestId('btn-dialog-confirm').click();
  
  // Dialog geschlossen
  await expect(page.getByTestId('dialog-confirm-delete')).not.toBeVisible();
});

// Dialog abbrechen
test('should cancel delete dialog', async ({ page }) => {
  await page.getByTestId('btn-delete-user-1').click();
  await page.getByTestId('btn-dialog-cancel').click();
  
  // User noch vorhanden
  await expect(page.getByTestId('row-1')).toBeVisible();
});

// Tabs navigieren
test('should switch tabs', async ({ page }) => {
  await page.goto('/users/1');
  
  // Übersicht ist aktiv
  await expect(page.getByTestId('tab-content-overview')).toBeVisible();
  
  // Zu Details wechseln
  await page.getByTestId('tab-details').click();
  await expect(page.getByTestId('tab-content-details')).toBeVisible();
  await expect(page.getByTestId('tab-content-overview')).not.toBeVisible();
});

// Sidenav öffnen/schließen
test('should open and close sidenav', async ({ page }) => {
  await page.getByTestId('btn-open-sidenav').click();
  await expect(page.getByTestId('sidenav-detail')).toBeVisible();
  
  // Schließen
  await page.getByTestId('btn-sidenav-close').click();
  await expect(page.getByTestId('sidenav-detail')).not.toBeVisible();
});

// Empty State testen
test('should show empty state', async ({ page }) => {
  // Mit Filter der keine Ergebnisse hat
  await page.getByTestId('input-search-users').fill('xyznonexistent');
  
  await expect(page.getByTestId('empty-state-no-results')).toBeVisible();
  await expect(page.getByTestId('empty-state-title')).toContainText('Keine Treffer');
  
  // Reset
  await page.getByTestId('btn-reset-filters').click();
  await expect(page.getByTestId('table-users')).toBeVisible();
});

// Loading State testen
test('should show loading state', async ({ page }) => {
  // Slow network simulieren
  await page.route('**/api/users', async route => {
    await new Promise(r => setTimeout(r, 1000));
    await route.continue();
  });
  
  await page.goto('/users');
  await expect(page.getByTestId('loading-overlay')).toBeVisible();
  await expect(page.getByTestId('loading-spinner')).toBeVisible();
  
  // Nach Laden verschwindet
  await expect(page.getByTestId('loading-overlay')).not.toBeVisible({ timeout: 5000 });
});
```

---

## data-testid Checkliste für Navigation/Dialoge

| Element | data-testid Pattern | Beispiel |
|---------|---------------------|----------|
| Dialog Container | `dialog-{type}-{entity}` | `dialog-confirm-delete` |
| Dialog Title | `dialog-title` | `dialog-title` |
| Dialog Content | `dialog-content` | `dialog-content` |
| Dialog Actions | `dialog-actions` | `dialog-actions` |
| Dialog Confirm | `btn-dialog-confirm` | `btn-dialog-confirm` |
| Dialog Cancel | `btn-dialog-cancel` | `btn-dialog-cancel` |
| Sidenav | `sidenav-{name}` | `sidenav-detail` |
| Tab Group | `tabs-{context}` | `tabs-detail` |
| Tab | `tab-{name}` | `tab-overview` |
| Tab Content | `tab-content-{name}` | `tab-content-overview` |
| Breadcrumb | `breadcrumb-{name}` | `breadcrumb-home` |
| Empty State | `empty-state-{type}` | `empty-state-no-data` |
| Loading | `loading-overlay` | `loading-overlay` |
| Skeleton | `skeleton-{type}` | `skeleton-list` |
