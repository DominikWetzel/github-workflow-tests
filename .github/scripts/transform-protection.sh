#!/usr/bin/env bash
# transform-protection.sh
#
# Transforms the GitHub branch protection GET response format into the PUT
# request format, setting lock_branch to the requested value while preserving
# all other existing protection settings.
#
# Usage:
#   echo "$EXISTING_JSON" | bash .github/scripts/transform-protection.sh --lock
#   echo "$EXISTING_JSON" | bash .github/scripts/transform-protection.sh --unlock
#
# Outputs: a JSON payload ready to be passed to `gh api --input -` for
#          PUT /repos/{owner}/{repo}/branches/{branch}/protection

set -euo pipefail

case "${1:-}" in
  --lock)   LOCK_VALUE="true"  ;;
  --unlock) LOCK_VALUE="false" ;;
  *)
    echo "Usage: $0 --lock | --unlock" >&2
    exit 1
    ;;
esac

jq --argjson lock "$LOCK_VALUE" '{
  required_status_checks: (
    if .required_status_checks then {
      strict: .required_status_checks.strict,
      contexts: (.required_status_checks.contexts // []),
      checks:   (.required_status_checks.checks   // [])
    } else null end
  ),
  enforce_admins: (.enforce_admins.enabled // false),
  required_pull_request_reviews: (
    if .required_pull_request_reviews then {
      dismiss_stale_reviews:          (.required_pull_request_reviews.dismiss_stale_reviews          // false),
      require_code_owner_reviews:     (.required_pull_request_reviews.require_code_owner_reviews     // false),
      required_approving_review_count:(.required_pull_request_reviews.required_approving_review_count // 0)
    } else null end
  ),
  restrictions: (
    if .restrictions then {
      users: [.restrictions.users[].login],
      teams: [.restrictions.teams[].slug],
      apps:  [.restrictions.apps[].slug]
    } else null end
  ),
  lock_branch: $lock
}'
