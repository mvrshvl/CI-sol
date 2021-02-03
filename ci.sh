#!/usr/bin/env bash

set -e +o pipefail

token=""
if [ "$GITLAB_CI" != "" ];
then
  service="gitlab"
  branch="${CI_BUILD_REF_NAME:-$CI_COMMIT_REF_NAME}"
  commit="${CI_BUILD_REF:-$CI_COMMIT_SHA}"
  repo_path="${CI_PROJECT_ID}"
  main_branch="${CI_DEFAULT_BRANCH}"
  pull_req="${CI_MERGE_REQUEST_ID}"
  pre_commit="${CI_COMMIT_BEFORE_SHA}"


elif [ "$GITHUB_ACTIONS" != "" ];
then
  service="github"
  main_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
  echo "Main Branch" "$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
  branch="${GITHUB_REF#refs/heads/}"
  pre_commit=""

  if [  "$GITHUB_HEAD_REF" != "" ];
  then
    pr="${GITHUB_REF#refs/pull/}"
    pr="${pr%/merge}"
    pull_req="$pr"
    branch="${GITHUB_HEAD_REF}"
    pre_commit=""
  fi
  commit="${GITHUB_SHA}"
  repo_path="${GITHUB_REPOSITORY}"

  mc=
  if [ -n "$pr" ] && [ "$pr" != false ];
  then
    mc=$(git show --no-patch --format="%P" 2>/dev/null || echo "")

    if [[ "$mc" =~ ^[a-z0-9]{40}[[:space:]][a-z0-9]{40}$ ]];
    then
      mc=$(echo "$mc" | cut -d' ' -f2)
      say "    Fixing merge commit SHA $commit -> $mc"
      commit=$mc
    elif [[ "$mc" = "" ]];
    then
      say "$r->  Issue detecting commit SHA. Please run actions/checkout with fetch-depth > 1 or set to 0$x"
    fi
  fi
fi

  body="
  {
  \"Service\":\"$service\",
  \"Token\":\"$token\",
  \"Commit\":\"$commit\",
  \"RepoPath\":\"$repo_path\",
  \"Branch\":\"$branch\",
  \"PullRequest\":\"$pull_req\",
  \"MainBranch\":\"$main_branch\",
  \"PreCommit\":\"$pre_commit\"
  }"

  echo "$body"

  res=$(curl -X POST -H "Content-Type: application/json" -d "$body" http://localhost:8080/check)

  echo "$res"

  status=$(echo "$res" | head -1 | cut -d' ' -f2)
  if [ "$status" = "" ] || [ "$status" = "200" ];
  then
    exit 0
  else
    exit 2
  fi