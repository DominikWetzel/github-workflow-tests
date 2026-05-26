#!/bin/bash

set -e

BRANCH="${BRANCH:?BRANCH environment variable is required}"
LOCK="${LOCK:?LOCK environment variable is required}"

OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

PROTECTION=$(gh api "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" 2>&1) || {
  if echo "${PROTECTION}" | jq -e '.status == "404"' > /dev/null 2>&1; then
    echo "No branch protection configured — nothing to do"
    exit 0
  fi
  echo "${PROTECTION}" >&2
  exit 1
}

IS_LOCKED=$(echo "${PROTECTION}" | jq -r '.lock_branch.enabled // false')

if [ "${LOCK}" = "true" ] && [ "${IS_LOCKED}" = "true" ]; then
  echo "Already locked — skipping"
  exit 0
fi

if [ "${LOCK}" = "false" ] && [ "${IS_LOCKED}" = "false" ]; then
  echo "Already unlocked — nothing to do"
  exit 0
fi

REQUEST_BODY=$(echo "${PROTECTION}" | jq --argjson lock "${LOCK}" '{
  lock_branch: $lock,
  enforce_admins: (.enforce_admins.enabled // false),
  required_status_checks: (
    if .required_status_checks then {
      strict: .required_status_checks.strict,
      contexts: (.required_status_checks.contexts // []),
      checks: ((.required_status_checks.checks // []) | map({ context: .context, app_id: .app_id }))
    } else null end
  ),
  required_pull_request_reviews: (
    if .required_pull_request_reviews then {
      dismiss_stale_reviews: .required_pull_request_reviews.dismiss_stale_reviews,
      require_code_owner_reviews: .required_pull_request_reviews.require_code_owner_reviews,
      required_approving_review_count: .required_pull_request_reviews.required_approving_review_count,
      require_last_push_approval: .required_pull_request_reviews.require_last_push_approval,
      dismissal_restrictions: (
        if .required_pull_request_reviews.dismissal_restrictions then {
          users: (.required_pull_request_reviews.dismissal_restrictions.users | map(.login)),
          teams: (.required_pull_request_reviews.dismissal_restrictions.teams | map(.slug)),
          apps: ((.required_pull_request_reviews.dismissal_restrictions.apps // []) | map(.slug))
        } else null end
      )
    } else null end
  ),
  restrictions: (
    if .restrictions then {
      users: (.restrictions.users | map(.login)),
      teams: (.restrictions.teams | map(.slug)),
      apps: ((.restrictions.apps // []) | map(.slug))
    } else null end
  )
}')

gh api \
  --method PUT \
  "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" \
  --input - <<< "${REQUEST_BODY}"

if [ "${LOCK}" = "true" ]; then
  echo "Branch ${BRANCH} locked"
else
  echo "Branch ${BRANCH} unlocked"
fi
