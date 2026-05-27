#!/usr/bin/env python3
import os
import datetime
import caldav
import requests
import sys

RADICALE_URL = os.environ.get("RADICALE_URL")
RADICALE_USER = os.environ.get("RADICALE_USER")
RADICALE_PASS = os.environ.get("RADICALE_PASS")
HA_URL = os.environ.get("HA_URL")
HA_TOKEN = os.environ.get("HA_TOKEN")
LAT = os.environ.get("LAT", "51.0501")
LON = os.environ.get("LON", "-114.0853")

def get_calgary_weather():
    url = f"https://api.open-meteo.com/v1/forecast?latitude={LAT}&longitude={LON}&current_weather=true&daily=temperature_2m_max,temperature_2m_min&timezone=auto"
    try:
        res = requests.get(url, timeout=5).json()
        current_temp = int(round(res['current_weather']['temperature']))
        max_temp = int(round(res['daily']['temperature_2m_max']))
        min_temp = int(round(res['daily']['temperature_2m_min']))
        return f"Weather report. Currently it is {current_temp} degrees. Today's high will be {max_temp} and the low will be {min_temp}."
    except Exception as e:
        print(f"Weather API error: {e}", file=sys.stderr)
        return "Unable to fetch current weather data."

def get_today_events():
    if not all([RADICALE_URL, RADICALE_USER, RADICALE_PASS]):
        return "Radicale credentials or URL are missing."
    try:
        client = caldav.DAVClient(url=RADICALE_URL, username=RADICALE_USER, password=RADICALE_PASS)
        calendar = client.principal().calendars()
        now = datetime.datetime.now()
        start_of_day = datetime.datetime(now.year, now.month, now.day, 0, 0, 0)
        end_of_day = datetime.datetime(now.year, now.month, now.day, 23, 59, 59)

        search_results = calendar.date_search(start=start_of_day, end=end_of_day)
        if not search_results:
            return "Your calendar is clear for today."

        events_list = []
        for event in search_results:
            vobject = event.vobject_instance
            summary = vobject.vevent.summary.value
            dtstart = vobject.vevent.dtstart.value
            if isinstance(dtstart, datetime.datetime):
                time_str = dtstart.strftime("%H:%M")
                events_list.append(f"At {time_str}, {summary}.")
            else:
                events_list.append(f"All day event, {summary}.")
        return "Your schedule for today includes: " + " ".join(events_list)
    except Exception as e:
        print(f"CalDAV calendar error: {e}", file=sys.stderr)
        return "Failed to connect to the Radicale calendar server."

def push_to_home_assistant(briefing_text):
    if not all([HA_URL, HA_TOKEN]):
        print("Home Assistant configuration is incomplete.", file=sys.stderr)
        return False
    headers = {
        "Authorization": f"Bearer {HA_TOKEN}",
        "Content-Type": "application/json",
    }
    payload = {"state": "Updated", "attributes": {"text": briefing_text}}
    try:
        req = requests.post(HA_URL, json=payload, headers=headers, timeout=5)
        return req.status_code in (200, 201)
    except Exception as e:
        print(f"Home Assistant REST API error: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    full_briefing = f"Good morning! {get_calgary_weather()} {get_today_events()}"
    if push_to_home_assistant(full_briefing):
        print("Briefing generated and pushed to Home Assistant successfully.")
    else:
        sys.exit(1)
