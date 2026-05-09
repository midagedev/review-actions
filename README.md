# review-actions

Reusable GitHub Actions for AI-assisted pull request review.

The first workflow is a Z.ai-backed PR reviewer built around
`anthropics/claude-code-action`.

## Z.ai PR Review

Caller repositories should add a small workflow that calls:

```yaml
uses: midagedev/review-actions/.github/workflows/zai-pr-review.yml@v1
```

Required caller secret:

- `ZAI_API_KEY`: Z.ai API key for the Anthropic-compatible endpoint.

Recommended caller permissions:

```yaml
permissions:
  contents: read
  pull-requests: write
  id-token: write
```

For public repositories, only run the automatic PR trigger for same-repository
branches. Use `workflow_dispatch` for external fork PRs after reviewing the
risk.

## Install In A Repository

Copy `examples/zai-review.yml` into the target repository as:

```text
.github/workflows/zai-review.yml
```

Optionally add a repository-specific prompt at:

```text
.github/zai-review-prompt.md
```

Set the secret:

```bash
gh secret set ZAI_API_KEY --repo OWNER/REPO --body "$ZAI_API_KEY"
```

For local use with an existing `ccz` alias that contains
`ANTHROPIC_AUTH_TOKEN=...`, extract the token without printing it:

```bash
ZAI_API_KEY="$(zsh -ic 'alias ccz' | sed -nE 's/.*ANTHROPIC_AUTH_TOKEN=([^ ]+).*/\1/p')"
gh secret set ZAI_API_KEY --repo OWNER/REPO --body "$ZAI_API_KEY"
unset ZAI_API_KEY
```

## Rollout Notes

- Use the caller workflow in each repository, not a copy of the central reusable
  workflow.
- Keep the central workflow pinned from callers with a stable ref, for example
  `@v1`.
- For public repositories, avoid `pull_request_target` unless the workflow is
  explicitly hardened for untrusted code.
