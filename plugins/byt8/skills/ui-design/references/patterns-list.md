# Listen-Patterns

Angular Material Patterns für Übersichten und Listen.
**Alle Elemente haben `data-testid` für Playwright E2E-Tests.**

---

## Naming Convention für data-testid

```
[komponente]-[kontext]-[element]

Beispiele:
- table-users                    → Haupttabelle
- table-users-row-{id}          → Tabellenzeile
- table-users-cell-status-{id}  → Zelle in Zeile
- btn-create-user               → Button
- input-search-users            → Suchfeld
- menu-row-actions-{id}         → Zeilen-Menü
- chip-filter-status            → Filter-Chip
```

---

## Tabelle (Standard für >20 Einträge)

```html
<div class="table-container mat-elevation-z1" data-testid="table-container-users">
  <!-- Toolbar -->
  <div class="table-toolbar" data-testid="toolbar-users">
    <mat-form-field appearance="outline" class="search-field">
      <mat-label>Suchen</mat-label>
      <input matInput 
             placeholder="Suchen..." 
             data-testid="input-search-users">
      <mat-icon matSuffix>search</mat-icon>
    </mat-form-field>
    
    <span class="spacer"></span>
    
    <button mat-button 
            [matMenuTriggerFor]="filterMenu"
            data-testid="btn-filter-users">
      <mat-icon>filter_list</mat-icon> Filter
    </button>
    
    <mat-menu #filterMenu="matMenu" data-testid="menu-filter-users">
      <button mat-menu-item data-testid="filter-status-active">Aktiv</button>
      <button mat-menu-item data-testid="filter-status-inactive">Inaktiv</button>
    </mat-menu>
    
    <button mat-raised-button 
            color="primary"
            data-testid="btn-create-user">
      <mat-icon>add</mat-icon> Neu
    </button>
  </div>

  <!-- Table -->
  <mat-table [dataSource]="dataSource" matSort data-testid="table-users">
    <!-- Checkbox Column -->
    <ng-container matColumnDef="select">
      <mat-header-cell *matHeaderCellDef>
        <mat-checkbox data-testid="checkbox-select-all"></mat-checkbox>
      </mat-header-cell>
      <mat-cell *matCellDef="let row">
        <mat-checkbox [attr.data-testid]="'checkbox-select-' + row.id"></mat-checkbox>
      </mat-cell>
    </ng-container>
    
    <!-- Status Column -->
    <ng-container matColumnDef="status">
      <mat-header-cell *matHeaderCellDef mat-sort-header data-testid="header-status">
        Status
      </mat-header-cell>
      <mat-cell *matCellDef="let row" [attr.data-testid]="'cell-status-' + row.id">
        <span class="status-badge status--active" 
              [attr.data-testid]="'badge-status-' + row.id">
          {{ row.status }}
        </span>
      </mat-cell>
    </ng-container>
    
    <!-- Name Column -->
    <ng-container matColumnDef="name">
      <mat-header-cell *matHeaderCellDef mat-sort-header data-testid="header-name">
        Name
      </mat-header-cell>
      <mat-cell *matCellDef="let row" [attr.data-testid]="'cell-name-' + row.id">
        {{ row.name }}
      </mat-cell>
    </ng-container>
    
    <!-- Email Column -->
    <ng-container matColumnDef="email">
      <mat-header-cell *matHeaderCellDef mat-sort-header data-testid="header-email">
        E-Mail
      </mat-header-cell>
      <mat-cell *matCellDef="let row" [attr.data-testid]="'cell-email-' + row.id">
        {{ row.email }}
      </mat-cell>
    </ng-container>
    
    <!-- Actions Column -->
    <ng-container matColumnDef="actions">
      <mat-header-cell *matHeaderCellDef></mat-header-cell>
      <mat-cell *matCellDef="let row">
        <button mat-icon-button 
                [matMenuTriggerFor]="rowMenu"
                [attr.data-testid]="'btn-actions-' + row.id">
          <mat-icon>more_vert</mat-icon>
        </button>
        <mat-menu #rowMenu="matMenu">
          <button mat-menu-item [attr.data-testid]="'action-edit-' + row.id">
            <mat-icon>edit</mat-icon> Bearbeiten
          </button>
          <button mat-menu-item [attr.data-testid]="'action-delete-' + row.id">
            <mat-icon>delete</mat-icon> Löschen
          </button>
        </mat-menu>
      </mat-cell>
    </ng-container>
    
    <mat-header-row *matHeaderRowDef="displayedColumns" data-testid="table-header"></mat-header-row>
    <mat-row *matRowDef="let row; columns: displayedColumns" 
             (click)="onRowClick(row)"
             [attr.data-testid]="'row-' + row.id"
             class="clickable-row"></mat-row>
  </mat-table>
  
  <!-- Empty State -->
  <div *ngIf="dataSource.data.length === 0" 
       class="empty-state"
       data-testid="empty-state-users">
    <mat-icon>inbox</mat-icon>
    <p>Keine Einträge gefunden</p>
  </div>
  
  <!-- Paginator -->
  <mat-paginator [pageSizeOptions]="[10, 25, 50]" 
                 showFirstLastButtons
                 data-testid="paginator-users"></mat-paginator>
</div>
```

### Tabellen-CSS

```css
.table-container {
  background: var(--color-surface);
  border-radius: var(--radius-sm);
}

.table-toolbar {
  display: flex;
  align-items: center;
  gap: var(--spacing-4);
  padding: var(--spacing-4);
  border-bottom: 1px solid var(--color-divider);
}

.search-field { width: 300px; }
.spacer { flex: 1; }

.clickable-row { cursor: pointer; }
.clickable-row:hover { background: rgba(0, 0, 0, 0.04); }

.status-badge {
  padding: var(--spacing-1) var(--spacing-2);
  border-radius: var(--radius-full);
  font-size: var(--font-size-xs);
  font-weight: 500;
}

.status--active { background: #e8f5e9; color: #2e7d32; }
.status--inactive { background: #fafafa; color: #757575; }
.status--pending { background: #fff3e0; color: #e65100; }
.status--error { background: #ffebee; color: #c62828; }
```

---

## Karten-Grid (≤20 Einträge, visuell)

```html
<div class="cards-container" data-testid="cards-container-projects">
  <!-- Toolbar -->
  <div class="cards-toolbar" data-testid="toolbar-projects">
    <mat-form-field appearance="outline">
      <input matInput 
             placeholder="Suchen..." 
             data-testid="input-search-projects">
      <mat-icon matSuffix>search</mat-icon>
    </mat-form-field>
    
    <span class="spacer"></span>
    
    <mat-button-toggle-group value="grid" data-testid="toggle-view-mode">
      <mat-button-toggle value="grid" data-testid="toggle-view-grid">
        <mat-icon>grid_view</mat-icon>
      </mat-button-toggle>
      <mat-button-toggle value="list" data-testid="toggle-view-list">
        <mat-icon>view_list</mat-icon>
      </mat-button-toggle>
    </mat-button-toggle-group>
    
    <button mat-raised-button 
            color="primary"
            data-testid="btn-create-project">
      <mat-icon>add</mat-icon> Neu
    </button>
  </div>

  <!-- Grid -->
  <div class="cards-grid" data-testid="grid-projects">
    <mat-card *ngFor="let item of items" 
              (click)="onCardClick(item)" 
              [attr.data-testid]="'card-project-' + item.id"
              class="clickable-card">
      <mat-card-header>
        <mat-card-title [attr.data-testid]="'card-title-' + item.id">
          {{ item.title }}
        </mat-card-title>
        <mat-card-subtitle [attr.data-testid]="'card-subtitle-' + item.id">
          {{ item.subtitle }}
        </mat-card-subtitle>
        <span class="status-badge" [attr.data-testid]="'card-status-' + item.id">
          {{ item.status }}
        </span>
      </mat-card-header>
      
      <mat-card-content>
        <p class="text-secondary" [attr.data-testid]="'card-description-' + item.id">
          {{ item.description }}
        </p>
      </mat-card-content>
      
      <mat-card-actions align="end">
        <button mat-icon-button [attr.data-testid]="'btn-edit-project-' + item.id">
          <mat-icon>edit</mat-icon>
        </button>
        <button mat-icon-button 
                color="warn"
                [attr.data-testid]="'btn-delete-project-' + item.id">
          <mat-icon>delete</mat-icon>
        </button>
      </mat-card-actions>
    </mat-card>
  </div>
  
  <!-- Empty State -->
  <div *ngIf="items.length === 0" 
       class="empty-state"
       data-testid="empty-state-projects">
    <mat-icon>folder_open</mat-icon>
    <p>Keine Projekte vorhanden</p>
    <button mat-raised-button color="primary" data-testid="btn-create-first-project">
      Erstes Projekt erstellen
    </button>
  </div>
</div>
```

---

## Master-Detail (häufiges Wechseln)

```html
<mat-sidenav-container class="master-detail-container" data-testid="master-detail-container">
  <!-- Master (Liste) -->
  <mat-sidenav mode="side" 
               opened 
               class="master-panel"
               data-testid="panel-master">
    <mat-form-field appearance="outline" class="full-width p-md">
      <input matInput 
             placeholder="Suchen..."
             data-testid="input-search-master">
      <mat-icon matSuffix>search</mat-icon>
    </mat-form-field>
    
    <mat-selection-list [multiple]="false" data-testid="list-master">
      <mat-list-option *ngFor="let item of items" 
                       [selected]="item === selectedItem"
                       (click)="select(item)"
                       [attr.data-testid]="'list-item-' + item.id">
        <span matListItemTitle>{{ item.title }}</span>
        <span matListItemLine class="text-secondary">{{ item.subtitle }}</span>
      </mat-list-option>
    </mat-selection-list>
  </mat-sidenav>
  
  <!-- Detail -->
  <mat-sidenav-content class="detail-panel" data-testid="panel-detail">
    <ng-container *ngIf="selectedItem; else emptyState">
      <!-- Detail Header -->
      <div class="detail-header" data-testid="detail-header">
        <h2 data-testid="detail-title">{{ selectedItem.title }}</h2>
        <div class="detail-actions">
          <button mat-button data-testid="btn-edit-detail">
            <mat-icon>edit</mat-icon> Bearbeiten
          </button>
          <button mat-button color="warn" data-testid="btn-delete-detail">
            <mat-icon>delete</mat-icon> Löschen
          </button>
        </div>
      </div>
      
      <!-- Detail Content -->
      <div class="detail-content" data-testid="detail-content">
        <!-- Content here -->
      </div>
    </ng-container>
    
    <ng-template #emptyState>
      <div class="empty-state" data-testid="empty-state-detail">
        <mat-icon>inbox</mat-icon>
        <p>Eintrag auswählen</p>
      </div>
    </ng-template>
  </mat-sidenav-content>
</mat-sidenav-container>
```

---

## Filter-Panel

```html
<mat-expansion-panel class="filter-panel" data-testid="panel-filter">
  <mat-expansion-panel-header data-testid="panel-filter-header">
    <mat-panel-title>
      <mat-icon>filter_list</mat-icon> Filter
      <mat-chip *ngIf="activeFilters > 0" data-testid="chip-filter-count">
        {{ activeFilters }}
      </mat-chip>
    </mat-panel-title>
  </mat-expansion-panel-header>
  
  <div class="filter-grid" data-testid="filter-grid">
    <mat-form-field appearance="outline">
      <mat-label>Status</mat-label>
      <mat-select multiple data-testid="select-filter-status">
        <mat-option value="active" data-testid="option-status-active">Aktiv</mat-option>
        <mat-option value="inactive" data-testid="option-status-inactive">Inaktiv</mat-option>
        <mat-option value="pending" data-testid="option-status-pending">Ausstehend</mat-option>
      </mat-select>
    </mat-form-field>
    
    <mat-form-field appearance="outline">
      <mat-label>Zeitraum</mat-label>
      <mat-date-range-input [rangePicker]="picker" data-testid="input-filter-daterange">
        <input matStartDate placeholder="Von" data-testid="input-date-from">
        <input matEndDate placeholder="Bis" data-testid="input-date-to">
      </mat-date-range-input>
      <mat-datepicker-toggle matSuffix [for]="picker"></mat-datepicker-toggle>
      <mat-date-range-picker #picker></mat-date-range-picker>
    </mat-form-field>
  </div>
  
  <div class="filter-actions">
    <button mat-button (click)="resetFilters()" data-testid="btn-filter-reset">
      Zurücksetzen
    </button>
    <button mat-raised-button 
            color="primary" 
            (click)="applyFilters()"
            data-testid="btn-filter-apply">
      Anwenden
    </button>
  </div>
</mat-expansion-panel>
```

---

## Playwright Test-Beispiele

```typescript
// Beispiel: Tabelle testen
test('should display users table', async ({ page }) => {
  await page.goto('/users');
  
  // Tabelle sichtbar
  await expect(page.getByTestId('table-users')).toBeVisible();
  
  // Suche
  await page.getByTestId('input-search-users').fill('Max');
  await expect(page.getByTestId('row-1')).toContainText('Max');
  
  // Zeilen-Aktion
  await page.getByTestId('btn-actions-1').click();
  await page.getByTestId('action-edit-1').click();
  
  // Neuer Eintrag
  await page.getByTestId('btn-create-user').click();
});

// Beispiel: Filter testen
test('should filter by status', async ({ page }) => {
  await page.getByTestId('btn-filter-users').click();
  await page.getByTestId('filter-status-active').click();
  
  // Nur aktive sichtbar
  const rows = page.locator('[data-testid^="row-"]');
  for (const row of await rows.all()) {
    await expect(row.getByTestId(/badge-status-/)).toContainText('Aktiv');
  }
});
```

---

## Entscheidungsbaum

```
Erwartete Einträge?
│
├─ >500 → Tabelle + Server-Side Pagination + Virtual Scroll
│
├─ 50-500 → Tabelle + Client Pagination
│
├─ 20-50 → Tabelle (ohne Pagination) oder Karten
│
└─ <20
    ├─ Sortierung wichtig? → Tabelle
    ├─ Visuell/Bilder? → Karten-Grid
    └─ Häufiges Wechseln? → Master-Detail
```

---

## data-testid Checkliste

| Element | data-testid Pattern | Beispiel |
|---------|---------------------|----------|
| Container | `{type}-container-{entity}` | `table-container-users` |
| Tabelle | `table-{entity}` | `table-users` |
| Zeile | `row-{id}` | `row-123` |
| Zelle | `cell-{column}-{id}` | `cell-status-123` |
| Button | `btn-{action}-{entity}` | `btn-create-user` |
| Input | `input-{purpose}-{entity}` | `input-search-users` |
| Select | `select-{field}` | `select-filter-status` |
| Menu | `menu-{context}` | `menu-row-actions` |
| Empty State | `empty-state-{entity}` | `empty-state-users` |
