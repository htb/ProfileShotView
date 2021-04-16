# ProfileShotView

## Publishing

To publish an update to this package, first see the last version number with

    git tag

Then update the version number in the master branch and push like this

    git commit -a -m "Something changed"
    git tag 1.0.1
    git push origin main --tags
