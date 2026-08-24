#!/bin/bash
cd "/Users/aidan/Documents/XCode/Checklist Manifesto v2"
echo "Testing build..."
xcodebuild -scheme "Checklist Manifesto v2" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 15" clean build 2>&1 | tee build_output.txt | grep -E "(Succeeded|Failed|error:|warning:)" 
echo "Build test completed. Check build_output.txt for full details."