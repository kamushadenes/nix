{ ... }:

{
  system = {
    defaults = {
      #sharingd = {
      #  DiscoverableMode = "Contacts Only";
      #};
      CustomUserPreferences = {
        # Enable Handoff
        "~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist" = {
          "ActivityAdvertisingAllowed" = true;
          "ActivityReceivingAllowed" = true;
        };
      };
    };
  };
}
