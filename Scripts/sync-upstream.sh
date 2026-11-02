#!/bin/zsh
set -euo pipefail

# Merges upstream Crest's main into this fork.
#
# The merge takes upstream's copy of Config/Version.xcconfig, merges
# Documentation/ReleaseNotes.json three ways (Scripts/merge-release-notes.py)
# and takes upstream's copy of every generated file and the built guides. When
# nothing else conflicts it regenerates the contract sources and the Xcode
# project, runs the lint, the script tests and the version check, and commits.
# Anything else that conflicts is left in the index for a person; after
# resolving and staging those files, --continue finishes the same steps.
#
#   Scripts/sync-upstream.sh [--upstream <remote>] [--branch <name>]
#                            [--no-commit] [--skip-checks] [--build]
#   Scripts/sync-upstream.sh --continue [--no-commit] [--skip-checks] [--build]
#
# --upstream names the remote for pauljoda/Crest; by default the script finds
# it by URL and adds one called "upstream" when none exists. --no-commit stops
# after resolving so the merge can be reviewed. --build also builds the Crest
# scheme in Debug.

script_root="${0:A:h:h}"
cd "$script_root"

upstream_remote=""
upstream_branch="main"
should_commit=1
should_check=1
should_build=0
continuing=0

fail() {
    print -u2 "sync-upstream: $1"
    exit 1
}

while (( $# > 0 )); do
    case "$1" in
        --upstream) upstream_remote="${2:-}"; shift 2 ;;
        --branch) upstream_branch="${2:-}"; shift 2 ;;
        --no-commit) should_commit=0; shift ;;
        --skip-checks) should_check=0; shift ;;
        --build) should_build=1; shift ;;
        --continue) continuing=1; shift ;;
        -h|--help) sed -n '4,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) fail "unknown option $1" ;;
    esac
done

is_generated() {
    case "$1" in
        CrestContracts/include/*.h|CrestCore/src/CrestCore.Native/Generated/*|CrestShared/Infrastructure/Core/Generated/*) return 0 ;;
        *) return 1 ;;
    esac
}

# MARK: - Merge

start_merge() {
    [[ -z "$(git status --porcelain)" ]] || fail "commit or stash your changes first"
    ! git rev-parse -q --verify MERGE_HEAD >/dev/null || fail "a merge is in progress; finish it with --continue or 'git merge --abort'"

    if [[ -z "$upstream_remote" ]]; then
        upstream_remote="$(git remote -v | awk '/github\.com[:\/]pauljoda\/Crest(\.git)? \(fetch\)/ { print $1; exit }')"
    fi
    if [[ -z "$upstream_remote" ]]; then
        git remote add upstream https://github.com/pauljoda/Crest.git
        upstream_remote="upstream"
        print "Added the upstream remote https://github.com/pauljoda/Crest.git."
    fi

    git fetch --quiet "$upstream_remote" "$upstream_branch"
    local target="$upstream_remote/$upstream_branch"
    local current_branch="$(git branch --show-current)"
    [[ -n "$current_branch" ]] || fail "check out the branch that should receive upstream (detached HEAD)"

    if git merge-base --is-ancestor "$target" HEAD; then
        print "Already up to date with $target ($(git rev-parse --short "$target"))."
        exit 0
    fi

    print "Merging $target ($(git rev-parse --short "$target"), $(git rev-list --count --first-parent "HEAD..$target") upstream commits) into $current_branch."
    # The merge leaves conflicts in the index; the exit status only says so.
    git merge --no-ff --no-commit "$target" >/dev/null 2>&1 || true
}

# Resolves the files upstream owns outright. Prints what still needs a person.
resolve_owned_files() {
    local file base_file ours_file theirs_file
    for file in ${(f)"$(git diff --name-only --diff-filter=U)"}; do
        case "$file" in
            Config/Version.xcconfig)
                # The fork never bumps the version; upstream's line is the base.
                git checkout --quiet --theirs -- "$file"
                git add -- "$file"
                print -u2 "  took upstream's $file"
                ;;
            Documentation/ReleaseNotes.json)
                base_file="$(mktemp)"; ours_file="$(mktemp)"; theirs_file="$(mktemp)"
                git show ":1:$file" > "$base_file"
                git show ":2:$file" > "$ours_file"
                git show ":3:$file" > "$theirs_file"
                if python3 Scripts/merge-release-notes.py "$base_file" "$ours_file" "$theirs_file" --output "$file"; then
                    git add -- "$file"
                    print -u2 "  merged $file three ways"
                fi
                rm -f "$base_file" "$ours_file" "$theirs_file"
                ;;
            Crest.xcodeproj/*|Website/guides/*)
                # Regenerated from project.yml, or rebuilt from HelpCenter/.
                git checkout --quiet --theirs -- "$file"
                git add -- "$file"
                ;;
            *)
                if is_generated "$file"; then
                    git checkout --quiet --theirs -- "$file"
                    git add -- "$file"
                fi
                ;;
        esac
    done
    git diff --name-only --diff-filter=U
}

# MARK: - Finish

regenerate() {
    local target="$1"
    if [[ -n "$(git diff --name-only HEAD "$target" -- CrestCore/src/CrestCore/Contracts CrestCore/tools CrestContracts/include CrestCore/src/CrestCore.Native/Generated CrestShared/Infrastructure/Core/Generated)" ]]; then
        print "Regenerating the contract sources."
        Scripts/control-plane/generate-contracts.sh >/dev/null
        git add -- CrestContracts/include CrestCore/src/CrestCore.Native/Generated CrestShared/Infrastructure/Core/Generated
    fi
    if [[ -n "$(git diff --name-only HEAD "$target" -- project.yml Crest.xcodeproj)" ]]; then
        print "Regenerating the Xcode project."
        xcodegen generate >/dev/null
        git add -- Crest.xcodeproj
    fi
}

check() {
    print "Running the lint, the script tests and the version check."
    Scripts/control-plane/lint-dotnet.sh >/dev/null
    python3 -m unittest discover -s Scripts/Tests -p 'test_*.py' >/dev/null 2>&1 \
        || fail "the script tests fail on the merged tree; the merge is staged, not committed"
    Scripts/check-version.sh >/dev/null
    if (( should_build )); then
        print "Building the Crest scheme."
        xcodebuild build -scheme Crest -configuration Debug -destination 'platform=macOS' \
            CODE_SIGNING_ALLOWED=NO -quiet >/dev/null \
            || fail "the Debug build fails on the merged tree; the merge is staged, not committed"
    fi
}

commit_merge() {
    local target="$1"
    local message_file="$(mktemp)"
    {
        print "Merge upstream $upstream_branch at $(git rev-parse --short "$target")"
        print ""
        print "Brings in these upstream commits:"
        print ""
        git log --first-parent --format='- %s' "HEAD..$target"
    } > "$message_file"
    git commit --quiet --signoff -F "$message_file"
    rm -f "$message_file"
    print "Merged: $(git log --oneline -1)"
}

finish() {
    local target="$1"
    regenerate "$target"
    (( should_check )) && check
    if (( ! should_commit )); then
        print "Merge resolved and staged; review with 'git diff --cached', then 'git commit'."
        return
    fi
    commit_merge "$target"
}

# MARK: - Main

if (( continuing )); then
    git rev-parse -q --verify MERGE_HEAD >/dev/null || fail "no merge is in progress; run without --continue"
    [[ -z "$(git diff --name-only --diff-filter=U)" ]] || fail "unmerged files remain; resolve and 'git add' them first"
    finish MERGE_HEAD
    exit 0
fi

start_merge
unresolved=("${(@f)$(resolve_owned_files)}")
unresolved=("${(@)unresolved:#}")
if (( ${#unresolved} > 0 )); then
    print ""
    print "These files need a person. Read both sides' commits, resolve and 'git add' them, then"
    print "run 'Scripts/sync-upstream.sh --continue' (or 'git merge --abort' to drop the merge):"
    for file in "${unresolved[@]}"; do print "  $file"; done
    exit 1
fi
finish MERGE_HEAD
