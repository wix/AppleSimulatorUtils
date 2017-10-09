targetDir="$1"

xcodebuild clean build -project applesimutils/applesimutils.xcodeproj -scheme applesimutils -configuration Release -derivedDataPath ./build BUILD_DIR=../build/Build/Products
mkdir -p "$targetDir"/bin
cp applesimutils/Build/Products/Release/applesimutils "$targetDir"/bin
