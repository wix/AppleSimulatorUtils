#!/bin/bash
set -e

### User running this script must have git permission, and have https://cli.github.com/ installed and authenticated.

# Assumes gh is installed and logged in

if [ "$#" -ne 1 ]; then
	echo -e >&2 "\033[1;31mIllegal number of parameters\033[0m"
	echo -e >&2 "\033[1;31mreleaseVersion.sh <version>\033[0m"
	exit -1
fi

if [[ -n $(git status --porcelain) ]]; then
	echo -e >&2 "\033[1;31mCannot release version because there are unstaged changes:\033[0m"
	git status --short
	exit -2
fi

if [[ -n $(git tag --contains $(git rev-parse --verify HEAD)) ]]; then
	echo -e >&2 "\033[1;31mThe latest commit is already contained in the following releases:\033[0m"
	git tag --contains $(git rev-parse --verify HEAD)
	exit -3
fi

if [[ -n $(git log --branches --not --remotes) ]]; then
	echo -e "\033[1;34mPushing commits to git\033[0m"
	git push
fi

echo -e "\033[1;34mCreating release notes\033[0m"

RELEASE_NOTES_FILE=_tmp_release_notes.md

touch "${RELEASE_NOTES_FILE}"
open -Wn "${RELEASE_NOTES_FILE}"

if ! [ -s "${RELEASE_NOTES_FILE}" ]; then
	echo -e >&2 "\033[1;31mNo release notes provided, aborting.\033[0m"
	rm -f "${RELEASE_NOTES_FILE}"
	exit -1
fi

echo -e "\033[1;34mCreating commit for version\033[0m"

VERSION="$1"

echo "\"${VERSION}\"" > applesimutils/applesimutils/version.h

echo -e "\033[1;34mCreating a compressed tarball of the source\033[0m"

SRC_TGZ_FILE="AppleSimulatorUtils-${VERSION}.tar.gz"

mkdir -p build
tar --exclude="releaseVersion.sh" --exclude=".git" --exclude="build" --exclude="bottle" --exclude "_tmp_release_notes.md" --exclude=".github" --exclude="homebrew-brew" -cvzf "build/${SRC_TGZ_FILE}" .

echo -e "\033[1;34mCreating Homebrew bottles"

rm -fr bottle
BOTTLE_DIR="bottle/applesimutils/${VERSION}/"
mkdir -p "${BOTTLE_DIR}"
./buildForBrew.sh "${BOTTLE_DIR}"
pushd .
cd bottle

BOTTLES=( "catalina" "mojave" "high_sierra" "sierra" "big_sur" "arm64_big_sur" )
for BOTTLE in "${BOTTLES[@]}"
do
	BOTTLE_TGZ_FILE="applesimutils-${VERSION}.${BOTTLE}.bottle.tar.gz"
	tar -cvzf "${BOTTLE_TGZ_FILE}" applesimutils
done

popd

echo -e "\033[1;34mUpdating applesimutils.rb with latest hashes\033[0m"

cd homebrew-brew

git checkout master
git fetch
git pull --rebase
sed -i '' -e 's/^\ \ url .*/\ \ url '"'https:\/\/github.com\/wix\/AppleSimulatorUtils\/releases\/download\/${VERSION}\/${SRC_TGZ_FILE}'"'/g' Formula/applesimutils.rb
sed -i '' -e 's/^\ \ \ \ root\_url .*/\ \ \ \ root\_url '"'https:\/\/github.com\/wix\/AppleSimulatorUtils\/releases\/download\/${VERSION}'"'/g' Formula/applesimutils.rb
sed -i '' -e 's/^\ \ sha256 .*/\ \ sha256 '"'"$(shasum -b -a 256 ../build/${SRC_TGZ_FILE} | awk '{ print $1 }')"'"'/g' Formula/applesimutils.rb

for BOTTLE in "${BOTTLES[@]}"
do
	BOTTLE_TGZ_FILE="applesimutils-${VERSION}.${BOTTLE}.bottle.tar.gz"
	sed -i '' -e "s/^    sha256 .* => :${BOTTLE}/    sha256 '$(shasum -b -a 256 ../bottle/${BOTTLE_TGZ_FILE} | awk '{ print $1 }')' => :${BOTTLE}/g" Formula/applesimutils.rb
done

git add -A
git commit -m "Apple Simulator Utils ${VERSION}"
git push

cd ..

echo -e "\033[1;34mPushing changes to AppleSimUtils\033[0m"

git add -A
git commit -m "${VERSION}"
git tag "${VERSION}"

git push
git push --tags

echo -e "\033[1;34mCreating a GitHub release\033[0m"

gh release create --repo wix/AppleSimulatorUtils "$VERSION" --title "$VERSION" --notes-file "${RELEASE_NOTES_FILE}"

echo -e "\033[1;34mUploading attachments to release\033[0m"

gh release upload --repo wix/AppleSimulatorUtils "$VERSION" "build/${SRC_TGZ_FILE}#$(basename ${SRC_TGZ_FILE})"

for BOTTLE in "${BOTTLES[@]}"
do	
	BOTTLE_TGZ_FILE="applesimutils-${VERSION}.${BOTTLE}.bottle.tar.gz"
	gh release upload --repo wix/AppleSimulatorUtils "$VERSION" "bottle/${BOTTLE_TGZ_FILE}#$(basename ${BOTTLE_TGZ_FILE})"
done

rm -fr build
rm -fr bottle
rm -f "${RELEASE_NOTES_FILE}"