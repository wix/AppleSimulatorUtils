#!/bin/bash
set -e

if [ "$#" -ne 1 ]; then
	echo >&2 "Illegal number of parameters"
	echo >&2 "releaseVersion.sh <version>"
	exit -1
fi

if [[ -n $(git status --porcelain) ]]; then
	echo >&2 "Cannot release version because there are unstaged changes:"
	git status --short
	exit -2
fi

if [[ -n $(git tag --contains $(git rev-parse --verify HEAD)) ]]; then
	echo >&2 "The latest commit is already contained in the following releases:"
	git tag --contains $(git rev-parse --verify HEAD)
	exit -3
fi

echo "Creating commit for version"

echo "\"$1\"" > applesimutils/applesimutils/version.h
git add -A
git commit -m $1
git tag $1
git push origin --tags

echo "Cleaning up"

git clean -xdf

echo "Creating a compressed tarball of the source"

tar --exclude=".git" --exclude=".github" --exclude="homebrew-brew" -cvzf "AppleSimulatorUtils-$1.tar.gz" .

echo "Updating brew repository with latest tarball and update applesimutils.rb"

cd homebrew-brew

mv ../AppleSimulatorUtils-$1.tar.gz .
sed -i '' -e 's/url .*/url '"'https:\/\/raw.githubusercontent.com\/wix\/homebrew-brew\/master\/AppleSimulatorUtils-$1.tar.gz'"'/g' applesimutils.rb
sed -i '' -e 's/sha256 .*/sha256 '"'"$(shasum -b -a 256 AppleSimulatorUtils-$1.tar.gz | awk '{ print $1 }')"'"'/g' applesimutils.rb
git add -A
git commit -m $1
git push

# version.h