# 0013 · The rolling `dev` release publishes from the development branch

**Made:** when CI was given a publish job.
**Standing:** in force until this repository has a default branch with the
build on it. **Deviation from Master Prompt**, recorded in `parity.md`.

Master Prompt publishes its rolling `dev` prerelease only from the default
branch, and the reason is good: a pull request should not move the build
everyone is installing from.

This repository has exactly one branch — the development branch this work is
on — so that condition would never fire and there would be nothing to download.
A build nobody can install is not a build, and the whole point of the release
pipeline is that the person this is for can put it on their phone.

So the publish job fires on the default branch **or** on the development
branch. The default-branch clause is written first and stays correct the moment
this repository has one; when it does, the second clause is the thing to
delete.

Two properties are kept whatever the branch: pull requests never publish, and
every asset carries its build number and commit in its name, so a downloaded
file is identifiable months later and the updater can tell which build it is
looking at.
