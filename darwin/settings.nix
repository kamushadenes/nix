{
  config,
  ...
}:
{

  system = {
    primaryUser = config.users.users.kamushadenes.name;
    defaults = {
      NSGlobalDomain = {
        # Use metric units
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        AppleTemperatureUnit = "Celsius";

        # Use a 24-hour clock
        AppleICUForce24HourTime = true;

        # Use a dark menu bar and Dock
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = false;

        # Key repeating
        KeyRepeat = 5;
        InitialKeyRepeat = 30;

        # Click to tap
        "com.apple.mouse.tapBehavior" = 1;

        # Disable force click
        "com.apple.trackpad.forceClick" = false;

        # Hide menubar to use SketchyBar
        _HIHideMenuBar = false;
      };

      # Finder
      finder = {
        CreateDesktop = false;
        # Search the current folder by default
        FXDefaultSearchScope = "SCcf";
        # Show the path bar
        ShowPathbar = true;
      };

      # Clock
      menuExtraClock = {
        Show24Hour = true;
      };

      # Trackpad
      trackpad = {
        ActuationStrength = 1;
        Clicking = true;
        Dragging = false;
        FirstClickThreshold = 1;
        TrackpadRightClick = true;
        TrackpadThreeFingerTapGesture = 2;
      };

      spaces = {
        spans-displays = true;
      };

      CustomUserPreferences = {
        NSGlobalDomain = {
          # Add a context menu item for showing the Web Inspector in web views
          WebKitDeveloperExtras = true;
        };

        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network and USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };

        "com.apple.TV" = {
          # Remove movies and TV shows from the TV app after watching
          automaticallyDeleteVideoAssetsAfterWatching = true;
        };

        "com.apple.finder" = {
          # Remove items from the Trash after 30 days
          FXRemoveOldTrashItems = true;
        };

        "com.apple.Safari" = {
          # Privacy: don’t send search queries to Apple
          UniversalSearchEnabled = false;
          SuppressSearchSuggestions = true;
          # Press Tab to highlight each item on a web page
          WebKitTabToLinksPreferenceKey = true;
          ShowFullURLInSmartSearchField = true;
          # Prevent Safari from opening ‘safe’ files automatically after downloading
          AutoOpenSafeDownloads = false;
          ShowFavoritesBar = false;
          IncludeInternalDebugMenu = true;
          IncludeDevelopMenu = true;
          WebKitDeveloperExtrasEnabledPreferenceKey = true;
          WebContinuousSpellCheckingEnabled = true;
          WebAutomaticSpellingCorrectionEnabled = false;
          AutoFillFromAddressBook = false;
          AutoFillCreditCardData = false;
          AutoFillMiscellaneousForms = false;
          WarnAboutFraudulentWebsites = true;
          WebKitJavaEnabled = false;
          WebKitJavaScriptCanOpenWindowsAutomatically = false;
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks" = true;
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" = false;
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled" = false;
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles" = false;
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically" = false;
        };

        "com.apple.mail" = {
          # Disable inline attachments (just show the icons)
          DisableInlineAttachmentViewing = true;
        };

        "com.apple.AdLib" = {
          # Disable Apple personalized advertising
          allowApplePersonalizedAdvertising = false;
        };

        "com.apple.SoftwareUpdate" = {
          AutomaticCheckEnabled = true;
          # Check for software updates daily, not just once per week
          ScheduleFrequency = 1;
          # Download newly available updates in background
          AutomaticDownload = 1;
          # Install System data files & security updates
          CriticalUpdateInstall = 1;
        };

        "com.apple.TimeMachine" = {
          # Do not offer new disks for Time Machine backup
          DoNotOfferNewDisksForBackup = true;
        };

        "com.apple.ImageCapture" = {
          # Prevent Photos from opening automatically when devices are plugged in
          disableHotPlug = true;
        };

        "com.apple.commerce" = {
          # Turn on app auto-update
          AutoUpdate = true;
        };

        # Spotlight privacy settings
        "com.apple.Spotlight" = {
          # Disable clipboard history in Spotlight
          PasteboardHistoryEnabled = false;
          # Disable related content (Apple & partner content) and iPhone apps
          # Empty array disables: "Custom.relatedContents", "System.iphoneApps"
          EnabledPreferenceRules = [ ];
        };

        "com.apple.assistant.support" = {
          # Disable "Help Apple Improve Search" data collection
          "Search Queries Data Sharing Status" = 0;
        };

        "com.apple.widgets" = {
          # Set the widget appearance to full color
          widgetAppearance = 1;
        };

        # Enable iPhone widgets
        "com.apple.chronod" = {
          effectiveRemoteWidgetsEnabled = 1;
          remoteWidgetsEnabled = 1;
        };
      };
    };

    startup = {
      chime = true;
    };
  };
}
