VERSION := VERSION
XCODE_CONFIGURATION := Release
# XCODE_CONFIGURATION := "Debug"
BUILD_DIR = "build/${XCODE_CONFIGURATION}"
BUILD_PRODUCTS = "${BUILD_DIR}/QLStephen Dummy.app" "${BUILD_DIR}/QLStephen.app" "${BUILD_DIR}/QLStephen.qlgenerator"

.PHONY: build install uninstall package clean realclean

build: | clean
	xcodebuild SYMROOT=../build -project QuickLookStephenProject/QuickLookStephen.xcodeproj -configuration "${XCODE_CONFIGURATION}" $(XC_OPTIONS) build -alltargets

$BUILD_PRODUCTS: build

install: $BUILD_PRODUCTS | uninstall
	mkdir -p ~/Applications
	cp -r "${BUILD_DIR}/QLStephen Dummy.app" ~/Applications/
	sudo cp -r "${BUILD_DIR}/QLStephen.app" /Applications/
	cp -r "${BUILD_DIR}/QLStephen.qlgenerator" ~/Library/QuickLook/
	qlmanage -r

# Also cleans up builds and packages because macOS will have probably have
# discovered them and registered them as services.
uninstall: | realclean
	rm -rf ~/Applications/QLStephen\ Dummy.app
	rm -rf ~/Library/QuickLook/QLStephen.qlgenerator
	sudo rm -rf /Applications/QLStephen.app
	/System/Library/CoreServices/pbs -flush

package: $BUILD_PRODUCTS
	rm -rf "package"
	mkdir -p "package/QLStephen-${VERSION}-${XCODE_CONFIGURATION}"
	cp -r ${BUILD_PRODUCTS} "package/QLStephen-${VERSION}-${XCODE_CONFIGURATION}"
	cd "package" && zip -rX "QLStephen-${VERSION}-${XCODE_CONFIGURATION}.zip" "QLStephen-${VERSION}-${XCODE_CONFIGURATION}"
	sha256sum "package/QLStephen-${VERSION}-${XCODE_CONFIGURATION}.zip"

clean:
	@rm -rf ./build
	@rm -rf ~/Library/Developer/Xcode/DerivedData/QuickLookStephen-*

realclean: clean
	@rm -rf ./package
