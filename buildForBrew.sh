targetDir="$1"

export CODE_SIGNING_REQUIRED=NO && xcodebuild clean build -project applesimutils/applesimutils.xcodeproj -scheme applesimutils -configuration Release -derivedDataPath ./build BUILD_DIR=../build/Build/Products
mkdir -p "$targetDir"/bin
cp build/Build/Products/Release/applesimutils "$targetDir"/bin