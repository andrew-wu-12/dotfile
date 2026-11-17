#!/bin/bash
# Prints "<branch>(<repo>)" — the tmux-dev-layout.sh window-name suffix — for each open PR of mine, within the
# last 14 days, with an unresolved review thread whose last comment is someone else's (human or Copilot), or a
# non-empty human comment/review body newer than my own latest comment/review. Empty reviews (approvals,
# inline-only) and Copilot's overview are skipped: their actionable part is the threads.
# The window picker (prefix w) caches it and marks matching cards 💬. Exits non-zero when gh fails.
set -o pipefail

gh api graphql -f query='{
  viewer { login }
  search(query: "is:pr is:open author:@me archived:false", type: ISSUE, first: 30) {
    nodes { ... on PullRequest {
      headRefName repository { name }
      comments(last: 20) { nodes { author { __typename login } at: createdAt body } }
      reviews(last: 20) { nodes { author { __typename login } at: submittedAt body } }
      reviewThreads(last: 50) { nodes { isResolved comments(last: 1) { nodes { author { login } at: createdAt } } } }
    } }
  }
}' | jq -r '
  .data.viewer.login as $me
  | (now - 14 * 86400) as $since
  | .data.search.nodes[] as $pr
  | ([$pr.comments.nodes[], $pr.reviews.nodes[]] | map(select(.author))) as $top
  | ([$top[] | select(.author.login == $me) | .at | fromdate] | max // 0) as $mine
  | [($top[] | select(.author.login != $me and .author.__typename != "Bot" and .body != ""
                      and (.at | fromdate) > ([$mine, $since] | max))),
     ($pr.reviewThreads.nodes[] | select(.isResolved | not) | .comments.nodes[0]
      | select(.author and .author.login != $me and (.at | fromdate) > $since))]
  | select(length > 0)
  | "\($pr.headRefName)(\($pr.repository.name))"
'
