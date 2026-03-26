# App Store Distribution Checklist

**For: Tråkke v1.3.0 (build 1)**
**Updated: March 26, 2026**
**Scope: Post-build phases before shipping to Apple for review**

---

## Table of Contents

1. [Pre-Upload Technical Verification](#1-pre-upload-technical-verification)
2. [Code Signing and Archive](#2-code-signing-and-archive)
3. [Screenshots](#3-screenshots)
4. [App Preview Videos (Optional)](#4-app-preview-videos-optional)
5. [App Store Connect Metadata](#5-app-store-connect-metadata)
6. [Privacy and Compliance](#6-privacy-and-compliance)
7. [App Review Preparation](#7-app-review-preparation)
8. [TestFlight](#8-testflight)
9. [Release Strategy](#9-release-strategy)
10. [Post-Submission Monitoring](#10-post-submission-monitoring)

---

## 1. Pre-Upload Technical Verification

### Build Configuration (Release)

- [ ] `SWIFT_OPTIMIZATION_LEVEL = -O` (whole-module optimization)
- [ ] `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` (needed for crash symbolication)
- [ ] `STRIP_INSTALLED_PRODUCT = YES`
- [ ] `ENABLE_TESTABILITY = NO`
- [ ] `SWIFT_ACTIVE_COMPILATION_CONDITIONS` does NOT include `DEBUG`
- [ ] No test code, mock data, or debug flags present in Release build

### Info.plist

- [ ] `CFBundleDisplayName` = "Tråkke" (with å)
- [ ] `CFBundleShortVersionString` matches App Store Connect version (1.3.0)
- [ ] `CFBundleVersion` is higher than any previously uploaded build (currently 1)
- [ ] `ITSAppUsesNonExemptEncryption` = `false` (app uses only standard HTTPS)
- [ ] `NSLocationWhenInUseUsageDescription` is present, specific, and in Norwegian
- [ ] `UIRequiredDeviceCapabilities` = `[arm64]` only (do not add `gps` or `location-services`)
- [ ] No unused `NS*UsageDescription` keys (requesting unnecessary permissions = rejection)

### App Icon

- [ ] Single 1024x1024 PNG in asset catalog
- [ ] No alpha channel / no transparency (ITMS-90032 if present)
- [ ] No rounded corners (Apple applies the superellipse mask)
- [ ] sRGB or Display P3 color space

### Privacy Manifest

- [ ] `PrivacyInfo.xcprivacy` exists in app target
- [ ] `NSPrivacyTracking` = `false`
- [ ] `NSPrivacyTrackingDomains` = empty array
- [ ] `NSPrivacyCollectedDataTypes` declares Precise Location (not linked, not tracking, app functionality)
- [ ] `NSPrivacyCollectedDataTypes` declares Coarse Location (not linked, not tracking, app functionality)
- [ ] `NSPrivacyAccessedAPITypes` declares UserDefaults with reason `CA92.1`
- [ ] `NSPrivacyAccessedAPITypes` declares FileTimestamp with reason `C617.1` (used by activity tracking file operations)
- [ ] Run `Product > Generate Privacy Report` on the archive to verify completeness
- [ ] Verify MapLibre, MGRS, GRDB, and other SPM dependencies ship their own privacy manifests

### Performance

- [ ] App launches in under 1 second (test on oldest supported device)
- [ ] No crashes with location permission denied
- [ ] No crashes with no network connection (airplane mode)
- [ ] No crashes with malformed GPX import
- [ ] SwiftData ModelContainer recovery does not crash (test corrupt store scenario)
- [ ] Navigation overlay does not impact map scrolling performance
- [ ] Valhalla route computation handles server timeout gracefully (30 s)
- [ ] Activity tracking does not significantly increase memory footprint during long recording sessions
- [ ] Knowledge pack download does not block the main thread (verify with Instruments)
- [ ] Profile with Instruments: App Launch, Allocations, Energy Diagnostics

### Accessibility

- [ ] All controls have `.accessibilityLabel()` in Norwegian
- [ ] VoiceOver navigation works through all screens including new activity and knowledge views
- [ ] Dynamic Type renders correctly at all sizes (including accessibility sizes)
- [ ] Minimum 44x44 pt touch targets on all interactive elements
- [ ] Color contrast meets WCAG 2.2 AA (4.5:1 normal text, 3:1 large text)
- [ ] `accessibilityReduceMotion` is respected (splash, map controls, menu animations, data reset, SOS morse signal)

### Localization

- [ ] All strings in `Localizable.xcstrings` have `nb` translations
- [ ] No untranslated or placeholder text visible in the app
- [ ] æ, ø, å characters display correctly everywhere
- [ ] Dates/numbers formatted with `nb_NO` locale
- [ ] No text truncation at larger Dynamic Type sizes

---

## 2. Code Signing and Archive

### Certificates and Profiles

- [ ] **Apple Distribution certificate** exists in Keychain (with private key)
- [ ] Signing style is Automatic (Xcode manages profiles)
- [ ] Team ID: `8NW62A7PRA`
- [ ] Bundle ID matches App Store Connect: `no.tazk.trakke`

### Archive

```bash
# Archive via Xcode
Product > Archive (with destination "Any iOS Device (arm64)")

# Or via command line
xcodebuild -project Trakke.xcodeproj \
  -scheme Trakke \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath ./build/Trakke.xcarchive \
  -skipMacroValidation \
  archive
```

### Upload

1. Open **Window > Organizer** in Xcode
2. Select the archive
3. Click **Validate App** first (catches most issues before upload)
4. Click **Distribute App** > **App Store Connect** > **Upload**
5. Wait for processing (15-30 minutes)
6. Check email for processing results

### Common Upload Errors

| Error | Cause | Fix |
|-------|-------|-----|
| ITMS-90032 | App icon has alpha channel | Remove transparency from PNG |
| ITMS-90096 | Bundle ID mismatch | Ensure `no.tazk.trakke` matches ASC |
| ITMS-90174 | Missing privacy manifest in SDK | Update SDK or add manifest |
| ITMS-91061 | Privacy-impacting SDK lacks manifest | Contact SDK provider for update |
| ITMS-90478 | Invalid bundle structure | Remove .DS_Store or stray files |
| ITMS-90189 | Missing provisioning profile | Let Xcode auto-manage or regenerate |

---

## 3. Screenshots

### Required Sizes (iPhone)

Only ONE set is mandatory. The 6.9" display is the primary required size. If provided, all smaller sizes are auto-scaled.

| Display | Devices | Portrait (px) | Required? |
|---------|---------|---------------|-----------|
| **6.9"** | iPhone Air, 17 Pro Max, 16 Pro Max, 16 Plus, 15 Pro Max, 15 Plus, 14 Pro Max | **1260 x 2736** | **YES** (or 6.5") |
| 6.5" | iPhone 14 Plus, 13 Pro Max, 12 Pro Max, 11 Pro Max, XS Max, XR | 1284 x 2778 or 1242 x 2688 | Only if 6.9" not provided |
| 6.3" | iPhone 17 Pro, 17, 16 Pro, 16, 15 Pro, 15, 14 Pro | 1179 x 2556 or 1206 x 2622 | Optional (scaled from 6.5") |
| 6.1" | iPhone 16e, 14, 13, 12, 11 Pro, XS, X | 1170 x 2532 or 1125 x 2436 | Optional (scaled from 6.5") |
| 5.5" | iPhone 8 Plus, 7 Plus, 6S Plus | 1242 x 2208 | Optional (scaled from 6.1") |

**For Tråkke (iOS 26.0+):** Provide the **6.9"** screenshots (1260 x 2736). Optionally add 6.3" for pixel-perfect display on iPhone 17/16 Pro.

### File Requirements

- Format: PNG or JPEG (PNG preferred)
- No alpha channel / no transparency
- Color space: sRGB or Display P3
- Quantity: 1-10 per device size per localization
- Orientation: Portrait (standard for phone apps)

### Clean Status Bar

Before capturing, override the simulator status bar:

```bash
# Get your simulator device ID
xcrun simctl list devices | grep "iPhone"

# Override status bar to Apple-standard appearance
xcrun simctl status_bar <DEVICE_ID> override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularMode active \
  --cellularBars 4 \
  --wifiBars 3 \
  --operatorName ""

# Capture screenshot
xcrun simctl io <DEVICE_ID> screenshot ~/Desktop/screenshot_01.png

# Reset status bar when done
xcrun simctl status_bar <DEVICE_ID> clear
```

**Why 9:41?** Apple uses this time in all marketing materials (the original iPhone was unveiled at 9:41 AM). Using it makes screenshots look polished and "Apple-like."

### Dynamic Island

The Dynamic Island does NOT appear in simulator screenshots. The simulator renders a clean status bar area. No special handling needed.

### Screenshot Content Strategy

Recommended order (first 3 are visible without scrolling on the product page):

1. **Hero shot**: Map in full glory -- scenic Norwegian location (Jotunheimen, Lofoten) with hiking trail visible
2. **Core feature**: Route with elevation profile
3. **Discovery**: POI layers enabled (tilfluktsrom, kulturminner, etc.)
4. **Weather**: Weather sheet open showing temperature, sunrise/sunset daylight card, and water temperature
5. **Activity**: Activity recording in progress (GPS track)
6. **Knowledge**: Knowledge article open (survival tips or outdoor skills)
7. **Layers**: Map layer switching (topo/grayscale/toporaster) and overlays (hillshading, naturvernomrader, naturskog sub-picker)
8. **Emergency**: Emergency sheet showing coordinates in multiple formats

### Design Tips

- **Full-bleed screenshots** work well for map apps (the Kartverket maps are visually striking)
- **Short text overlays** in Norwegian above or below the screenshot area are optional but effective
- **No device frames needed** for initial submission (Apple's product page adds context)
- Top apps trend toward clean, full-bleed screenshots without device frames
- Keep visual style consistent across all screenshots (same color accents, font)

### Automation (Optional)

```bash
#!/bin/bash
# Simple screenshot capture script
DEVICE="<DEVICE_ID>"
DIR="$HOME/Desktop/TrakkeScreenshots"
mkdir -p "$DIR"

xcrun simctl boot "$DEVICE"
xcrun simctl status_bar "$DEVICE" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --operatorName ""

# Install and launch in screenshot mode
xcrun simctl install "$DEVICE" path/to/Trakke.app
xcrun simctl launch "$DEVICE" no.tazk.trakke

sleep 3
xcrun simctl io "$DEVICE" screenshot "$DIR/01_map.png"
# Navigate to next screen, capture, repeat...

xcrun simctl shutdown "$DEVICE"
```

For full automation, use **Fastlane Snapshot** with UI tests (see Sources).

---

## 4. App Preview Videos (Optional)

Not required for launch, but highly effective for map apps.

### Specifications

| Property | Requirement |
|----------|-------------|
| Duration | 15-30 seconds |
| Frame rate | 30 fps |
| Format | H.264 (.mov/.mp4/.m4v) or ProRes 422 HQ (.mov) |
| Portrait resolution (6.9") | 886 x 1920 |
| File size | Max 500 MB |
| Audio | Optional. Stereo, 256kbps AAC, 44.1/48 kHz |
| Max count | 3 per device size per localization |
| Poster frame | Defaults to 5 seconds in |

### Recording from Simulator

```bash
# Start recording (Ctrl+C to stop)
xcrun simctl io <DEVICE_ID> recordVideo --codec h264 --force preview.mp4
```

### Suggested Content (20 seconds)

- 0-3s: App opens to map view
- 3-8s: Pan/zoom over scenic Norwegian terrain
- 8-13s: Toggle POI layer, shelters appear
- 13-18s: Open route, scroll elevation profile
- 18-20s: Text card "Tråkke -- din turkamerat"

---

## 5. App Store Connect Metadata

### App-Level Information

| Field | Limit | Value for Tråkke |
|-------|-------|------------------|
| **Name** | 2-30 chars | Trakke |
| **Subtitle** | 30 chars | e.g., "Norske turkart fra Kartverket" |
| **Bundle ID** | Fixed after first upload | no.tazk.trakke |
| **SKU** | Your internal reference | e.g., trakke-ios-001 |
| **Primary Language** | -- | Norwegian Bokmal (nb) |
| **Primary Category** | -- | Navigation |
| **Secondary Category** | -- | Travel |
| **Copyright** | Free text | 2026 Tazk |
| **Content Rights** | Declaration | Yes (third-party content: Kartverket, MET, OSM, etc.) |

### Version-Level Information

| Field | Limit | Localizable | Notes |
|-------|-------|-------------|-------|
| **Description** | 4,000 chars | Yes | Plain text only. First ~170 chars visible before "More" tap |
| **Keywords** | 100 bytes | Yes | Comma-separated, no spaces after commas |
| **Promotional Text** | 170 chars | Yes | Can change anytime without new submission |
| **What's New** | 4,000 chars | Yes | Not available for first version |
| **Support URL** | URL | Yes | Must lead to real contact info |
| **Marketing URL** | URL | Yes | Optional |
| **Privacy Policy URL** | URL | Yes | **MANDATORY for iOS apps** |
| **Review Contact** | Name, email, phone | No | Required |
| **Review Notes** | 4,000 bytes | No | Critical for Norwegian-language apps |

### Keywords Strategy

- Do NOT repeat the app name or developer name (Apple indexes those automatically)
- Use singular forms (Apple matches plural automatically)
- No spaces after commas (saves bytes)
- Norwegian characters (æ, ø, å) use multiple bytes in UTF-8 -- count bytes, not characters

**Suggested Norwegian keywords (v1.3.0):**
```
turkart,friluftsliv,topo,kartverket,tur,fjell,vandring,gps,rute,offline,kart,natur,skog,topptur,tilfluktsrom,kulturminne,gpx,veipunkt,overlevelse,aktivitet,soloppgang,vanntemperatur
```
(Verify total is under 100 bytes before saving)

### Age Rating

Answer "None" to all categories. Expected result: **4+** globally. Tråkke has no objectionable content, no ads, no in-app purchases, no user-generated content, no AI/chatbot features.

### Pricing

- Price: Free (kr 0)
- Base country: Norway
- Consider initially limiting availability to **Norway only** (maps and language are Norway-specific), expand later

### DSA (Digital Services Act) -- EU Requirement

- Declare trader/non-trader status
- If trader: provide identification info (displayed on product page to EU consumers)

---

## 6. Privacy and Compliance

### Privacy Policy URL (Mandatory)

The privacy policy must be:
- Hosted at a publicly accessible URL (not behind authentication)
- Available in Norwegian (the app's primary language)
- Permanently accessible (Apple checks periodically; a 404 can trigger removal)

Content in `PERSONVERN.md` is comprehensive. It needs to be hosted at a stable URL (e.g., `https://tazk.no/personvern` or GitHub Pages).

### App Privacy Details (Nutrition Labels)

Declare in App Store Connect:

| Data Type | Collected | Linked to Identity | Used for Tracking | Purpose |
|-----------|-----------|-------------------|-------------------|---------|
| Precise Location | Yes | No | No | App Functionality |

**Do NOT over-declare:**
- Search queries are transient (not "Search History")
- No user identifiers are collected
- No diagnostics/analytics are collected
- Activity tracks are stored on-device only and not transmitted

### Privacy Manifest (PrivacyInfo.xcprivacy)

Required since Spring 2024. Must declare:

| Category | Your App | Dependencies |
|----------|----------|--------------|
| File timestamp APIs | Yes (C617.1) -- activity tracking file operations | MapLibre: Yes (C617.1) |
| System boot time APIs | No | MapLibre: Yes (35F9.1) |
| Disk space APIs | No | No |
| Active keyboards APIs | No | No |
| User defaults APIs | Yes (CA92.1) | MapLibre: Yes (CA92.1) |

**Note:** CoreLocation and Network framework are NOT Required Reason APIs. They use separate permission mechanisms.

### Export Compliance

`ITSAppUsesNonExemptEncryption = false` is correct. The app uses only standard HTTPS via URLSession, which qualifies for the mass-market encryption exemption.

### GDPR (Norway/EEA)

Tråkke's architecture is GDPR-friendly by design:
- No accounts, no tracking, no analytics, no ads
- All data on-device
- All external APIs are Norwegian/EU government services
- Privacy policy covers legal basis (legitimate interest + consent for location)
- Users can delete all data by deleting the app
- Routes exportable as GPX (data portability)
- In-app "Slett alle data" function in Preferences (GDPR Art. 17 right to erasure) -- also deletes activity records and downloaded knowledge packs

### Data Source Attribution

Required attributions that must be visible somewhere in the app:

| Source | License | Attribution Required |
|--------|---------|---------------------|
| Kartverket | NLOD 2.0 | "(c) Kartverket" on map views |
| MET Norway (Locationforecast) | CC BY 4.0 | Credit near weather display |
| MET Norway (Oceanforecast 2.0) | CC BY 4.0 | Credit near water temperature display |
| Yr/NRK | CC BY 4.0 | Credit for weather symbols |
| Havvarsel-Frost | CC BY 4.0 | Credit near bathing spot temperatures |
| OpenStreetMap | ODbL | "(c) OpenStreetMap contributors" for bundled POI |
| DSB | NLOD | Recommended in credits |
| Riksantikvaren | NLOD | Recommended in credits |
| Miljodirektoratet | NLOD 2.0 | Recommended in credits |
| FOSSGIS / Valhalla | ODbL / MIT | Recommended in credits |

---

## 7. App Review Preparation

### Top Rejection Reasons (2025-2026)

| # | Guideline | Risk for Tråkke | Prevention |
|---|-----------|-----------------|------------|
| 1 | **2.1 -- App Completeness** | Medium | Test Release build on device, test offline, test location denied |
| 2 | **4.0 -- Minimum Functionality** | Low | Substantial unique value with Kartverket maps |
| 3 | **2.3 -- Accurate Metadata** | Medium | Screenshots must match actual app UI |
| 4 | **5.1.1 -- Data Collection** | High | Privacy Policy URL mandatory; Nutrition Labels must be accurate |
| 5 | **5.1.2 -- Data Use/Sharing** | Medium | Disclose location sent to Kartverket, MET, Geonorge |
| 6 | **ITMS-91061 -- Privacy Manifest** | Medium | Verify all SDKs include manifests |

### Guideline 5.2.5 -- Apple Maps

Tråkke uses MapLibre + Kartverket instead of Apple Maps. This is justified because Kartverket provides detailed Norwegian terrain data (contour lines, trails, shelters) not available in Apple Maps. Explain this in Review Notes.

### Reviewer Notes Template

```
LANGUAGE: Trakke (displayed as "Tråkke" with Norwegian å) is entirely in
Norwegian (Bokmal). All UI text, menus, and descriptions are in Norwegian.

MAPS: The app uses Kartverket (Norwegian Mapping Authority) topographic
maps via MapLibre, not Apple Maps. This is intentional -- Kartverket
provides detailed Norwegian terrain data (contour lines, trails, shelters)
essential for outdoor activities that is not available in Apple Maps.

TESTING LOCATION: The maps only cover Norway. If testing from outside
Norway, please set the simulator location to:
  Oslo: 59.9139, 10.7522
  Bergen: 60.3913, 5.3221
  Trondheim: 63.4305, 10.3951

KEY FEATURES TO TEST:
1. Map view: Scroll and zoom the map. Toggle between Topo, Grayscale, and
   Toporaster base layers via the preferences icon (top-right).
2. Search: Tap the search icon and type "Galdhopiggen" (Norway's highest
   mountain).
3. Routes: Long-press on the map to add route points. The app calculates
   elevation profiles.
4. POI layers: Enable point-of-interest categories (shelters, caves, etc.)
   from the layer picker.
5. GPX: Import/export routes as GPX files via the share sheet.
6. Offline: Download a map area for offline use from the preferences menu.
7. Weather: Weather data appears for the current map center location
   (requires network). The weather sheet includes a sunrise/sunset daylight
   card and water temperature (ocean forecast + bathing spots where
   available).
8. Navigation: Tap a point on the map, choose "Navigate here". Test both
   computed route (requires network, uses Valhalla routing) and compass
   bearing mode (works offline).
9. Activity tracking: Tap the activity button to start recording a GPS hike.
   Stop and save the activity. Saved activities are viewable in the activity
   list.
10. Knowledge articles: Open the "More" hub sheet and navigate to the
    knowledge section. Browse bundled survival articles. Download an
    additional knowledge pack (requires network).
11. Emergency sheet: Open via the emergency button. The sheet has two tabs:
    "Koordinater" (displays current location in multiple coordinate formats
    including decimal, DMS, and MGRS) and "SOS-signal" (Morse code torch
    signalling).
12. More hub: Open the "More" sheet to navigate to all secondary features
    (knowledge, activity history, settings).
13. Data deletion: In Settings > "Slett alle data" deletes all user data
    (routes, waypoints, offline maps, activities, downloaded knowledge packs)
    and resets preferences (GDPR Art. 17).

LOCATION PERMISSION: The app works without location permission. Location
is only used to show the user's position on the map, fetch local weather,
and record activity tracks. A pre-explanation screen is shown before the
iOS permission dialog.

NO ACCOUNTS: No user accounts, no login, no in-app purchases, no tracking.

PRIVACY: All data is stored locally on-device. External API calls go only
to Norwegian government services (Kartverket, MET Norway, DSB,
Riksantikvaren) within the EU/EEA.
```

### Pre-Submission Testing Checklist

- [ ] Test on **physical device** (not just simulator)
- [ ] Test the **archived Release build** (not Debug)
- [ ] Test **first-launch experience** from clean install
- [ ] Test with **location permission denied** -- app must not crash
- [ ] Test with **airplane mode** -- graceful degradation
- [ ] Test from a **non-Norwegian simulated location** (e.g., Cupertino) -- blank map tiles must not crash
- [ ] Test **GPX import** with corrupt, empty, and large files
- [ ] Test all external APIs reachable (Kartverket, MET, DSB, etc.)
- [ ] Verify **Kartverket attribution** "(c) Kartverket" is visible on map
- [ ] Verify **OSM attribution** visible for bundled POI data
- [ ] Test **navigation** (computed route + compass mode) -- route computes, off-track detection works
- [ ] Test **"Slett alle data"** in Preferences -- all routes, waypoints, offline maps, activities, downloaded knowledge packs, and POI cache deleted
- [ ] Test **SwiftData corruption recovery** -- corrupt store is rebuilt without crash
- [ ] Test **activity recording** start, stop, and save -- activity appears in history list
- [ ] Test **knowledge pack download** and offline article viewing -- articles readable with no network
- [ ] Test **water temperature display** in weather sheet (ocean forecast card and bathing spot data)
- [ ] Test **emergency coordinates display** in multiple formats (decimal, DMS, MGRS) when location is available and denied
- [ ] Test **SOS morse signal** activation and deactivation (torch flashing pattern starts and stops correctly)
- [ ] Test **"More" sheet** navigation to all sub-destinations (knowledge, activity, settings)
- [ ] Test **toporaster base layer** -- tiles load and display correctly
- [ ] Test **naturskog sub-picker** -- switching between the three naturskog layers updates the map overlay

---

## 8. TestFlight

### Internal vs External Testing

| Aspect | Internal | External |
|--------|----------|----------|
| Testers | Up to 100 (ASC users) | Up to 10,000 |
| Beta App Review | Not required | Required (first build per version) |
| Available | Immediately after processing | After beta review (24-48 hours) |
| Build expiry | 90 days | 90 days |

### Key Points

- Each upload needs a unique `CFBundleVersion` (build number)
- You cannot re-upload the same version + build combination
- Beta review is lighter than full review but checks for crashes, privacy, major violations
- TestFlight automatically collects crash reports
- Export compliance: handled by `ITSAppUsesNonExemptEncryption = false`

### Recommended Flow

1. Upload build via Xcode Organizer
2. Wait for processing (15-30 min)
3. Internal test first (your own devices)
4. If stable, enable external testing
5. Monitor crash reports in Xcode Organizer and App Store Connect
6. When satisfied, submit the same build for App Store review

---

## 9. Release Strategy

### Release Options

| Option | Description | When to Use |
|--------|-------------|-------------|
| **Manual** | "Pending Developer Release" after approval. You click release. | First release (control launch timing) |
| **Automatic** | Goes live immediately after approval | When timing doesn't matter |
| **Scheduled** | Auto-releases after approval, not before a specific date | Coordinated launches |

### Phased Release (Updates Only)

| Day | Users | Cumulative |
|-----|-------|------------|
| 1 | 1% | 1% |
| 2 | 2% | 3% |
| 3 | 5% | 8% |
| 4 | 10% | 18% |
| 5 | 20% | 38% |
| 6 | 50% | 88% |
| 7 | 100% | 100% |

- Can pause for up to 30 days total
- Can release to all users at any time
- Users can always manually download from the App Store

### Recommendation for Tråkke

- **v1.3.0:** Use **phased release** (this is an update -- phased rollout catches regressions early; pause if crash-free rate drops below 99.5%)
- **1.3.x:** Security fixes only
- **1.2.x:** End of life

### Supported Versions

| Version | Support level |
|---------|--------------|
| 1.3.x | Current release |
| 1.2.x | Security fixes only |
| 1.1.x | End of life |

---

## 10. Post-Submission Monitoring

### Review Timeline

- Average review time: 24-48 hours (can vary)
- Complex apps or first submissions may take longer
- If rejected: fix the issue, increment build number, resubmit

### After Approval

- [ ] Verify the app appears correctly on the App Store
- [ ] Check screenshots display properly on all device sizes
- [ ] Verify privacy policy URL is accessible
- [ ] Test downloading from the App Store on a test device
- [ ] Monitor crash reports in Xcode Organizer
- [ ] Monitor customer reviews and respond promptly
- [ ] Set up App Analytics in App Store Connect

### Accessibility Nutrition Labels (New 2025)

Currently voluntary but becoming required. Evaluate and declare support for:
- VoiceOver
- Voice Control
- Larger Text
- Sufficient Contrast
- Differentiate Without Color
- Reduced Motion

Not applicable for Tråkke: Dark Interface (light mode only), Captions, Audio Descriptions.

---

## Quick Reference: Action Items Before Submission

### Must Do

1. **Host privacy policy** at a public URL (PERSONVERN.md content is ready)
2. **Host support page** at a public URL with contact info
3. **Create App Store Connect record** with all metadata (name, description, keywords, screenshots)
4. **Capture screenshots** for 6.9" iPhone display in Norwegian locale
5. **Fill in App Privacy Details** in ASC (Precise Location, not linked, not tracking)
6. **Complete age rating questionnaire** (all "None" = 4+ rating)
7. **Declare content rights** (confirm rights to Kartverket, OSM, MET, Havvarsel-Frost data)
8. **Write reviewer notes** in English explaining the Norwegian-language app and new v1.3.0 features
9. **Upload build** via Xcode, wait for processing, submit for review

### Should Do

10. **TestFlight** internal test of the archived Release build on physical device
11. **Generate Privacy Report** (Product > Generate Privacy Report) and verify
12. **Run Accessibility Inspector** audit on all screens including new activity and knowledge views
13. **Test from non-Norwegian location** to ensure no crashes on blank tiles
14. **Declare DSA trader/non-trader status** for EU distribution

### Nice to Have

15. Create an app preview video (15-30 seconds) -- consider showing activity recording and knowledge browsing
16. Add 6.3" screenshots for pixel-perfect display on iPhone 17/16 Pro
17. Set up Fastlane for automated screenshot capture
18. Evaluate and declare Accessibility Nutrition Labels

---

## Sources

- [Screenshot Specifications -- Apple Developer](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [App Preview Specifications -- Apple Developer](https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications/)
- [App Store Review Guidelines -- Apple Developer](https://developer.apple.com/app-store/review/guidelines/)
- [Privacy Manifest Files -- Apple Developer](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Adding a Privacy Manifest -- Apple Developer](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [Privacy Updates for App Store Submissions -- Apple Developer](https://developer.apple.com/news/?id=3d8a9yyh)
- [Required, Localizable, and Editable Properties -- Apple Developer](https://developer.apple.com/help/app-store-connect/reference/required-localizable-and-editable-properties/)
- [Platform Version Information -- Apple Developer](https://developer.apple.com/help/app-store-connect/reference/platform-version-information/)
- [Upload App Previews and Screenshots -- Apple Developer](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)
- [Set an App Age Rating -- Apple Developer](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)
- [Manage App Privacy -- Apple Developer](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Choose a Build to Submit -- Apple Developer](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit/)
- [Submit an App for Review -- Apple Developer](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/)
- [Release a Version Update in Phases -- Apple Developer](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/)
- [Version Release Options -- Apple Developer](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option/)
- [Accessibility Nutrition Labels -- Apple Developer](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)
- [App Tags -- Apple Developer](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-tags/)
- [Export Compliance Overview -- Apple Developer](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [Set a Price -- Apple Developer](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/)
- [App Icons -- Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Accessibility -- Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [App Store Product Page -- Apple Developer](https://developer.apple.com/app-store/product-page/)
- [Beta Testing with TestFlight -- Apple Developer](https://developer.apple.com/testflight/)
- [Fastlane Snapshot Documentation](https://docs.fastlane.tools/actions/snapshot/)
- [Preparing Your App for Distribution -- Apple Developer](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)
- [Complying with Encryption Export Regulations -- Apple Developer](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
