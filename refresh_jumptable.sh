rm $(find ./zig-pkg -maxdepth 1 -name "*velox_sdk*") -r
echo "removed old version. installing new one:"
zig fetch --save "git+https://github.com/skzidev/velox-sdk"
