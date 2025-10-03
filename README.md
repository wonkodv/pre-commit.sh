# pre-commit.sh

a simple git pre-commit hook to run a formatter (or linter) on staged files before committing.

## Why

I've happily used `pre-commit.py`[^1] for years.
It is a very well made pre-commit hook, also a performant job runner, a build system for several languages,
a distributed configuration system and has ambitions to be your CI.
I just don't want to rely on python, yaml and 7000 lines of code to run `nix fmt` for me.

## How to use

```bash
cp --symbolic-link /path/to/your/pre-commit.sh/pre-commit.sh /path/to/your/repo/.git/hooks/pre-commit
```

**Note:** This script assumes that your repository has at least one commit. If you are initializing a new repository, please make an initial commit before installing and using this hook.

If you don't use `nix fmt` and you don't want to modify the file,
you can set `PRE_COMMIT_FORMATTER` to the formatter or linter you want.
The command is called with all the files that need checking on the command line.
The commit is aborted if the formatter returns an error
or if it ag, modifies a file.

## Does this work?

To only check the changes staged for commit,
the other changes need to be hidden from the formatter.
You can do this with `git stash`,
but it is a little trickier to work with than patch files.
The core logic is copied from the `pre-commit.py` project,
([staged_files_only.py](https://github.com/pre-commit/pre-commit/blob/917e2102be90a6384cf514ddc0edefbc563b49fc/pre_commit/staged_files_only.py#L51)).

While the script is short, the execution paths are surprisingly diverse:

-   Check for unstaged changes, store them to file
    1.  no unstaged changes
        -   remove empty patch file
        -   run formatter
            1. returns success (and a subsequent `git diff` detects no change):
                -   => commit
            2. returns an error or git diff detects a change
                -   => abort commit, leave formatter's changes in workspace
    2.  unstaged changes
        -   install exit hook (runs on normal exit, because of `set -e`, or because of SIGINT (Ctrl-C))
        -   revert unstaged changes
        -   run formatter
            1. returns success (and a subsequent `git diff` detects no change):
                -   **exit hook**: restore unstaged changes
                    1.  patch file applies cleanly
                        -   remove patch file
                        -   => commit staged changes
                        -   => leave unstaged changes in workdir
                    2.  patch does not apply (happens if the user modifies files)
                        -   => leave patch file for the user to clean up the mess
                        -   => abort commit
            2. returns an error or git diff detects a change
                -   **exit hook**: restore unstaged changes
                    1.  patch file applies cleanly
                        -   remove patch file
                        -   => leave unstaged changes and formatter changes in workdir
                    2.  patch does not apply
                        -   formatter made changes that conflict with the unstaged changes
                        -   remove changes from formatter
                        -   apply patch again
                            1.  patch file applies cleanly
                                -   remove patch file
                                -   => leave unstaged changes in workdir
                            2.  patch does not apply(happens if the user modifies files)
                                -   => leave patch file for the user to clean up the mess
                                -   => abort commit

[^1]: They call themselves [`pre-commit`](https://github.com/pre-commit/pre-commit).
    To me, `pre-commit` is specific git functionality.
