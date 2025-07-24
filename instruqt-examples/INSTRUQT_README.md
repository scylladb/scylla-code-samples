
# Instruqt README

The purpose of the code in this folder is to provide coding examples and challenges 
to the Instruqt tracks related to drivers of particular programming languages.

Currently existing only on the fork of the `scylla-code-samples` from `eduardknezovic` in the `java-testcontainers` branch.

## How to get and update the code 

```
git clone https://github.com/eduardknezovic/scylla-code-samples
git checkout java-testcontainers
cd scylla-code-samples/instruqt-examples
```

And from there, the procedure for updating is standard for git flow.

```
git add .
git commit -am "message"
git push
```

## How to update the code on Instruqt VM 

After we've updated the version control on GitHub, we need to update the Instruqt VM.

Instruqt VM 

1. Go to https://play.instruqt.com/manage/scylladb/host-images
2. Select scylladb/scylladb-6-1-1 by Tim Koopmans
3. Select "Edit"
4. On "Step 1" press "Next"
5. Wait for few minutes for terminal appear on the "Step 2"
6. Run `cd eduard-scylla-code-samples/scylla-code-samples`
7. Run `git pull`
8. Press "Save" button (in the top right corner)

### Important note

There is a folder `~/instruqt-examples` that's used for all of the Instruqt tracks.

This is actually a shortcut (more specifically, a symbolic link) that points to:
`~/eduard-scylla-code-samples/scylla-code-samples/instruqt-examples`

So, when the `~/eduard-scylla-code-samples/scylla-code-samples/instruqt-examples`
gets updated by running `git pull`, the `~/instruqt-examples` folder gets updated, too!

This was done to improve terminal readability for learners going through the Instruqt tracks.
