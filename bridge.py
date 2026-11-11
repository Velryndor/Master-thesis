#!/usr/bin/env python3
"""Beam SDK 2.2 -> Godot. UDP JSON, uniquement sur localhost."""
import json
import socket
import time
from eyeware import beam_eye_tracker as beam


def main():
    viewport = beam.ViewportGeometry()
    viewport.point_00 = beam.Point(0, 0)
    viewport.point_11 = beam.Point(0, 0)
    api = beam.API("Beam vers Godot", viewport)
    timestamp = beam.NULL_DATA_TIMESTAMP()
    print("Passerelle active : 127.0.0.1:4243 — Ctrl+C pour arrêter.", flush=True)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
        def send(data):
            udp.sendto(json.dumps(data, allow_nan=False).encode(), ("127.0.0.1", 4243))

        try:
            while True:
                if not api.wait_for_new_tracking_state_set(timestamp, 250):
                    send({"valid": False, "confidence": 0})
                    continue
                state = api.get_latest_tracking_state_set().user_state()
                gaze = state.unified_screen_gaze
                confidence = int(gaze.confidence)
                point = gaze.point_of_regard
                send({"x": point.x, "y": point.y, "confidence": confidence,
                      "valid": confidence >= 2,
                      "timestamp": state.timestamp_in_seconds.value})
        except KeyboardInterrupt:
            print("\nPasserelle arrêtée.")
        finally:
            send({"valid": False, "confidence": 0})


if __name__ == "__main__":
    main()
