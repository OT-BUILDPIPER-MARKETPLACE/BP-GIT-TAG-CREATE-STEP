# BP-GIT-TAG-CREATE-STEP

This step will help in the creation of the repository's git tag.

## Setup
* Clone the code available at [BP-GIT-TAG-CREATE-STEP](https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-GIT-TAG-CREATE-STEP.git)

```
git clone https://github.com/OT-BUILDPIPER-MARKETPLACE/BP-GIT-TAG-CREATE-STEP.git
```
* Build the docker image
```
git submodule init
git submodule update
docker build -t ot/git-tag-create:0.1 .

git-tag-create:0.1
git-tag-create:ssh-0.1