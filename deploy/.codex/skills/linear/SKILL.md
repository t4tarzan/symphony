# Linear Skill

Interact with Linear for issue management, comments, and state transitions.

## Available tools

Symphony injects a `linear_graphql` app-server tool that can execute raw Linear GraphQL queries.

## Common operations

### Read an issue

```graphql
query GetIssue($id: String!) {
  issue(id: $id) {
    id
    identifier
    title
    description
    state { name }
    labels { nodes { name } }
    comments { nodes { id body } }
    attachments { nodes { url title } }
  }
}
```

### Transition issue state

```graphql
mutation UpdateIssue($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: { stateId: $stateId }) {
    success
    issue { id state { name } }
  }
}
```

To find state IDs for your team:
```graphql
query TeamStates($teamId: String!) {
  team(id: $teamId) {
    states { nodes { id name } }
  }
}
```

### Create/update a comment (workpad)

```graphql
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) {
    success
    comment { id }
  }
}

mutation UpdateComment($id: String!, $body: String!) {
  commentUpdate(id: $id, input: { body: $body }) {
    success
  }
}
```

### Attach a PR to an issue

```graphql
mutation CreateAttachment($issueId: String!, $url: String!, $title: String!) {
  attachmentCreate(input: {
    issueId: $issueId
    url: $url
    title: $title
    iconUrl: "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png"
  }) {
    success
    attachment { id }
  }
}
```

## Rules

- Always use the `linear_graphql` tool injected by Symphony rather than calling Linear's HTTP API directly
- Keep the workpad comment updated in-place (update, don't recreate)
- State transitions must match the status map in WORKFLOW.md
- Never move an issue to `Done` — that's the human's job after reviewing the landed PR
