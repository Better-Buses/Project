#!/usr/bin/env python3

import sys
import csv
import re

SCHEDULE_CSV = "/data/schedule.csv"

def time_to_seconds(t):
    h, m, s = map(int, t.split(":"))
    return h * 3600 + m * 60 + s

schedule = {}
with open(SCHEDULE_CSV, newline='') as f:
    reader = csv.reader(f)
    header = next(reader)
    stop_ids = [int(x.strip()) for x in header]
    for zone_idx, row in enumerate(reader, start=1):
        for col_idx, time_str in enumerate(row):
            stop_id = stop_ids[col_idx]
            schedule[(zone_idx, stop_id)] = time_to_seconds(time_str)

line_re = re.compile(r'^(\S+?),(\S+) (\S+)(?: (\d+))?$')

def parse_topic_tag(tags_str):
    m = re.search(r'topic="?([^",]+)"?', tags_str)
    return m.group(1) if m else None

def zone_stop_from_topic(topic):
    m = re.match(r'zone-(\d+)/stop/(\d+)', topic)
    return (int(m.group(1)), int(m.group(2))) if m else None

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    m = line_re.match(line)
    if not m:
        print(line, flush=True)
        continue

    measurement, tags_str, fields_str, ts = m.groups()

    if not measurement.startswith("stop_offset"):
        print(line, flush=True)
        continue

    topic = parse_topic_tag(tags_str)
    zs = zone_stop_from_topic(topic) if topic else None
    if zs is None or zs not in schedule:
        print(line, flush=True)
        continue

    fm = re.match(r'value="?(\d{2}:\d{2}:\d{2})"?', fields_str)
    if not fm:
        print(line, flush=True)
        continue

    actual_seconds = time_to_seconds(fm.group(1))
    diff = (actual_seconds - schedule[zs])/60 # in minutes

    new_line = f"{measurement},{tags_str} value={diff}"
    if ts:
        new_line += f" {ts}"
    print(new_line, flush=True)
