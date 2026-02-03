---
description: "Generate a Product Requirements Document (PRD) for a new feature. Use when planning a feature, starting a new project, or when asked to create a PRD. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."
---

# PRD Generator

Create Product Requirements Documents that focus on the **"What"** and **"Why"** — not the technical "How". Technical implementation details belong in the Technical Specification (Phase 0 of the full-stack-feature workflow).

> "A PRD should avoid anticipating or defining how the product will do it, in order to later allow designers and engineers to use their expertise to provide the optimal solution." — [Wikipedia](https://en.wikipedia.org/wiki/Product_requirements_document)

---

## The Job

1. Receive a feature description from the user
2. Ask 3-5 clarifying questions about goals, users, and scope
3. Generate a user-focused PRD (no code references!)
4. Save to `docs/prds/prd-[feature-name].md`
5. Present the PRD to the user for approval
6. On approval → Create a GitHub Issue with the PRD content

**Important:**
- Do NOT analyze the codebase — that's the Architect-Planner's job (Phase 0)
- Do NOT reference specific files, classes, tables, or endpoints
- Focus on user needs, business value, and acceptance criteria

---

## Step 1: Clarifying Questions

Ask only critical questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve? Why now?
- **Target Users:** Who benefits from this feature?
- **Core Functionality:** What are the key user actions?
- **Scope/Boundaries:** What should it NOT do?
- **Success Criteria:** How do we know it's successful?

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

3. What is the MVP scope?
   A. Minimal — just the core functionality
   B. Standard — core + nice-to-haves
   C. Full — complete feature set
```

This lets users respond with "1A, 2C, 3B" for quick iteration.

---

## Step 2: PRD Structure

Generate the PRD with these sections:

### 1. Overview

Brief description of the feature and the problem it solves. Answer:
- What is being built?
- Why is it needed?
- Who is it for?

### 2. Goals

Specific, measurable objectives (bullet list). What does success look like?

### 3. User Stories

Each story needs:
- **Title:** Short descriptive name
- **Description:** "As a [user], I want [action] so that [benefit]"
- **Acceptance Criteria:** Verifiable checklist from the user's perspective

**Format:**
```markdown
### US-001: [Title]
**Description:** As a [user type], I want [action] so that [benefit].

**Acceptance Criteria:**
- [ ] User can [observable behavior]
- [ ] System displays [expected feedback]
- [ ] [Edge case] is handled gracefully
```

**Rules for User Stories:**
- Write from the **user's perspective**, not the developer's
- Describe **observable behavior**, not implementation
- Keep stories small enough for one focused session
- **NO code references** — no file names, class names, database tables, or API endpoints

**Good Examples:**
- "As a user, I want to see my task's priority at a glance so I can focus on what's urgent"
- "As an admin, I want to export user data as CSV so I can analyze it in Excel"

**Bad Examples (too technical):**
- ~~"Add `priority` field to Task model"~~ → This belongs in Technical Spec
- ~~"Extend `OrderService` with `cancelOrder()` method"~~ → This belongs in Technical Spec
- ~~"Create migration to add column"~~ → This belongs in Technical Spec

### 4. Functional Requirements

Numbered list of **what** the system must do (not how):
- "FR-1: The system must allow users to..."
- "FR-2: When a user performs X, the system must respond with Y..."

Be explicit and unambiguous, but stay at the functional level.

### 5. Non-Goals (Out of Scope)

What this feature will NOT include. Critical for managing scope and expectations.

### 6. User Experience Considerations

- Key user flows and interactions
- Important UI states (loading, empty, error)
- Accessibility requirements
- Mobile/responsive considerations

**Note:** This is NOT a wireframe or design spec. Just describe the expected experience.

### 7. Constraints & Dependencies

High-level constraints that affect the feature:
- Business rules or policies
- External dependencies (third-party services, APIs)
- Timing constraints (must ship before X)
- Compliance requirements (GDPR, accessibility)

**Note:** Do NOT include technical architecture here. That's the Architect-Planner's job.

### 8. Success Metrics

How will success be measured?
- "Reduce time to complete X by 50%"
- "Increase conversion rate by 10%"
- "Decrease support tickets about Y by 30%"

### 9. Open Questions

Remaining questions or areas needing clarification before implementation.

---

## Step 3: User Approval & GitHub Issue

After saving the PRD file, present it to the user and ask:

```
PRD gespeichert unter docs/prds/prd-[feature-name].md

Soll ich ein GitHub Issue mit dieser PRD erstellen?
```

### On Approval: Create GitHub Issue

Use `gh issue create` to create the issue. The PRD content becomes the issue body.

**Rules:**
- **Title:** `feat: [Feature Name]` (derived from the PRD title)
- **Body:** The complete PRD markdown content (read from the saved file)
- **Label:** `feature` (create if it doesn't exist)
- **No assignee** — the user assigns manually

**Command pattern:**
```bash
mkdir -p docs/prds
gh label create "feature" --description "New feature" --color "0E8A16" --force
gh issue create --title "feat: [Feature Name]" --label "feature" --body-file "docs/prds/prd-[feature-name].md"
```

**Important:**
- Always use `--body-file` to pass the PRD content (avoids shell escaping issues)
- Show the created issue URL to the user after creation
- If the user declines, skip issue creation — the PRD file is still saved

---

## Output

- **Format:** Markdown (`.md`)
- **Location:** `docs/prds/`
- **Filename:** `prd-[feature-name].md` (kebab-case)
- **GitHub Issue:** Created on approval with `feature` label

---

## Example PRD

```markdown
# PRD: Task Priority System

## Overview

Users need a way to mark tasks as high, medium, or low priority so they can focus on what matters most. Currently, all tasks appear equal, making it hard to identify urgent work.

**Target Users:** All users who manage tasks in the system.

## Goals

- Enable users to quickly identify their most important tasks
- Reduce time spent deciding what to work on next
- Improve task completion rates for high-priority items

## User Stories

### US-001: Set task priority
**Description:** As a user, I want to assign a priority level to my tasks so that I can indicate which ones are most urgent.

**Acceptance Criteria:**
- [ ] User can select priority (high, medium, low) when creating a task
- [ ] User can change priority on existing tasks
- [ ] New tasks default to medium priority
- [ ] Priority change is saved immediately

### US-002: See priority at a glance
**Description:** As a user, I want to see task priority visually so that I can quickly identify urgent tasks without clicking into them.

**Acceptance Criteria:**
- [ ] Each task displays a visual priority indicator (color, icon, or badge)
- [ ] High priority is visually distinct from medium and low
- [ ] Priority indicator is visible in all task list views

### US-003: Filter by priority
**Description:** As a user, I want to filter my task list by priority so that I can focus on high-priority items when I'm busy.

**Acceptance Criteria:**
- [ ] User can filter to show only high/medium/low priority tasks
- [ ] Filter state persists when navigating away and back
- [ ] Clear indication when a filter is active
- [ ] Easy way to clear the filter and see all tasks

### US-004: Sort by priority
**Description:** As a user, I want to sort my task list by priority so that urgent tasks appear at the top.

**Acceptance Criteria:**
- [ ] User can sort tasks by priority (high → medium → low)
- [ ] Sort option is easily accessible
- [ ] Sort can be combined with other sorting options (e.g., due date)

## Functional Requirements

- FR-1: The system must support three priority levels: high, medium, low
- FR-2: The system must allow priority to be set during task creation
- FR-3: The system must allow priority to be changed on existing tasks
- FR-4: The system must display a visual indicator for each priority level
- FR-5: The system must support filtering tasks by priority
- FR-6: The system must support sorting tasks by priority

## Non-Goals

- Priority-based notifications or reminders
- Automatic priority assignment based on due date
- Priority inheritance for subtasks
- Priority analytics or reporting

## User Experience Considerations

- Priority selector should be quick to use (max 2 clicks)
- Visual indicators should be colorblind-accessible
- Mobile users should be able to change priority easily
- Consider keyboard shortcuts for power users

## Constraints & Dependencies

- Must work with existing task management workflow
- Should not significantly increase page load time
- Priority data must be included in any existing export features

## Success Metrics

- 70% of users assign priority to at least one task within first week
- Users report finding urgent tasks faster (survey)
- No increase in task abandonment rate

## Open Questions

- Should priority affect the default sort order automatically?
- Should we allow custom priority labels in the future?
- How should priority be displayed in calendar/timeline views?
```

---

## Checklist

Before finishing:

- [ ] Asked clarifying questions about goals, users, and scope
- [ ] Incorporated user's answers
- [ ] User stories are written from user perspective (no code references!)
- [ ] Acceptance criteria describe observable behavior
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals section defines clear boundaries
- [ ] No technical implementation details (that's the Architect-Planner's job)
- [ ] Saved to `docs/prds/prd-[feature-name].md`
- [ ] Presented PRD to user for approval
- [ ] On approval: Created GitHub Issue with `feature` label

