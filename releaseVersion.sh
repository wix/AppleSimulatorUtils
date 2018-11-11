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

if [[ -n $(git log --branches --not --remotes) ]]; then
	echo "Pushing commits to git"
	git push
fi

echo "Creating commit for version"

VERSION="$1"

echo "\"$VERSION\"" > applesimutils/applesimutils/version.h

echo "Cleaning up"

git clean -xdf

echo "Creating release notes"

RELEASE_NOTES_FILE=._tmp_release_notes.md

touch "${RELEASE_NOTES_FILE}"
open -Wn "${RELEASE_NOTES_FILE}"

if ! [ -s "${RELEASE_NOTES_FILE}" ]; then
	echo -e >&2 "\033[1;31mNo release notes provided, aborting.\033[0m"
	rm -f "${RELEASE_NOTES_FILE}"
	exit -1
fi

echo "Creating a compressed tarball of the source"

tar --exclude=".git" --exclude "._tmp_release_notes.md" --exclude=".github" --exclude="homebrew-brew" -cvzf "AppleSimulatorUtils-$1.tar.gz" .

echo "Updating brew repository with latest tarball and update applesimutils.rb"

cd homebrew-brew

git checkout master
git fetch
git pull --rebase
mv "../AppleSimulatorUtils-$1.tar.gz" .
sed -i '' -e 's/url .*/url '"'https:\/\/raw.githubusercontent.com\/wix\/homebrew-brew\/master\/AppleSimulatorUtils-$1.tar.gz'"'/g' applesimutils.rb
sed -i '' -e 's/sha256 .*/sha256 '"'"$(shasum -b -a 256 AppleSimulatorUtils-$1.tar.gz | awk '{ print $1 }')"'"'/g' applesimutils.rb
git add -A
git commit -m "$1"
git push

echo "Pushing submodule change"

cd ..

git add -A
git commit -m "$1"
git tag "$1"

git push
git push --tags

echo "Creating release"

#Escape user input in markdown to valid JSON string using PHP 🤦‍♂️ (https://stackoverflow.com/a/13466143/983912)
RELEASENOTESCONTENTS=$(printf '%s' "$(<"${RELEASE_NOTES_FILE}")" | php -r 'echo json_encode(file_get_contents("php://stdin"));')
API_JSON=$(printf '{"tag_name": "%s","target_commitish": "master", "name": "%s", "body": %s, "draft": false, "prerelease": false}' "$VERSION" "$VERSION" "$RELEASENOTESCONTENTS")
RELEASE_ID=$(curl -s --data "$API_JSON" https://api.github.com/repos/wix/AppleSimulatorUtils/releases?access_token=${GITHUB_RELEASES_TOKEN} | jq ".id")

rm -f "${RELEASE_NOTES_FILE}"