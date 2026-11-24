# REST Fallback

For a `gh` older than 2.94, which lacks `--type`, `--parent`, `--blocked-by`, `--blocking`, and the relation fields in `--json`. `gh api` reaches the same features. The write endpoints take the database `id` of the other issue, not its number.

## Read

```bash
gh api repos/{owner}/{repo}/issues/<n>/dependencies/blocked_by --jq '[.[] | {number, state, repo: .repository_url, assignees: [.assignees[].login]}]'
gh api repos/{owner}/{repo}/issues/<n>/dependencies/blocking --jq '[.[] | {number, state}]'
gh api repos/{owner}/{repo}/issues/<n>/sub_issues --jq '[.[] | {number, state}]'
gh api repos/{owner}/{repo}/issues/<n>/parent --jq '.number'   # 404 = no parent
gh api repos/{owner}/{repo}/issues/<n> --jq '.type.name'       # null = no type
```

## Write

File with `gh issue create` as usual, then add what the flags would have set:

```bash
gh api -X PATCH repos/{owner}/{repo}/issues/<n> -f type=Bug

id=$(gh api repos/{owner}/{repo}/issues/<blocker> --jq .id)
gh api -X POST repos/{owner}/{repo}/issues/<blocked>/dependencies/blocked_by -F issue_id="$id"

id=$(gh api repos/{owner}/{repo}/issues/<child> --jq .id)
gh api -X POST repos/{owner}/{repo}/issues/<parent>/sub_issues -F sub_issue_id="$id"
```

Statuses, relates-to, and fields do not depend on the `gh` version: they go through `gh api graphql` either way.
