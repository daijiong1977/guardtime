# GuardTime App - Complete Setup Guide

## Overview
This document provides a complete guide to rebuilding the GuardTime iOS app with Family Controls and DeviceActivity Report Extension. This app displays real family member names from Family Sharing and their Screen Time data.

**Last Updated:** October 30, 2025  
**iOS Deployment Target:** 16.0+  
**Key Technologies:** Family Controls, DeviceActivity, App Extensions

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Apple Developer Portal Setup](#apple-developer-portal-setup)
3. [Project Structure](#project-structure)
4. [Critical Configuration Details](#critical-configuration-details)
5. [Common Issues and Solutions](#common-issues-and-solutions)
6. [Building and Running](#building-and-running)

---

## Prerequisites

### Required Tools
- **Xcode 15.0+**
- **XcodeGen** - Install via Homebrew:
  ```bash
  brew install xcodegen
  ```
- **macOS 13.0+**
- **Apple Developer Account** with Family Controls entitlement approval

### Required Apple Developer Setup
1. **Family Controls Entitlement Approval**
   - Must request from Apple at: https://developer.apple.com/contact/request/family-controls-distribution-entitlement
   - This is a restricted capability that requires explicit approval
   - Approval is tied to a specific App ID

2. **Development Team**
   - Team ID: `W6BCH2M54V`
   - Account: jiong dai (daedal1977@hotmail.com)

---

## Apple Developer Portal Setup

### CRITICAL: Bundle Identifier Configuration

**The bundle identifier MUST match the App ID that has Family Controls approval.**

In our case:
- **App ID in Portal:** `com.jidai.guardtime` (this has Family Controls capability enabled)
- **Main App Bundle ID:** `com.jidai.guardtime`
- **Extension Bundle ID:** `com.jidai.guardtime.reportextension`

### Step 1: Verify App ID Configuration

1. Go to: https://developer.apple.com/account/resources/identifiers/list
2. Find your App ID: `com.jidai.guardtime`
3. Verify it shows:
   ```
   Platform Support: iOS, visionOS
   Provisioning Support: Development, Ad hoc, App Store Connect
   Entitlement Keys: com.apple.developer.family-controls
   ```
4. **Important:** The "Enabled Capabilities" should show "Family Controls"

### Step 2: Create Certificates

You need Apple Development certificates for testing on devices.

**Option A: Create in Xcode (Easiest)**
1. Xcode → Settings → Accounts
2. Select your Apple ID
3. Click "Manage Certificates..."
4. Click "+" → Select "Apple Development"

**Option B: Create via Portal**
1. Go to: https://developer.apple.com/account/resources/certificates/add
2. Select "Apple Development" under iOS
3. Generate a CSR (Certificate Signing Request):
   ```bash
   # This creates CSR files on your Desktop
   mkdir -p ~/Desktop/GuardTimeCertificates
   cd ~/Desktop/GuardTimeCertificates
   
   openssl req -new -newkey rsa:2048 -nodes \
     -keyout GuardTimeDevelopment.key \
     -out GuardTimeDevelopment.certSigningRequest \
     -subj "/emailAddress=daedal1977@hotmail.com/CN=GuardTime Development/C=US"
   ```
4. Upload the CSR file and download the certificate
5. Double-click the .cer file to install in Keychain

### Step 3: Create Provisioning Profiles (CRITICAL)

**For Main App:**
1. Go to: https://developer.apple.com/account/resources/profiles/add
2. Select **"iOS App Development"** → Continue
3. **Select App ID:** `com.jidai.guardtime` → Continue
4. **Select your certificate** (must match what's on your Mac) → Continue
5. Select your test devices → Continue
6. Name it clearly (e.g., "GuardTime Development") → Generate
7. **Download and double-click** the .mobileprovision file to install

**For App Extension (if needed for manual signing):**
1. Create another profile with App ID: `com.jidai.guardtime.reportextension`
2. Follow same steps as above

### Step 4: Verify Certificate Match (CRITICAL STEP)

**This is where most provisioning errors occur!**

The certificate in your provisioning profile MUST match a certificate installed on your Mac.

To check installed certificates:
```bash
security find-identity -v -p codesigning
```

To check what's in a provisioning profile:
```bash
security cms -D -i ~/Library/MobileDevice/Provisioning\ Profiles/<profile-name>.mobileprovision
```

**If they don't match:** Download the certificate from the Apple Developer Portal and double-click to install it.

---

## Project Structure

```
GuardTimeApp/
├── project.yml                           # XcodeGen configuration (CRITICAL FILE)
├── GuardTimeApp/                         # Main app target
│   ├── GuardTimeApp.swift               # App entry point
│   ├── ContentView.swift                # Main UI
│   ├── ScreenTimeReportView.swift       # Shows DeviceActivityReport
│   ├── GuardTimeApp.entitlements        # Main app entitlements
│   ├── Info.plist
│   └── Services/
│       └── ScreenTimeService.swift      # Family Controls authorization
├── GuardTimeReportExtension/            # Report extension target (REQUIRED)
│   ├── GuardTimeReportExtension.swift   # Extension entry point - accesses DeviceActivityData.User
│   ├── GuardTimeReportExtension.entitlements  # Extension entitlements
│   └── Info.plist                       # Extension Info.plist (CRITICAL CONFIGURATION)
└── GuardTimeApp.xcodeproj/              # Generated by XcodeGen
```

---

## Critical Configuration Details

### 1. Main App Entitlements (`GuardTimeApp/GuardTimeApp.entitlements`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.jidai.guardtime</string>
	</array>
	<key>com.apple.developer.family-controls</key>
	<true/>
</dict>
</plist>
```

**Key Points:**
- Use `com.apple.developer.family-controls` (NOT the .distribution variant)
- The entitlement key must match what's approved in your App ID
- App Groups allow data sharing between app and extension

### 2. Extension Entitlements (`GuardTimeReportExtension/GuardTimeReportExtension.entitlements`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.jidai.guardtime</string>
	</array>
	<key>com.apple.developer.family-controls</key>
	<true/>
</dict>
</plist>
```

**CRITICAL:** The extension MUST have its own entitlements file with Family Controls capability.

### 3. Extension Info.plist (`GuardTimeReportExtension/Info.plist`) - MOST CRITICAL

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>GuardTimeReportExtension</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.deviceactivityui.report-extension</string>
	</dict>
</dict>
</plist>
```

**⚠️ CRITICAL MISTAKE TO AVOID:**

**DO NOT include these keys in NSExtension dictionary:**
- ❌ `NSExtensionPrincipalClass`
- ❌ `NSExtensionMainStoryboard`

If you include these keys, you'll get installation error:
```
Code: 3002
Appex bundle defines either an NSExtensionMainStoryboard or NSExtensionPrincipalClass key, 
which is not allowed for the extension point com.apple.deviceactivityui.report-extension
```

DeviceActivity Report Extensions use a SwiftUI-based scene architecture, NOT a principal class or storyboard.

### 4. Project Configuration (`project.yml`)

```yaml
name: GuardTimeApp
options:
  bundleIdPrefix: com.jidai
  deploymentTarget:
    iOS: 16.0
  generateEmptyDirectories: true
  createIntermediateGroups: true

targets:
  GuardTimeApp:
    type: application
    platform: iOS
    deploymentTarget: 16.0
    sources:
      - GuardTimeApp
    dependencies:
      - target: GuardTimeReportExtension
        embed: true                          # CRITICAL: Must embed the extension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jidai.guardtime
        CODE_SIGN_ENTITLEMENTS: GuardTimeApp/GuardTimeApp.entitlements
        INFOPLIST_FILE: GuardTimeApp/Info.plist
        TARGETED_DEVICE_FAMILY: 1
        SWIFT_VERSION: 5.9
        CODE_SIGN_STYLE: Automatic           # Automatic signing recommended
        DEVELOPMENT_TEAM: W6BCH2M54V
  
  GuardTimeReportExtension:
    type: app-extension                      # CRITICAL: Must be app-extension type
    platform: iOS
    deploymentTarget: 16.0
    sources:
      - GuardTimeReportExtension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jidai.guardtime.reportextension
        CODE_SIGN_ENTITLEMENTS: GuardTimeReportExtension/GuardTimeReportExtension.entitlements
        INFOPLIST_FILE: GuardTimeReportExtension/Info.plist
        TARGETED_DEVICE_FAMILY: 1
        SWIFT_VERSION: 5.9
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: W6BCH2M54V
        SKIP_INSTALL: NO

schemes:
  GuardTimeApp:
    build:
      targets:
        GuardTimeApp: all
        GuardTimeReportExtension: all        # Build extension with main app
    run:
      config: Debug
    profile:
      config: Release
    archive:
      config: Release
```

**Key Points:**
- Extension must have `embed: true` in dependencies
- Only define one scheme (for main app) - extension scheme causes "select app to run" issues
- Use Automatic signing for simplicity (or Manual if you prefer)
- Both targets must have the same `DEVELOPMENT_TEAM`

### 5. Accessing DeviceActivityData.User in Extension

**This is the key to getting family member names!**

In `GuardTimeReportExtension.swift`:

```swift
import SwiftUI
import DeviceActivity

@main
struct GuardTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        ActivityReport { context in
            ActivityReportView(context: context)
        }
    }
}

struct ActivityReport: DeviceActivityReportScene {
    let makeConfiguration: (DeviceActivityResults<DeviceActivityData>) async -> ActivityReportView.Configuration
    
    func configuration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ActivityReportView.Configuration {
        
        var familyMembers: [String] = []
        
        // THIS IS WHERE YOU ACCESS DeviceActivityData.User!
        for await datum in data {
            let user = datum.user  // DeviceActivityData.User
            
            // Extract user information:
            // - user.nameComponents: PersonNameComponents? (the user's actual name)
            // - user.appleID: String? (their Apple ID)
            // - user.role: DeviceActivityData.User.FamilyRole (child, parent, individual, etc.)
            
            if let nameComponents = user.nameComponents {
                let formatter = PersonNameComponentsFormatter()
                let name = formatter.string(from: nameComponents)
                
                let roleString: String
                switch user.role {
                case .child:
                    roleString = "Child"
                case .individual:
                    roleString = "Individual"
                @unknown default:
                    roleString = "Unknown"
                }
                
                familyMembers.append("\(name) (\(roleString))")
            }
            
            // You can also access activity data:
            // - datum.segments: Activity segments with app usage
            // - datum.dateInterval: Time period for the data
        }
        
        return ActivityReportView.Configuration(familyMembers: familyMembers)
    }
}

struct ActivityReportView: View {
    let configuration: Configuration
    
    struct Configuration {
        let familyMembers: [String]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Members")
                .font(.headline)
            
            ForEach(configuration.familyMembers, id: \.self) { member in
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                    Text(member)
                }
            }
        }
        .padding()
    }
}
```

**Key Understanding:**
- `DeviceActivityData.User` is ONLY accessible within the Report Extension
- You cannot access it from the main app code
- The extension runs in a sandboxed environment
- Data flows: System → Extension → UI Display

---

## Common Issues and Solutions

### Issue 1: "Provisioning profile doesn't include signing certificate"

**Cause:** Certificate mismatch between provisioning profile and Mac.

**Solution:**
1. Check certificates on Mac:
   ```bash
   security find-identity -v -p codesigning
   ```
2. Check certificate in provisioning profile:
   ```bash
   security cms -D -i ~/Downloads/YourProfile.mobileprovision | grep -A 20 "DeveloperCertificates"
   ```
3. Download the correct certificate from Apple Developer Portal
4. Double-click to install
5. Re-download provisioning profile if needed

### Issue 2: "Provisioning profile doesn't include Family Controls entitlement"

**Cause:** The App ID in the provisioning profile doesn't have Family Controls capability enabled.

**Solution:**
1. Go to: https://developer.apple.com/account/resources/identifiers/list
2. Click on your App ID
3. Verify "Family Controls" is checked
4. If not, you need to request Family Controls approval from Apple
5. After approval, create a NEW provisioning profile (existing ones won't update automatically)

### Issue 3: Installation Error 3002 - "NSExtensionPrincipalClass not allowed"

**Cause:** Extension Info.plist has keys that aren't allowed for DeviceActivity Report Extensions.

**Solution:**
Remove these keys from the NSExtension dictionary in Info.plist:
- `NSExtensionPrincipalClass`
- `NSExtensionMainStoryboard`

Only keep:
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.deviceactivityui.report-extension</string>
</dict>
```

### Issue 4: "Select an app to run" dialog when running

**Cause:** Xcode is trying to run the extension scheme instead of the main app scheme.

**Solution:**
1. In project.yml, only define a scheme for the main app (not the extension)
2. Regenerate project: `xcodegen generate`
3. In Xcode, select "GuardTimeApp" scheme (not "GuardTimeReportExtension")
4. If extension scheme still appears, close Xcode and reopen

### Issue 5: Blank screen after granting Family Controls permission

**Cause:** `DeviceActivityReport` shows blank if no data is available or extension has errors.

**Solution:**
1. Make sure you're testing on a physical device (not simulator)
2. Ensure your device is part of a Family Sharing group with children
3. Check that Screen Time is enabled on the device
4. Add debug logging to extension to verify it's being called
5. Wait a few seconds - data loading can be asynchronous

### Issue 6: Can't access family member names from main app

**This is by design!**

`DeviceActivityData.User` is ONLY accessible within the Report Extension for privacy reasons. You cannot query family member information directly from the main app code.

The architecture is:
- Main App → Displays `DeviceActivityReport` view
- System → Calls your Report Extension
- Extension → Accesses `DeviceActivityData.User` and returns UI configuration

### Issue 7: "Development Team" empty causing provisioning failure

**Cause:** DEVELOPMENT_TEAM not set in project.yml

**Solution:**
Add to both targets in project.yml:
```yaml
DEVELOPMENT_TEAM: W6BCH2M54V
```

---

## Building and Running

### Step 1: Generate Xcode Project

```bash
cd /path/to/GuardTimeApp
xcodegen generate
```

### Step 2: Open in Xcode

```bash
open GuardTimeApp.xcodeproj
```

### Step 3: Verify Signing Configuration

1. Select the **GuardTimeApp** target
2. Go to **Signing & Capabilities**
3. Verify:
   - Team: Your team (W6BCH2M54V)
   - Signing Certificate: Apple Development
   - Provisioning Profile: (Automatic or your manual profile)
   - Capabilities: Family Controls ✓

4. Select the **GuardTimeReportExtension** target
5. Verify same settings as above

### Step 4: Build and Run

1. Select **GuardTimeApp** scheme (NOT the extension scheme)
2. Select your physical iPhone device
3. Click Run (▶️)
4. Grant Family Controls permission when prompted
5. You should see family member names from Family Sharing!

### Step 5: Testing

**On Device:**
- The app MUST run on a physical device
- The device must be part of a Family Sharing group
- Screen Time must be enabled
- You should see:
  - Your own name
  - Children in your Family Sharing group
  - Their roles (Child, Individual, etc.)

**Common Test Scenarios:**
- If you see only your name: Your device may not be part of a Family Sharing group with children
- If you see blank: Check extension logs, verify permissions granted
- If you see "Choose from Family": This is expected - it's a system picker for selecting which family member to monitor

---

## Architecture Overview

### How DeviceActivityData.User Access Works

```
┌─────────────────┐
│   Main App      │
│  (GuardTimeApp) │
└────────┬────────┘
         │
         │ 1. Displays DeviceActivityReport view
         │    with filter: users: .all
         ▼
┌─────────────────────────┐
│   iOS System            │
│   (DeviceActivity)      │
└────────┬────────────────┘
         │
         │ 2. Calls Report Extension
         │    Passes DeviceActivityResults<DeviceActivityData>
         ▼
┌──────────────────────────┐
│  Report Extension        │
│  (Sandboxed Environment) │
│                          │
│  - Receives data         │
│  - Accesses .user prop   │
│  - Extracts names/IDs    │
│  - Returns UI config     │
└────────┬─────────────────┘
         │
         │ 3. Returns SwiftUI view configuration
         ▼
┌─────────────────┐
│  Displayed in   │
│  Main App UI    │
└─────────────────┘
```

**Key Points:**
- Main app cannot directly access `DeviceActivityData.User`
- Extension is the ONLY place where this data is available
- This is for privacy and security
- Data is sandboxed and processed in the extension
- UI configuration is returned to the main app

### Authorization Flow

```swift
// In main app - Request authorization
let center = AuthorizationCenter.shared
try await center.requestAuthorization(for: .individual)

// Authorization includes:
// - Access to Family Controls data
// - Access to Screen Time information
// - Access to family member data (in extension context)
```

**Authorization Types:**
- `.individual` - Monitor this device (can access family data synced to this device)
- `.child` - Monitor a specific child (requires parent/guardian role)

For accessing family member names, use `.individual` - the family data is synced locally to the device through Family Sharing.

---

## Troubleshooting Checklist

Before asking for help, verify:

- [ ] XcodeGen is installed: `brew list xcodegen`
- [ ] Bundle identifiers match App IDs in Apple Developer Portal
- [ ] App ID has Family Controls capability enabled
- [ ] Certificates are installed on Mac: `security find-identity -v -p codesigning`
- [ ] Provisioning profiles are installed: `ls ~/Library/MobileDevice/Provisioning\ Profiles/`
- [ ] Provisioning profile certificate matches installed certificate
- [ ] Extension Info.plist does NOT have NSExtensionPrincipalClass key
- [ ] Both targets have entitlements files with Family Controls capability
- [ ] DEVELOPMENT_TEAM is set in project.yml for both targets
- [ ] Testing on physical device (not simulator)
- [ ] Device is part of Family Sharing group
- [ ] Screen Time is enabled on device
- [ ] Running GuardTimeApp scheme (not extension scheme)

---

## Quick Rebuild Commands

If you need to rebuild from scratch:

```bash
# 1. Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/GuardTimeApp*

# 2. Regenerate Xcode project
cd /path/to/GuardTimeApp
xcodegen generate

# 3. Open and build
open GuardTimeApp.xcodeproj
```

If you need to update bundle identifier or team:

```bash
# Edit project.yml
nano project.yml

# Update PRODUCT_BUNDLE_IDENTIFIER and DEVELOPMENT_TEAM
# Then regenerate
xcodegen generate
```

---

## Key Takeaways

### What Makes This Work

1. **DeviceActivity Report Extension** - Required to access `DeviceActivityData.User`
2. **Correct Info.plist** - No NSExtensionPrincipalClass for report extensions
3. **Matching Bundle IDs** - Must match App ID with Family Controls approval
4. **Separate Entitlements** - Both app and extension need their own entitlements files
5. **Automatic Signing** - Simplest approach for development
6. **Physical Device** - Family Controls data only available on real devices
7. **Family Sharing** - Device must be part of a Family Sharing group

### What Doesn't Work

- ❌ Accessing `DeviceActivityData.User` from main app code
- ❌ Using FamilyActivityPicker to select family members (it's for apps, not users)
- ❌ Testing on iOS Simulator (Family Controls requires physical device)
- ❌ Including NSExtensionPrincipalClass in report extension Info.plist
- ❌ Creating separate runnable scheme for extension (causes "select app" dialog)

---

## Additional Resources

- **Apple Documentation:** https://developer.apple.com/documentation/deviceactivity
- **DeviceActivityData.User:** https://developer.apple.com/documentation/deviceactivity/deviceactivitydata/user-swift.struct
- **Family Controls Guide:** https://developer.apple.com/documentation/familycontrols
- **Request Family Controls Entitlement:** https://developer.apple.com/contact/request/family-controls-distribution-entitlement

---

## Version History

**v1.0 - October 30, 2025**
- Initial working version
- Supports iOS 16.0+
- Successfully displays family member names from DeviceActivityData.User
- Uses automatic code signing

---

## Support

If you encounter issues:

1. Check the [Troubleshooting Checklist](#troubleshooting-checklist)
2. Review [Common Issues and Solutions](#common-issues-and-solutions)
3. Verify your Apple Developer Portal configuration
4. Check Xcode build logs for specific errors

**Most Common Issue:** Certificate/provisioning profile mismatch - see Issue #1 above.

---

**End of Guide**
