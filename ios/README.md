# GlobalBriefing iOS

Bundle ID: com.addvalue.globalbriefing. Requires iOS 16 or later.

Open GlobalBriefing.xcodeproj in Xcode. Under Signing & Capabilities select your Apple Developer Team. Create the matching app in App Store Connect using this Bundle ID.

Select Any iOS Device (arm64), then Product > Archive. In Organizer select Distribute App > App Store Connect > Upload. After processing, configure TestFlight testers in App Store Connect.

The app displays the hosted RSS briefing and includes native refresh, sharing, loading and connection-error handling. News updates do not require a new iOS build.

An unsigned archive is only a build verification artifact; it cannot be uploaded to TestFlight. Web-focused apps may need additional native functionality to pass Apple's review.
