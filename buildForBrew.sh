targetDir="$1"

xcodebuild clean build -project applesimutils/applesimutils.xcodeproj -scheme applesimutils -configuration Release -derivedDataPath ./build
mkdir -p "$targetDir"/bin
cp build/Build/Products/Release/applesimutils "$targetDir"/bin