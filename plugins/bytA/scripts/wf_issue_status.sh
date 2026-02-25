#!/usr/bin/env bash
# wf_issue_status.sh — Set GitHub issue status on project board (best-effort)
# Usage: wf_issue_status.sh <issue_number> [status]
# Example: wf_issue_status.sh 42 "In Progress"
# Never fails the workflow — exits 0 even on error.

ISSUE_NUMBER="${1:-}"
TARGET_STATUS="${2:-In Progress}"

if [ -z "$ISSUE_NUMBER" ]; then
  echo "WARN: No issue number provided, skipping status update"
  exit 0
fi

# Get repo owner/name
REPO_INFO=$(gh repo view --json owner,name -q '.owner.login + "/" + .name' 2>/dev/null) || {
  echo "WARN: Could not determine repo, skipping status update"
  exit 0
}
OWNER="${REPO_INFO%%/*}"
REPO="${REPO_INFO##*/}"

# Find project items for this issue via GraphQL
PROJECT_ITEMS=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        projectItems(first: 5) {
          nodes {
            id
            project { id title }
          }
        }
      }
    }
  }
' -f owner="$OWNER" -f repo="$REPO" -F number="$ISSUE_NUMBER" 2>/dev/null) || {
  echo "WARN: Could not fetch project items for issue #$ISSUE_NUMBER, skipping"
  exit 0
}

# Extract first project item
ITEM_ID=$(echo "$PROJECT_ITEMS" | jq -r '.data.repository.issue.projectItems.nodes[0].id // empty' 2>/dev/null)
PROJECT_ID=$(echo "$PROJECT_ITEMS" | jq -r '.data.repository.issue.projectItems.nodes[0].project.id // empty' 2>/dev/null)
PROJECT_TITLE=$(echo "$PROJECT_ITEMS" | jq -r '.data.repository.issue.projectItems.nodes[0].project.title // empty' 2>/dev/null)

if [ -z "$ITEM_ID" ] || [ -z "$PROJECT_ID" ]; then
  echo "WARN: Issue #$ISSUE_NUMBER not on any project board, skipping status update"
  exit 0
fi

# Get status field and its options from the project
FIELD_INFO=$(gh api graphql -f query='
  query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        fields(first: 20) {
          nodes {
            ... on ProjectV2SingleSelectField {
              id
              name
              options { id name }
            }
          }
        }
      }
    }
  }
' -f projectId="$PROJECT_ID" 2>/dev/null) || {
  echo "WARN: Could not fetch project fields, skipping status update"
  exit 0
}

# Find the Status field ID and the target option ID
STATUS_FIELD_ID=$(echo "$FIELD_INFO" | jq -r '[.data.node.fields.nodes[] | select(.name == "Status")][0].id // empty' 2>/dev/null)
OPTION_ID=$(echo "$FIELD_INFO" | jq -r --arg status "$TARGET_STATUS" '[.data.node.fields.nodes[] | select(.name == "Status")][0].options[] | select(.name == $status) | .id // empty' 2>/dev/null)

if [ -z "$STATUS_FIELD_ID" ] || [ -z "$OPTION_ID" ]; then
  echo "WARN: Status field or '$TARGET_STATUS' option not found on project '$PROJECT_TITLE', skipping"
  exit 0
fi

# Update the status
gh api graphql -f query='
  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $projectId
      itemId: $itemId
      fieldId: $fieldId
      value: { singleSelectOptionId: $optionId }
    }) {
      projectV2Item { id }
    }
  }
' -f projectId="$PROJECT_ID" -f itemId="$ITEM_ID" -f fieldId="$STATUS_FIELD_ID" -f optionId="$OPTION_ID" >/dev/null 2>&1 || {
  echo "WARN: Could not update status, skipping"
  exit 0
}

echo "Issue #$ISSUE_NUMBER → '$TARGET_STATUS' (project: $PROJECT_TITLE)"
