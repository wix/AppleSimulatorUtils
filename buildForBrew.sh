targetDir="$1"

echo "\n\n\033[1;33mIf you see issues while installing applesimutils, make sure to update your Xcode Commandline Tools from System Preferences\033[0m\n\n"

export CODE_SIGNING_REQUIRED=NO && xcodebuild clean build -project applesimutils/applesimutils.xcodeproj -scheme applesimutils -configuration Release -derivedDataPath ./build BUILD_DIR=../build/Build/Products
mkdir -p "$targetDir"/bin
cp build/Build/Products/Release/applesimutils "$targetDir"/bin
