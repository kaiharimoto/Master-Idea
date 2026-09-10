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

So the publish job fires on the default branch **or** on a development
branch. The default-branch clause is written first and stays correct the moment
this repository has one; when it does, the second clause is the thing to
delete.

**Amended while walking the workflow before shipping.** It named one branch,
by name. Every session after the one that wrote it works on a branch of its
own, so from that point the pipeline built green and published nothing, while
the release page users are told to bookmark went on serving a build from weeks
earlier — and an installed copy that has quietly stopped seeing updates says
nothing about it to anybody. The condition is now a prefix, `claude/*`, which
is what a development branch here is called. The newest green push owns the
`dev` tag, which is what the tag has always meant.

Two properties are kept whatever the branch: pull requests never publish, and
every asset carries its build number and commit in its name, so a downloaded
file is identifiable months later and the updater can tell which build it is
looking at.
