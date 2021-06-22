#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TARGET_VERSION="${TARGET_VERSION:-}"

if [[ ! "$TARGET_VERSION" ]]; then
  echo "TARGET_VERSION is not defined"
  exit 1
fi

WORK_DIR=`mktemp -d -p "$DIR"`

# check if tmp dir was created
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

function cleanup {
  cd $DIR
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

cd $WORK_DIR

if git show-ref --verify --quiet "refs/heads/$TARGET_VERSION"; then
  git branch --delete --force $TARGET_VERSION
fi
git checkout -b $TARGET_VERSION

rm -rf $(find . -type f ! -name "*.sh")

git clone -b $TARGET_VERSION https://github.com/jetstack/cert-manager.git
cp ./cert-manager/go.mod $DIR/.
cd ./cert-manager/pkg/apis
cp --parents -r $(find  . -name "*.go") $DIR/.
cd $WORK_DIR && rm -rf cert-manager
cd $DIR

rm -f doc.go
sed -i 's/jetstack\/cert-manager\/pkg\/apis/cert-manager\/api/g' $(find  . -name "*.go")
sed -i 's/jetstack\/cert-manager/cert-manager\/api/g' go.mod
sed -i '/^\/\//d' go.mod
sed -i '/^replace/d' go.mod
sed -i '/\/\/\ indirect$/d' go.mod
go mod tidy
sed -i '/\/\/\ indirect$/d' go.mod
rm go.sum
go mod tidy

git add .
git commit -s -m "API version for $TARGET_VERSION"
git push origin $TARGET_VERSION
