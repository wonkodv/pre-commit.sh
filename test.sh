#!/usr/bin/env bash
set -xuo pipefail

GREEN='\e[32m'
RED='\e[31m'
NC='\e[0m' # No Color

main() {
    run_test test_1_1
    run_test test_1_2
    run_test test_2_1_1
    run_test test_2_1_2
    run_test test_2_2_1
    run_test test_2_2_2_1
    run_test test_2_2_2_2
}

run_test() {
    local test_name=$1
    local tests_failed=0
    echo "--- running $test_name ---"
    (
        set -e
        setup
        "$test_name"
        cleanup
    )
    if [ $? -eq 0 ]; then
        echo -e "--- ${GREEN}success${NC} ---"
    else
        echo -e "--- ${RED}failed${NC} ---"
        ((tests_failed++))
    fi
    if [ "$tests_failed" -ne 0 ]; then
        exit 1
    fi
}

setup() {
    TEST_DIR=$(mktemp -d)
    git -C "$TEST_DIR" init -b main >/dev/null
    git -C "$TEST_DIR" config user.email "test@example.com"
    git -C "$TEST_DIR" config user.name "Test"
    git -C "$TEST_DIR" commit --allow-empty -m "initial commit"
    mkdir -p "$TEST_DIR"/.git/hooks
    echo "bash -x $(pwd)/pre-commit.sh" > "$TEST_DIR"/.git/hooks/pre-commit
    chmod +x "$TEST_DIR"/.git/hooks/pre-commit
    cd "$TEST_DIR"
}

cleanup() {
    rm -rf "$TEST_DIR"
}

assert_last_commit_message() {
    if [ "$(git log -1 --pretty=%B)" != "$1" ]; then
        echo "expected last commit message to be '$1', but found '$(git log -1 --pretty=%B)'"
        return 1
    fi
}

assert_file_content() {
    if [ "$(cat "$1")" != "$2" ]; then
        echo "expected file '$1' to contain '$2', but found '$(cat "$1")'"
        return 1
    fi
}

assert_no_patch_file() {
    if [ -n "$(find . -name '.pre-commit-unstaged-patch-*')" ]; then
        echo "expected no patch file, but found one"
        return 1
    fi
}

assert_patch_file() {
    if [ -z "$(find . -name '.pre-commit-unstaged-patch-*')" ]; then
        echo "expected patch file, but found none"
        return 1
    fi
}

test_1_1() {
    echo "should commit if there are no unstaged changes and the formatter does not make any changes"
    export PRE_COMMIT_FORMATTER=true
    echo "a" >file
    git add file
    git commit -m "test"
    assert_last_commit_message "test"
}

test_1_2() {
    echo "should abort commit if there are no unstaged changes and the formatter makes changes"
    export PRE_COMMIT_FORMATTER="sed -i s/a/b/g"
    echo "a" >file
    git add file
    if git commit -m "test"; then
        return 1
    fi
    assert_file_content file b
    assert_last_commit_message "initial commit"
}

test_2_1_1() {
    echo "should commit if there are unstaged changes and the formatter does not make any changes"
    export PRE_COMMIT_FORMATTER=true
    echo "staged" >file
    git add file
    echo "unstaged" >file
    git commit -m "test"
    assert_last_commit_message "test"
    assert_file_content file unstaged
    assert_no_patch_file
}

test_2_1_2() {
    echo "should abort commit if there are unstaged changes, the formatter does not make any changes, but the user modifies the file"
    export PRE_COMMIT_FORMATTER="true"
    echo "staged" >file
    git add file
    echo "unstaged" >file
    (
        while true
        do
            echo "user modification" >file
        done
    ) &
    pid=$!
    if git commit -m "test"; then
        return 1
    fi
    kill $pid
    assert_last_commit_message "initial commit"
    assert_patch_file
}

test_2_2_1() {
    echo "should abort commit if there are unstaged changes and the formatter makes changes"
    export PRE_COMMIT_FORMATTER="sed -i s/a/b/g"
    echo "staged a" >file
    git add file
    echo "unstaged a" >file
    if git commit -m "test"; then
        return 1
    fi
    assert_file_content file "unstaged a"
    assert_last_commit_message "initial commit"
    assert_no_patch_file
}

test_2_2_2_1() {
    echo "should abort commit if there are unstaged changes and the formatter makes changes that conflict with the unstaged changes"
    export PRE_COMMIT_FORMATTER="sed -i s/staged/formatted/g"
    echo "staged" >file
    git add file
    echo "unstaged" >file
    if git commit -m "test"; then
        return 1
    fi
    assert_file_content file unstaged
    assert_last_commit_message "initial commit"
    assert_no_patch_file
}

test_2_2_2_2() {
    echo "should abort commit if there are unstaged changes, the formatter makes changes that conflict with the unstaged changes, and the user modifies the file"
    export PRE_COMMIT_FORMATTER="sed -i s/staged/formatted/g"
    echo "staged" >file
    git add file
    echo "unstaged" >file
    (
        while true
        do
            echo "user modification" >file
        done
    ) &
    pid=$!
    if git commit -m "test"; then
        return 1
    fi
    kill $pid
    assert_last_commit_message "initial commit"
    assert_patch_file
}

main
