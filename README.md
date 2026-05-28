# morning-briefing

A NixOS service that generates a daily spoken briefing — current weather and today's calendar events — and pushes it to Home Assistant as a text entity. Designed to be read aloud by a Galaxy Watch or TTS automation at wake time.

## How it works

1. Fetches current temperature and today's high/low from [Open-Meteo](https://open-meteo.com/) (no API key required)
2. Pulls today's events from a [Radicale](https://radicale.org/) CalDAV server
3. Composes a natural-language briefing string
4. POSTs it to a Home Assistant `input_text` entity via the REST API

## NixOS Module

Add the flake as an input and import the module:

```nix
# flake.nix
inputs.morning-briefing.url = "github:4rmcyt/morning-briefing";

# NixOS configuration
imports = [ inputs.morning-briefing.nixosModules.default ];

services.morning-briefing = {
  enable = true;
  radicaleUrl = "http://127.0.0.1:5232/user/calendar/";
  haUrl = "http://127.0.0.1:8123/api/states/input_text.morning_briefing_text";
  secretFile = config.sops.secrets.morning-briefing.path;
  latitude = "51.0501";   # defaults to Calgary
  longitude = "-114.0853";
};
```

### Module options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | — | Enable the service |
| `radicaleUrl` | str | — | CalDAV endpoint on your Radicale instance |
| `haUrl` | str | `http://127.0.0.1:8123/api/states/input_text.morning_briefing_text` | Home Assistant REST API state URL |
| `secretFile` | path | — | Environment file with `HA_TOKEN`, `RADICALE_USER`, `RADICALE_PASS` |
| `latitude` | str | `51.0501` | Latitude for weather forecast |
| `longitude` | str | `-114.0853` | Longitude for weather forecast |

### Secret file format

```
HA_TOKEN=your_long_lived_token
RADICALE_USER=username
RADICALE_PASS=password
```

Manage with sops-nix or any secrets manager that produces an environment file.

### Scheduling

The module installs a oneshot systemd service. Wire it to a timer in your host config:

```nix
systemd.timers.morning-briefing = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "*-*-* 06:30:00";
    Persistent = true;
  };
};
```

### Home Assistant side

Create an `input_text` entity and an automation that speaks `{{ states('input_text.morning_briefing_text') }}` via your preferred TTS service when the state changes.

## Standalone usage

```bash
nix run github:4rmcyt/morning-briefing -- # runs with env vars set
```

Or set env vars manually and run `main.py` directly:

```
RADICALE_URL=...  RADICALE_USER=...  RADICALE_PASS=...
HA_URL=...  HA_TOKEN=...
LAT=51.0501  LON=-114.0853
python main.py
```

## CI

GitHub Actions runs on every push to `main`:

- `nix fmt --check` — Nix formatting via nixpkgs-fmt
- `nix flake check` — builds the package and runs flake8 on `main.py`
- `nix build .#default` — full package build

Artifacts are pushed to the [Cachix](https://cachix.org/) binary cache `4rmcyt`.
