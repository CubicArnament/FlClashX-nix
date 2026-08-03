android_arm64:
	dart ./setup.dart android --arch arm64
android_app:
	dart ./setup.dart android
android_arm64_core:
	dart ./setup.dart android --arch arm64 --out core
linux_arm64:
	dart ./setup.dart linux --arch arm64
linux_amd64:
	dart ./setup.dart linux --arch amd64

cleanLocal:
	rm -rf dist
	rm -rf build
