---
name: prd-generator
description: "Generate a Product Requirements Document (PRD) for a new feature. Use when planning a feature, starting a new project, or when asked to create a PRD. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."
---

# PRD Generator

Create detailed Product Requirements Documents that are clear, actionable, and suitable for implementation.

---

## The Job

0. Analyze relevant parts of the codebase using 3 parallel researchers
1. Receive a feature description from the user
2. Ask 3-5 clarifying questions (informed by codebase findings)
3. Generate a structured PRD based on answers + findings
4. Save to `.workflow/prds/prd-[feature-name].md`
5. Present the PRD to the user for approval
6. On approval → Create a GitHub Issue with the PRD content

**Important:** Do NOT start implementing. Just create the PRD and (optionally) the GitHub Issue.

---

## Step 0: Codebase Analysis

Before asking clarifying questions, analyze the existing codebase to ground the PRD in reality. Launch **three parallel Explore subagents**, each focused on one architectural layer. Pass each agent the user's feature description as context.

### Data Layer Researcher

Discover how data is stored and structured in this project.
Find and report:
- Database schema, migrations, or ORM model definitions relevant to the feature
- Existing tables/collections/entities that the feature might extend or reference
- Naming conventions and patterns (e.g., how IDs, timestamps, soft-deletes are handled)
- Test data or seed files that would need updating

### Backend / API Researcher

Discover how business logic and APIs are structured in this project.
Find and report:
- Existing API endpoints (routes, controllers, handlers) related to the feature
- Service layer / business logic that could be extended or reused
- Authentication/authorization patterns in use (guards, middleware, decorators)
- Relevant DTOs, validation rules, or error handling patterns

### Frontend / UI Researcher

Discover how the user interface is structured in this project.
Find and report:
- Existing pages, components, or views related to the feature
- Routing structure and navigation patterns
- UI component library or design system in use (e.g., Material, Bootstrap, custom)
- State management approach and data fetching patterns
- Reusable components or patterns that the new feature should follow

### Using the Findings

- Collect findings from all three researchers before proceeding to Step 1
- If a researcher finds no relevant code (e.g., greenfield feature), note this — the PRD will be less specific for that layer, which is fine
- Use findings to:
  1. Ask **better clarifying questions** in Step 1 (reference actual code)
  2. Write **precise user stories** in Step 2 (reference actual files, classes, endpoints)
  3. Populate **Technical Considerations** with real architecture context

---

## Step 1: Clarifying Questions

Ask only critical questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Success Criteria:** How do we know it's done?

### Format Questions Like This:

```
1. What is the primary goal of this feature?
   A. Improve user onboarding experience
   B. Increase user retention
   C. Reduce support burden
   D. Other: [please specify]

2. Who is the target user?
   A. New users only
   B. Existing users only
   C. All users
   D. Admin users only

3. What is the scope?
   A. Minimal viable version
   B. Full-featured implementation
   C. Just the backend/API
   D. Just the UI
```

This lets users respond with "1A, 2C, 3B" for quick iteration.

**Codebase-informed questions:** Where the codebase analysis (Step 0) revealed relevant existing code, reference it in your questions. For example:
- Instead of "Where should we store the data?" → "I found an existing `users` table/model. Should the new feature extend this or use a separate entity?"
- Instead of "What UI pattern?" → "The project uses a list+detail pattern (e.g., in the orders module). Should this feature follow the same pattern?"

---

## Step 2: PRD Structure

Generate the PRD with these sections:

### 1. Introduction/Overview
Brief description of the feature and the problem it solves.

### 2. Goals
Specific, measurable objectives (bullet list).

### 3. User Stories
Each story needs:
- **Title:** Short descriptive name
- **Description:** "As a [user], I want [feature] so that [benefit]"
- **Acceptance Criteria:** Verifiable checklist of what "done" means

Each story should be small enough to implement in one focused session.

**Format:**
```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Another criterion
- [ ] Typecheck/lint passes
- [ ] **[UI stories only]** Manual visual verification by user (open in browser, check layout/interactions)
```

**Important:**
- Acceptance criteria must be verifiable, not vague. "Works correctly" is bad. "Button shows confirmation dialog before deleting" is good.
- **For any story with UI changes:** Always include "Manual visual verification by user" as acceptance criteria. This ensures the user checks the UI in the browser before the story is considered done.

**Codebase references:** When existing code was found by the researchers (Step 0), user stories should reference specific files, classes, endpoints, or tables. This helps implementers know exactly where to make changes.
- Good: "Extend the `OrderService` with a `cancelOrder()` method"
- Bad: "Implement order cancellation logic"
- Good: "Add column `cancelled_at` to the `orders` table"
- Bad: "Store cancellation data"
- If no existing code was found (greenfield), write stories without code references.

### 4. Functional Requirements
Numbered list of specific functionalities:
- "FR-1: The system must allow users to..."
- "FR-2: When a user clicks X, the system must..."

Be explicit and unambiguous.

### 5. Non-Goals (Out of Scope)
What this feature will NOT include. Critical for managing scope.

### 6. Design Considerations (Optional)
- UI/UX requirements
- Link to mockups if available
- Relevant existing components to reuse

### 7. Technical Considerations
Populate this section with findings from Step 0. Include:
- Existing relevant data structures (tables, models, schemas)
- Existing relevant API endpoints or services
- Reusable UI components or patterns
- Identified tech stack and conventions
- Known constraints or dependencies
- Integration points with existing systems
- Performance requirements

If Step 0 found no relevant code, note "Greenfield — no existing related code found."

### 8. Success Metrics
How will success be measured?
- "Reduce time to complete X by 50%"
- "Increase conversion rate by 10%"

### 9. Open Questions
Remaining questions or areas needing clarification.

---

## Writing for Junior Developers

The PRD reader may be a junior developer or AI agent. Therefore:

- Be explicit and unambiguous
- Avoid jargon or explain it
- Provide enough detail to understand purpose and core logic
- Number requirements for easy reference
- Use concrete examples where helpful

---

## Step 3: User Approval & GitHub Issue

After saving the PRD file, present it to the user and ask:

```
PRD gespeichert unter .workflow/prds/prd-[feature-name].md

Soll ich ein GitHub Issue mit dieser PRD erstellen?
```

### On Approval: Create GitHub Issue

Use `gh issue create` to create the issue. The PRD content becomes the issue body.

**Rules:**
- **Title:** `feat: [Feature Name]` (derived from the PRD title, without "PRD:" prefix)
- **Body:** The complete PRD markdown content (read from the saved file)
- **Label:** `feature` (create if it doesn't exist)
- **No assignee** — the user assigns manually

**Command pattern:**
```bash
gh label create "feature" --description "New feature" --color "0E8A16" --force
gh issue create --title "feat: [Feature Name]" --label "feature" --body-file ".workflow/prds/prd-[feature-name].md"
```

**Important:**
- Always use `--body-file` to pass the PRD content (avoids shell escaping issues with large markdown)
- Show the created issue URL to the user after creation
- If the user declines, skip issue creation — the PRD file is still saved

---

## Output

- **Format:** Markdown (`.md`)
- **Location:** `.workflow/prds/`
- **Filename:** `prd-[feature-name].md` (kebab-case)
- **GitHub Issue:** Created on approval with `feature` label

---

## Example PRD

```markdown
# PRD: Task Priority System

## Introduction

Add priority levels to tasks so users can focus on what matters most. Tasks can be marked as high, medium, or low priority, with visual indicators and filtering to help users manage their workload effectively.

## Goals

- Allow assigning priority (high/medium/low) to any task
- Provide clear visual differentiation between priority levels
- Enable filtering and sorting by priority
- Default new tasks to medium priority

## User Stories

### US-001: Add priority field to data model
**Description:** As a developer, I need to store task priority so it persists across sessions.

**Codebase Context** (from Step 0 analysis):
- Existing model: `src/models/Task` (has fields: title, status, assignee)
- Migration pattern: project uses sequential numbered migrations in `db/migrations/`
- Existing enum pattern: `Status` enum used for task status field

**Acceptance Criteria:**
- [ ] Add `priority` field to Task model (enum: high | medium | low, default: medium)
- [ ] Create migration to add the column
- [ ] Update seed/test data if applicable
- [ ] Typecheck passes

### US-002: Display priority indicator on task cards
**Description:** As a user, I want to see task priority at a glance so I know what needs attention first.

**Acceptance Criteria:**
- [ ] Each task card shows colored priority badge (red=high, yellow=medium, gray=low)
- [ ] Priority visible without hovering or clicking
- [ ] Typecheck passes
- [ ] Manual visual verification by user (open in browser, check layout/interactions)

### US-003: Add priority selector to task edit
**Description:** As a user, I want to change a task's priority when editing it.

**Acceptance Criteria:**
- [ ] Priority dropdown in task edit modal
- [ ] Shows current priority as selected
- [ ] Saves immediately on selection change
- [ ] Typecheck passes
- [ ] Manual visual verification by user (open in browser, check layout/interactions)

### US-004: Filter tasks by priority
**Description:** As a user, I want to filter the task list to see only high-priority items when I'm focused.

**Acceptance Criteria:**
- [ ] Filter dropdown with options: All | High | Medium | Low
- [ ] Filter persists in URL params
- [ ] Empty state message when no tasks match filter
- [ ] Typecheck passes
- [ ] Manual visual verification by user (open in browser, check layout/interactions)

## Functional Requirements

- FR-1: Add `priority` field to tasks table ('high' | 'medium' | 'low', default 'medium')
- FR-2: Display colored priority badge on each task card
- FR-3: Include priority selector in task edit modal
- FR-4: Add priority filter dropdown to task list header
- FR-5: Sort by priority within each status column (high to medium to low)

## Non-Goals

- No priority-based notifications or reminders
- No automatic priority assignment based on due date
- No priority inheritance for subtasks

## Technical Considerations

**Codebase findings (Step 0):**
- Existing `Task` model at `src/models/Task` with fields: title, status, assignee
- Existing `Badge` component at `src/components/Badge` supports color variants
- Task list uses URL search params for existing filters (status, assignee)

**Implementation notes:**
- Reuse existing badge component with color variants
- Filter state managed via URL search params (extend existing pattern)
- Priority stored in database, not computed

## Success Metrics

- Users can change priority in under 2 clicks
- High-priority tasks immediately visible at top of lists
- No regression in task list performance

## Open Questions

- Should priority affect task ordering within a column?
- Should we add keyboard shortcuts for priority changes?
```

---

## Checklist

Before finishing:

- [ ] Ran codebase analysis with 3 parallel researchers (Step 0)
- [ ] Asked clarifying questions with lettered options
- [ ] Incorporated user's answers
- [ ] User stories are small and specific
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals section defines clear boundaries
- [ ] Saved to `.workflow/prds/prd-[feature-name].md`
- [ ] Presented PRD to user for approval
- [ ] On approval: Created GitHub Issue with `feature` label via `gh issue create`
