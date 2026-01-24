# Formular-Patterns

Angular Material Patterns für Formulare und Eingabemasken.
**Alle Elemente haben `data-testid` für Playwright E2E-Tests.**

---

## Naming Convention für data-testid

```
[komponente]-[feld/aktion]

Beispiele:
- form-create-user           → Formular-Container
- input-firstname            → Text-Input
- select-category            → Dropdown
- textarea-description       → Mehrzeiliges Feld
- checkbox-terms             → Checkbox
- radio-gender-male          → Radio Button
- btn-submit                 → Submit Button
- btn-cancel                 → Cancel Button
- error-email-required       → Fehlermeldung
- hint-password              → Feld-Hinweis
```

---

## Standard-Formular (≤6 Felder)

```html
<form [formGroup]="form" 
      (ngSubmit)="onSubmit()" 
      class="form-container"
      data-testid="form-create-user">
  
  <h2 class="form-title" data-testid="form-title">Benutzer erstellen</h2>
  
  <!-- Text Input -->
  <mat-form-field appearance="outline" class="full-width">
    <mat-label>Name *</mat-label>
    <input matInput 
           formControlName="name"
           data-testid="input-name">
    <mat-error *ngIf="form.get('name')?.hasError('required')" 
               data-testid="error-name-required">
      Pflichtfeld
    </mat-error>
    <mat-error *ngIf="form.get('name')?.hasError('minlength')" 
               data-testid="error-name-minlength">
      Mindestens 2 Zeichen
    </mat-error>
  </mat-form-field>
  
  <!-- Email Input -->
  <mat-form-field appearance="outline" class="full-width">
    <mat-label>E-Mail *</mat-label>
    <input matInput 
           type="email" 
           formControlName="email"
           data-testid="input-email">
    <mat-icon matSuffix>email</mat-icon>
    <mat-error *ngIf="form.get('email')?.hasError('required')" 
               data-testid="error-email-required">
      Pflichtfeld
    </mat-error>
    <mat-error *ngIf="form.get('email')?.hasError('email')" 
               data-testid="error-email-invalid">
      Ungültige E-Mail-Adresse
    </mat-error>
  </mat-form-field>
  
  <!-- Select -->
  <mat-form-field appearance="outline" class="full-width">
    <mat-label>Kategorie</mat-label>
    <mat-select formControlName="category" data-testid="select-category">
      <mat-option value="" data-testid="option-category-empty">Bitte wählen...</mat-option>
      <mat-option value="admin" data-testid="option-category-admin">Administrator</mat-option>
      <mat-option value="user" data-testid="option-category-user">Benutzer</mat-option>
      <mat-option value="guest" data-testid="option-category-guest">Gast</mat-option>
    </mat-select>
  </mat-form-field>
  
  <!-- Textarea -->
  <mat-form-field appearance="outline" class="full-width">
    <mat-label>Beschreibung</mat-label>
    <textarea matInput 
              formControlName="description" 
              rows="4"
              data-testid="textarea-description"></textarea>
    <mat-hint align="end" data-testid="hint-description-count">
      {{ form.get('description')?.value?.length || 0 }} / 500
    </mat-hint>
  </mat-form-field>
  
  <!-- Checkbox -->
  <mat-checkbox formControlName="active" data-testid="checkbox-active">
    Aktiv
  </mat-checkbox>
  
  <!-- Form Actions -->
  <div class="form-actions" data-testid="form-actions">
    <button mat-button 
            type="button" 
            (click)="onCancel()"
            data-testid="btn-cancel">
      Abbrechen
    </button>
    <button mat-raised-button 
            color="primary" 
            type="submit" 
            [disabled]="form.invalid || form.pristine"
            data-testid="btn-submit">
      Speichern
    </button>
  </div>
  
  <!-- Form-Level Error -->
  <div class="form-error-banner" 
       *ngIf="submitError"
       data-testid="error-form-submit">
    <mat-icon>error</mat-icon>
    <span>{{ submitError }}</span>
  </div>
</form>
```

### Standard-Formular-CSS

```css
.form-container {
  max-width: 600px;
  padding: var(--spacing-6);
}

.form-title {
  font-size: var(--font-size-xl);
  font-weight: 500;
  margin-bottom: var(--spacing-6);
}

.full-width {
  width: 100%;
  margin-bottom: var(--spacing-2);
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--spacing-2);
  margin-top: var(--spacing-6);
  padding-top: var(--spacing-4);
  border-top: 1px solid var(--color-divider);
}

.form-error-banner {
  display: flex;
  align-items: center;
  gap: var(--spacing-2);
  padding: var(--spacing-4);
  background: #ffebee;
  border-radius: var(--radius-md);
  color: var(--color-error);
  margin-top: var(--spacing-4);
}
```

---

## 2-Spalten-Formular (7-12 Felder)

```html
<form [formGroup]="form" 
      class="form-container form-container--wide"
      data-testid="form-create-contact">
  
  <h2 class="form-title" data-testid="form-title">Kontakt anlegen</h2>
  
  <div class="form-grid" data-testid="form-grid">
    <!-- Row 1 -->
    <mat-form-field appearance="outline">
      <mat-label>Vorname *</mat-label>
      <input matInput formControlName="firstName" data-testid="input-firstname">
      <mat-error data-testid="error-firstname-required">Pflichtfeld</mat-error>
    </mat-form-field>
    
    <mat-form-field appearance="outline">
      <mat-label>Nachname *</mat-label>
      <input matInput formControlName="lastName" data-testid="input-lastname">
      <mat-error data-testid="error-lastname-required">Pflichtfeld</mat-error>
    </mat-form-field>
    
    <!-- Row 2 -->
    <mat-form-field appearance="outline">
      <mat-label>E-Mail *</mat-label>
      <input matInput type="email" formControlName="email" data-testid="input-email">
      <mat-icon matSuffix>email</mat-icon>
    </mat-form-field>
    
    <mat-form-field appearance="outline">
      <mat-label>Telefon</mat-label>
      <input matInput formControlName="phone" data-testid="input-phone">
      <mat-icon matSuffix>phone</mat-icon>
    </mat-form-field>
    
    <!-- Full Width Row -->
    <mat-form-field appearance="outline" class="span-2">
      <mat-label>Adresse</mat-label>
      <input matInput formControlName="address" data-testid="input-address">
    </mat-form-field>
    
    <!-- Row 3 -->
    <mat-form-field appearance="outline">
      <mat-label>PLZ</mat-label>
      <input matInput formControlName="zip" data-testid="input-zip">
    </mat-form-field>
    
    <mat-form-field appearance="outline">
      <mat-label>Stadt</mat-label>
      <input matInput formControlName="city" data-testid="input-city">
    </mat-form-field>
    
    <!-- Country Select -->
    <mat-form-field appearance="outline">
      <mat-label>Land</mat-label>
      <mat-select formControlName="country" data-testid="select-country">
        <mat-option value="DE" data-testid="option-country-de">Deutschland</mat-option>
        <mat-option value="AT" data-testid="option-country-at">Österreich</mat-option>
        <mat-option value="CH" data-testid="option-country-ch">Schweiz</mat-option>
      </mat-select>
    </mat-form-field>
    
    <!-- Date Picker -->
    <mat-form-field appearance="outline">
      <mat-label>Geburtsdatum</mat-label>
      <input matInput [matDatepicker]="picker" formControlName="birthdate" data-testid="input-birthdate">
      <mat-datepicker-toggle matSuffix [for]="picker" data-testid="btn-datepicker-birthdate"></mat-datepicker-toggle>
      <mat-datepicker #picker></mat-datepicker>
    </mat-form-field>
  </div>
  
  <div class="form-actions" data-testid="form-actions">
    <button mat-button type="button" data-testid="btn-cancel">Abbrechen</button>
    <button mat-raised-button color="primary" data-testid="btn-submit">Speichern</button>
  </div>
</form>
```

### 2-Spalten-CSS

```css
.form-container--wide {
  max-width: 800px;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--spacing-4);
}

.span-2 {
  grid-column: span 2;
}

@media (max-width: 600px) {
  .form-grid {
    grid-template-columns: 1fr;
  }
  .span-2 {
    grid-column: span 1;
  }
}
```

---

## Gruppiertes Formular (>12 Felder)

```html
<form [formGroup]="form" 
      class="form-container form-container--wide"
      data-testid="form-create-customer">
  
  <h2 class="form-title" data-testid="form-title">Neuen Kunden anlegen</h2>
  
  <!-- Section 1: Stammdaten -->
  <section class="form-section" data-testid="section-basic">
    <h3 class="section-title">Stammdaten</h3>
    <div class="form-grid">
      <mat-form-field appearance="outline">
        <mat-label>Firmenname *</mat-label>
        <input matInput formControlName="company" data-testid="input-company">
      </mat-form-field>
      <mat-form-field appearance="outline">
        <mat-label>Kundennummer</mat-label>
        <input matInput formControlName="customerNo" readonly data-testid="input-customerno">
        <mat-hint>Wird automatisch vergeben</mat-hint>
      </mat-form-field>
    </div>
  </section>
  
  <!-- Section 2: Kontaktdaten -->
  <section class="form-section" data-testid="section-contact">
    <h3 class="section-title">Kontaktdaten</h3>
    <div class="form-grid">
      <mat-form-field appearance="outline">
        <mat-label>Ansprechpartner</mat-label>
        <input matInput formControlName="contactPerson" data-testid="input-contactperson">
      </mat-form-field>
      <mat-form-field appearance="outline">
        <mat-label>E-Mail</mat-label>
        <input matInput formControlName="email" data-testid="input-email">
      </mat-form-field>
      <mat-form-field appearance="outline">
        <mat-label>Telefon</mat-label>
        <input matInput formControlName="phone" data-testid="input-phone">
      </mat-form-field>
      <mat-form-field appearance="outline">
        <mat-label>Fax</mat-label>
        <input matInput formControlName="fax" data-testid="input-fax">
      </mat-form-field>
    </div>
  </section>
  
  <!-- Section 3: Optional (collapsed) -->
  <mat-expansion-panel class="form-section-expandable" data-testid="section-advanced">
    <mat-expansion-panel-header data-testid="section-advanced-header">
      <mat-panel-title>Erweiterte Einstellungen</mat-panel-title>
      <mat-panel-description>Optional</mat-panel-description>
    </mat-expansion-panel-header>
    <div class="form-grid">
      <mat-form-field appearance="outline">
        <mat-label>USt-IdNr.</mat-label>
        <input matInput formControlName="vatId" data-testid="input-vatid">
      </mat-form-field>
      <mat-form-field appearance="outline">
        <mat-label>Zahlungsziel (Tage)</mat-label>
        <input matInput type="number" formControlName="paymentTerms" data-testid="input-paymentterms">
      </mat-form-field>
    </div>
  </mat-expansion-panel>
  
  <div class="form-actions" data-testid="form-actions">
    <button mat-button type="button" data-testid="btn-cancel">Abbrechen</button>
    <button mat-raised-button color="primary" data-testid="btn-submit">Speichern</button>
  </div>
</form>
```

---

## Wizard/Stepper

```html
<mat-stepper [linear]="true" #stepper class="wizard-container" data-testid="stepper-registration">
  
  <!-- Step 1 -->
  <mat-step [stepControl]="step1Form" label="Grunddaten" data-testid="step-basic">
    <form [formGroup]="step1Form" data-testid="form-step-basic">
      <div class="step-content">
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Name *</mat-label>
          <input matInput formControlName="name" cdkFocusInitial data-testid="input-name">
        </mat-form-field>
        
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>E-Mail *</mat-label>
          <input matInput formControlName="email" data-testid="input-email">
        </mat-form-field>
      </div>
      
      <div class="step-actions">
        <span></span>
        <button mat-raised-button 
                color="primary" 
                matStepperNext
                data-testid="btn-step-next">
          Weiter <mat-icon>arrow_forward</mat-icon>
        </button>
      </div>
    </form>
  </mat-step>
  
  <!-- Step 2 -->
  <mat-step [stepControl]="step2Form" label="Details" data-testid="step-details">
    <form [formGroup]="step2Form" data-testid="form-step-details">
      <div class="step-content">
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Firma</mat-label>
          <input matInput formControlName="company" data-testid="input-company">
        </mat-form-field>
        
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Position</mat-label>
          <input matInput formControlName="position" data-testid="input-position">
        </mat-form-field>
      </div>
      
      <div class="step-actions">
        <button mat-button matStepperPrevious data-testid="btn-step-prev">
          <mat-icon>arrow_back</mat-icon> Zurück
        </button>
        <button mat-raised-button color="primary" matStepperNext data-testid="btn-step-next">
          Weiter <mat-icon>arrow_forward</mat-icon>
        </button>
      </div>
    </form>
  </mat-step>
  
  <!-- Step 3: Confirmation -->
  <mat-step label="Bestätigung" data-testid="step-confirmation">
    <div class="step-content">
      <mat-card class="summary-card" data-testid="card-summary">
        <mat-card-header>
          <mat-card-title>Zusammenfassung</mat-card-title>
        </mat-card-header>
        <mat-card-content>
          <dl class="summary-list" data-testid="summary-list">
            <dt>Name</dt>
            <dd data-testid="summary-name">{{ step1Form.get('name')?.value }}</dd>
            <dt>E-Mail</dt>
            <dd data-testid="summary-email">{{ step1Form.get('email')?.value }}</dd>
            <dt>Firma</dt>
            <dd data-testid="summary-company">{{ step2Form.get('company')?.value }}</dd>
          </dl>
        </mat-card-content>
      </mat-card>
      
      <mat-checkbox formControlName="terms" data-testid="checkbox-terms">
        Ich akzeptiere die AGB *
      </mat-checkbox>
    </div>
    
    <div class="step-actions">
      <button mat-button matStepperPrevious data-testid="btn-step-prev">
        <mat-icon>arrow_back</mat-icon> Zurück
      </button>
      <button mat-raised-button 
              color="primary" 
              (click)="onSubmit()"
              [disabled]="!termsAccepted"
              data-testid="btn-submit">
        <mat-icon>check</mat-icon> Absenden
      </button>
    </div>
  </mat-step>
</mat-stepper>
```

---

## Spezial-Felder

### Autocomplete

```html
<mat-form-field appearance="outline" class="full-width">
  <mat-label>Kunde</mat-label>
  <input matInput 
         [matAutocomplete]="auto" 
         formControlName="customer"
         data-testid="input-customer-autocomplete">
  <mat-autocomplete #auto="matAutocomplete" 
                    [displayWith]="displayFn"
                    data-testid="autocomplete-customer">
    <mat-option *ngFor="let option of filteredOptions | async" 
                [value]="option"
                [attr.data-testid]="'option-customer-' + option.id">
      <span>{{ option.name }}</span>
      <small class="text-secondary"> - {{ option.city }}</small>
    </mat-option>
  </mat-autocomplete>
  <mat-icon matSuffix>search</mat-icon>
</mat-form-field>
```

### Datei-Upload

```html
<div class="file-upload-container" data-testid="upload-container">
  <input type="file" 
         #fileInput 
         hidden 
         (change)="onFileSelected($event)" 
         multiple
         data-testid="input-file-hidden">
  
  <div class="file-dropzone" 
       (click)="fileInput.click()"
       (dragover)="onDragOver($event)"
       (drop)="onDrop($event)"
       data-testid="dropzone-file">
    <mat-icon>cloud_upload</mat-icon>
    <p>Dateien hierher ziehen oder <a>auswählen</a></p>
    <small class="text-secondary">Max. 10 MB, PDF/JPG/PNG</small>
  </div>
  
  <mat-list *ngIf="files.length > 0" class="file-list" data-testid="list-files">
    <mat-list-item *ngFor="let file of files; let i = index"
                   [attr.data-testid]="'file-item-' + i">
      <mat-icon matListItemIcon>insert_drive_file</mat-icon>
      <span matListItemTitle data-testid="file-name">{{ file.name }}</span>
      <span matListItemLine class="text-secondary" data-testid="file-size">
        {{ file.size | fileSize }}
      </span>
      <button mat-icon-button 
              matListItemMeta 
              (click)="removeFile(file)"
              [attr.data-testid]="'btn-remove-file-' + i">
        <mat-icon>close</mat-icon>
      </button>
    </mat-list-item>
  </mat-list>
</div>
```

---

## Playwright Test-Beispiele

```typescript
// Beispiel: Formular ausfüllen
test('should create user', async ({ page }) => {
  await page.goto('/users/new');
  
  // Formular ausfüllen
  await page.getByTestId('input-name').fill('Max Mustermann');
  await page.getByTestId('input-email').fill('max@example.com');
  await page.getByTestId('select-category').click();
  await page.getByTestId('option-category-admin').click();
  await page.getByTestId('checkbox-active').check();
  
  // Absenden
  await page.getByTestId('btn-submit').click();
  
  // Erfolg prüfen
  await expect(page.getByTestId('error-form-submit')).not.toBeVisible();
});

// Beispiel: Validierung testen
test('should show validation errors', async ({ page }) => {
  await page.goto('/users/new');
  
  // Leeres Formular absenden
  await page.getByTestId('btn-submit').click();
  
  // Fehler sichtbar
  await expect(page.getByTestId('error-name-required')).toBeVisible();
  await expect(page.getByTestId('error-email-required')).toBeVisible();
});

// Beispiel: Wizard durchlaufen
test('should complete registration wizard', async ({ page }) => {
  await page.goto('/register');
  
  // Step 1
  await page.getByTestId('input-name').fill('Max');
  await page.getByTestId('input-email').fill('max@test.de');
  await page.getByTestId('btn-step-next').click();
  
  // Step 2
  await expect(page.getByTestId('step-details')).toBeVisible();
  await page.getByTestId('input-company').fill('Acme GmbH');
  await page.getByTestId('btn-step-next').click();
  
  // Step 3: Bestätigung
  await expect(page.getByTestId('summary-name')).toContainText('Max');
  await page.getByTestId('checkbox-terms').check();
  await page.getByTestId('btn-submit').click();
});
```

---

## data-testid Checkliste für Formulare

| Element | data-testid Pattern | Beispiel |
|---------|---------------------|----------|
| Form | `form-{action}-{entity}` | `form-create-user` |
| Input | `input-{fieldname}` | `input-email` |
| Select | `select-{fieldname}` | `select-category` |
| Option | `option-{field}-{value}` | `option-category-admin` |
| Textarea | `textarea-{fieldname}` | `textarea-description` |
| Checkbox | `checkbox-{fieldname}` | `checkbox-active` |
| Radio | `radio-{field}-{value}` | `radio-gender-male` |
| Datepicker | `input-{field}` + `btn-datepicker-{field}` | `input-birthdate` |
| Error | `error-{field}-{type}` | `error-email-required` |
| Hint | `hint-{field}` | `hint-password` |
| Submit | `btn-submit` | `btn-submit` |
| Cancel | `btn-cancel` | `btn-cancel` |
| Section | `section-{name}` | `section-contact` |
| Step | `step-{name}` | `step-basic` |
