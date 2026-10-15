#!/usr/bin/env python3
"""Exercise the managed PhotoCraft configuration against a real CLI over MCP stdio."""

import argparse
import base64
import json
from pathlib import Path
import queue
import shutil
import struct
import subprocess
import sys
import tempfile
import threading
import time

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib


class Client:
    def __init__(self, process):
        self.process = process
        self.messages = queue.Queue()
        self.next_id = 0
        self.reader = threading.Thread(target=self.read, daemon=True)
        self.reader.start()

    def read(self):
        try:
            for line in self.process.stdout:
                self.messages.put(json.loads(line))
        except (ValueError, OSError) as error:
            self.messages.put(error)
        finally:
            self.messages.put(EOFError("MCP server closed stdout"))

    def send(self, message):
        self.process.stdin.write(json.dumps({"jsonrpc": "2.0", **message}) + "\n")
        self.process.stdin.flush()

    def request(self, method, params):
        self.next_id += 1
        self.send({"id": self.next_id, "method": method, "params": params})
        deadline = time.monotonic() + 30
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(f"MCP timed out: {method}")
            try:
                message = self.messages.get(timeout=remaining)
            except queue.Empty as error:
                raise TimeoutError(f"MCP timed out: {method}") from error
            if isinstance(message, Exception):
                raise message
            if message.get("id") == self.next_id:
                return message

    def call(self, name, arguments, fail=False):
        message = self.request("tools/call", {"name": name, "arguments": arguments})
        result = message.get("result", {})
        failed = "error" in message or result.get("isError", False)
        if bool(failed) != fail:
            raise AssertionError(f"{name}: expected failure={fail}: {message}")
        return result


def text_json(result):
    return json.loads(next(item["text"] for item in result["content"] if item["type"] == "text"))


def png_size(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError("Expected a PNG")
    return struct.unpack(">II", data[16:24])


def check(client, root):
    initialized = client.request("initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "titus-ai-smoke-test", "version": "1.0"},
    })
    assert "result" in initialized, initialized
    assert "tools" in initialized["result"]["capabilities"], initialized
    client.send({"method": "notifications/initialized"})
    tools = client.request("tools/list", {})
    names = {tool["name"] for tool in tools["result"]["tools"]}
    assert {"doc_new", "command_list", "command_run", "doc_save", "doc_export",
            "doc_inspect", "doc_open", "doc_close", "doc_render_preview"} <= names
    client.call("doc_new", {"width": 64, "height": 64, "background": "transparent"})
    commands = client.call("command_list", {"filter": "shape.create"})
    assert "shape.create" in json.dumps(commands)
    client.call("command_run", {"id": "shape.create", "params": {
        "kind": "rect", "rect": [8, 8, 48, 48], "fill": "#165DDE", "name": "Test shape",
    }})
    preview = client.call("doc_render_preview", {"max_side": 64})
    image = next(item for item in preview["content"] if item["type"] == "image")
    assert image["mimeType"] == "image/png"
    assert png_size(base64.b64decode(image["data"], validate=True)) == (64, 64)
    client.call("doc_save", {"path": "shape.pcraft"})
    client.call("doc_export", {"path": "shape.png"})
    assert png_size((root / "shape.png").read_bytes()) == (64, 64)
    client.call("doc_close", {})
    client.call("doc_open", {"path": "shape.pcraft"})
    state = text_json(client.call("doc_inspect", {}))
    assert (state["width"], state["height"]) == (64, 64), state
    assert any(layer["kind"] == "Shape" and layer["name"] == "Test shape"
               for layer in state["layers"]), state
    # Existing, valid PNG outside the root distinguishes denial from missing-file errors.
    outside = root.parent / "outside.png"
    outside.write_bytes((root / "shape.png").read_bytes())
    before = outside.read_bytes()
    client.call("doc_open", {"path": "../outside.png"}, fail=True)
    client.call("doc_open", {"path": str(outside)}, fail=True)
    client.call("doc_export", {"path": "../outside.png"}, fail=True)
    client.call("doc_export", {"path": str(outside)}, fail=True)
    assert outside.read_bytes() == before, "Out-of-root file was changed"
    client.call("command_run", {"id": "not.a.command"}, fail=True)
    client.call("doc_inspect", {})  # Rejections must leave the session usable.
    print(f"PhotoCraft MCP passed: {len(names)} tools; shapes, preview, export, reopen, root restrictions")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", help="PhotoCraft CLI executable (default: configured command on PATH)")
    repo = Path(__file__).resolve().parent.parent
    parser.add_argument("--config", type=Path, default=repo / "codex-home/config.toml",
                        help="Codex config to exercise (default: managed default config)")
    args = parser.parse_args()
    config = tomllib.loads(args.config.read_text())
    server = config["mcp_servers"]["photocraft"]
    assert server.get("enabled", True), "PhotoCraft is disabled in the selected config"
    binary = shutil.which(args.cli or server["command"])
    if not binary:
        parser.error("photocraft-cli not found; install it or pass --cli /path/to/photocraft-cli")
    binary = str(Path(binary).resolve())
    with tempfile.TemporaryDirectory(prefix="titus-ai-photocraft-") as temporary:
        root = Path(temporary) / "artwork with spaces"
        root.mkdir()
        with tempfile.TemporaryFile(mode="w+t") as errors:
            process = subprocess.Popen(
                [binary, *server["args"]], cwd=root, stdin=subprocess.PIPE,
                stdout=subprocess.PIPE, stderr=errors, text=True, encoding="utf-8",
            )
            try:
                check(Client(process), root)
            except Exception:
                process.terminate()
                process.wait(timeout=5)
                errors.seek(0)
                print(errors.read(), file=sys.stderr, end="")
                raise
            finally:
                process.stdin.close()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
                process.stdout.close()


if __name__ == "__main__":
    main()
