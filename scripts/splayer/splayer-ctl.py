#!/usr/bin/env python3
"""Send a control command to SPlayer via WebSocket."""
import asyncio
import json
import sys

import websockets

async def send(cmd):
    try:
        async with websockets.connect("ws://localhost:25885") as ws:
            await ws.send(json.dumps({"type": "control", "data": {"command": cmd}}))
    except Exception:
        pass

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: splayer-ctl toggle|next|prev|play|pause")
        sys.exit(1)
    asyncio.run(send(sys.argv[1]))
