#!/usr/bin/env python3
"""Compare two timestamps and output which is newer.

Supports:
- Unix milliseconds (e.g., "1767928849185")
- Unix seconds (e.g., "1767928849")
- ISO 8601 (e.g., "2026-01-09T00:06:53-03:00" or "2026-01-09T00:06:53.038283-03:00")

Usage:
    compare-timestamps.py <timestamp1> <timestamp2>

Output:
    "first" if timestamp1 is newer
    "second" if timestamp2 is newer
    "equal" if they are the same (within 1 second tolerance)

Exit codes:
    0: success
    1: first is newer
    2: second is newer
    3: equal
"""

import sys
from datetime import datetime, timezone


def parse_timestamp(ts: str) -> float:
    """Parse timestamp string to epoch seconds."""
    ts = ts.strip().strip('"')

    # Try Unix milliseconds (13+ digits)
    if ts.isdigit() and len(ts) >= 13:
        return int(ts) / 1000.0

    # Try Unix seconds (10 digits)
    if ts.isdigit() and len(ts) <= 12:
        return float(ts)

    # Try ISO 8601 formats
    # Handle microseconds by truncating to 6 digits
    if '.' in ts:
        base, frac = ts.split('.', 1)
        # Extract just the microseconds and timezone
        for i, c in enumerate(frac):
            if c in '+-Z':
                frac = frac[:min(i, 6)] + frac[i:]
                break
        else:
            frac = frac[:6]
        ts = f"{base}.{frac}"

    # Python 3.11+ handles 'Z' directly, but for compatibility:
    ts = ts.replace('Z', '+00:00')

    try:
        dt = datetime.fromisoformat(ts)
        # Convert to UTC epoch
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.timestamp()
    except ValueError:
        pass

    raise ValueError(f"Cannot parse timestamp: {ts}")


def main():
    if len(sys.argv) != 3:
        print("Usage: compare-timestamps.py <timestamp1> <timestamp2>", file=sys.stderr)
        sys.exit(1)

    try:
        ts1 = parse_timestamp(sys.argv[1])
        ts2 = parse_timestamp(sys.argv[2])
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    # Tolerance of 1 second for "equal"
    diff = ts1 - ts2

    if abs(diff) < 1:
        print("equal")
        sys.exit(3)
    elif diff > 0:
        print("first")
        sys.exit(1)
    else:
        print("second")
        sys.exit(2)


if __name__ == "__main__":
    main()
