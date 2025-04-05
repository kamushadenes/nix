{
  config,
  inputs,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  age.secrets = {
    "servers.json.age" = {
      file = ./resources/mcphub/servers.json.age;
      path = "${config.xdg.configHome}/mcphub/servers.json";
    };
  };

  home.packages = with pkgs-unstable; [
    # AI
    inputs.mcp-hub.packages."${system}".default
  ];
}
