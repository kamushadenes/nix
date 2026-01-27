# Custom Lovelace modules for haos
# Modules available in nixpkgs are used directly
# Others will be installed via HACS or packaged incrementally
{ pkgs }:

with pkgs.home-assistant-custom-lovelace-modules;
[
  # From nixpkgs (verified available)
  apexcharts-card     # Advanced charts with ApexCharts
  auto-entities       # Auto-populate entity lists
  bubble-card         # Bubble card UI
  button-card         # Highly customizable buttons
  card-mod            # CSS styling for cards
  mini-graph-card     # Minimalistic graphs
  mini-media-player   # Compact media player
  multiple-entity-row # Multiple entities per row
  mushroom            # Mushroom card collection (main UI framework)
  template-entity-row # Templated entity rows
  vacuum-card         # Vacuum robot control
  weather-card        # Weather display

  # Not in nixpkgs - install via HACS:
  # - atomic-calendar-revive (in nixpkgs but using HACS version)
  # - bar-card
  # - battery-state-card
  # - digital-clock
  # - entity-attributes-card
  # - flexible-horseshoe-card
  # - fold-entity-row
  # - gap-card
  # - gauge-card
  # - hui-element
  # - layout-card
  # - light-entity-card (in nixpkgs)
  # - lovelace-slider-entity-row
  # - more-info-card
  # - numberbox-card
  # - paper-buttons-row
  # - scheduler-card
  # - secondaryinfo-entity-row
  # - slider-button-card
  # - slider-entity-row
  # - stack-in-card
  # - state-switch
  # - tabbed-card
  # - text-divider-row
  # - timer-bar-card
  # - vertical-stack-in-card
]
