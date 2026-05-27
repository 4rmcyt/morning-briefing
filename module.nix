{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.morning-briefing;

  briefingScript = pkgs.writers.writePython3Bin "morning-briefing"
    {
      libraries = with pkgs.python3Packages; [ caldav requests ];
    }
    (builtins.readFile ./main.py);

in
{
  options.services.morning-briefing = {
    enable = mkEnableOption "Morning Briefing generation service";

    radicaleUrl = mkOption {
      type = types.str;
      description = "The URL endpoint of your Radicale CalDAV server.";
    };

    haUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:8123/api/states/input_text.morning_briefing_text";
      description = "The REST API endpoint for input_text state storage in Home Assistant.";
    };

    secretFile = mkOption {
      type = types.path;
      description = ''
        Path to an environment file containing secrets.
        Expected keys: HA_TOKEN, RADICALE_USER, RADICALE_PASS
      '';
    };

    latitude = mkOption {
      type = types.str;
      default = "51.0501";
      description = "Latitude for weather data forecast.";
    };

    longitude = mkOption {
      type = types.str;
      default = "-114.0853";
      description = "Longitude for weather data forecast.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ briefingScript ];

    systemd.services.morning-briefing = {
      description = "Generate and push morning briefing to Home Assistant";
      after = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${briefingScript}/bin/morning-briefing";
        EnvironmentFile = cfg.secretFile;
      };

      environment = {
        RADICALE_URL = cfg.radicaleUrl;
        HA_URL = cfg.haUrl;
        LAT = cfg.latitude;
        LON = cfg.longitude;
      };
    };
  };
}
