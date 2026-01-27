# Custom Home Assistant components for haos
# Components available in nixpkgs are used directly
# Others will be installed via HACS or packaged incrementally
{ pkgs }:

with pkgs.home-assistant-custom-components;
[
  # From nixpkgs (verified available)
  alarmo           # Alarm panel with full arming modes
  better_thermostat # Improved thermostat control
  smartir          # IR/RF device control via Broadlink/MQTT/ESPHome
  smartthinq-sensors # LG ThinQ appliance integration
  spook            # Home Assistant toolbox with extra features
  tuya_local       # Local control for Tuya devices (no cloud)

  # Not in nixpkgs - install via HACS:
  # - bermuda            (BLE device tracking)
  # - ble_adv            (BLE advertising)
  # - browser_mod        (Browser integration)
  # - extended_openai_conversation
  # - fontawesome        (Icon pack)
  # - hacs               (Home Assistant Community Store)
  # - icloud3            (iCloud device tracker v3)
  # - ics_calendar       (ICS calendar integration)
  # - lovelace_gen       (Jinja2 in lovelace)
  # - magic_areas        (Area-based automations)
  # - mail_and_packages  (Package tracking)
  # - truenas            (TrueNAS integration)
  # - uconnect           (Fiat/Jeep connected car)
  # - webrtc             (WebRTC camera streaming)
  #
  # SKIPPED per user request:
  # - alexa_media        (too complex, not essential)
]
