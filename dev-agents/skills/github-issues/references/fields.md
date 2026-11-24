# Issue Fields

Issue fields are typed metadata that the repository owner defines for all of its repositories (GitHub's defaults: `Priority`, `Effort`, `Start date`, `Target date`). `gh` has no flags for them. Apply this file only when the Capabilities query lists fields.

## Rules

- The `P0`-`P4` label stays the priority of record. Mirror it into a `Priority` field only when the field's options are named `P0`-`P4`; never translate between scales.
- Set a field only from a fact the caller has: a deadline the issue states, an effort class from triage. Do not guess a value.
- A field the caller knows nothing about stays empty.

## Discover

```bash
gh api graphql -F owner='{owner}' -F repo='{repo}' -f query='
  query($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
      issueFields(first: 25) { nodes {
        ... on Node { id }
        ... on IssueFieldCommon { name dataType }
        ... on IssueFieldSingleSelect { options { id name } }
        ... on IssueFieldMultiSelect { options { id name } }
      } }
    }
  }' --jq '.data.repository.issueFields.nodes'
```

## Read

```bash
gh api repos/{owner}/{repo}/issues/<n>/issue-field-values
```

## Set

```bash
gh api graphql -f issue="$(gh issue view <n> --json id --jq .id)" -f field="<field id>" -f option="<option id>" -f query='
  mutation($issue: ID!, $field: ID!, $option: ID!) {
    setIssueFieldValue(input: {issueId: $issue, issueFields: [{fieldId: $field, singleSelectOptionId: $option}]}) { issue { number } }
  }'
```

One entry of `issueFields` per field; several fields go in one call. The value key follows the field's `dataType`:

| `dataType` | Key | Value |
|------------|-----|-------|
| `SINGLE_SELECT` | `singleSelectOptionId` | option id |
| `MULTI_SELECT` | `multiSelectOptionIds` | list of option ids |
| `DATE` | `dateValue` | `YYYY-MM-DD` |
| `NUMBER` | `numberValue` | number |
| `TEXT` | `textValue` | string |

`delete: true` in place of a value clears the field.
