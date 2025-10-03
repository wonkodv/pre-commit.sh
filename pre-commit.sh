#!/usr/bin/env bash
set -euo pipefail
# git commands to only format staged changes mostly copied from 
# [pre-commit.py](https://github.com/pre-commit/pre-commit/blob/917e2102be90a6384cf514ddc0edefbc563b49fc/pre_commit/staged_files_only.py#L51)

tree=$(git write-tree)
patch_file=.pre-commit-unstaged-patch-$(date +%s)

if git diff-index --ignore-submodules --binary --exit-code --no-color --no-ext-diff "$tree" -- > "$patch_file"
then
    rm "$patch_file"
else
    echo "PRE: unstaged changes stored in $patch_file"
    restore() {
        echo -e "PRE: Restoring unstaged changes from $patch_file"
        if ! git apply --whitespace=nowarn "$patch_file"
        then
            echo -e "PRE: \e[32mconflicting changes, undoing hook\'s changes\e[0m"
            git -c submodule.recurse=0 checkout -- .
            echo -e "PRE: Restoring unstaged changes from $patch_file again"
            git apply --whitespace=nowarn "$patch_file"
        fi
        echo "PRE: removing $patch_file"
        rm "$patch_file"
    }
    trap restore EXIT

    # revert unstaged changes
    git -c submodules.recurse=0 checkout -- .
fi

# shellcheck disable=SC2086 (PRE_COMMIT_FORMATTER should be split)
git diff --cached --name-only --diff-filter=AM -z | xargs -0 ${PRE_COMMIT_FORMATTER:-nix fmt} 2>&1

if ! git diff --quiet
then
    echo -e "PRE: \e[31mFiles changed, commit aborted\e[0m"
    exit 1
else
    exit 0
fi
