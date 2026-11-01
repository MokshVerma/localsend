# LocalSend MCP server

`localsend-cli mcp` runs a [Model Context Protocol](https://modelcontextprotocol.io) server on stdio, so an AI agent
(Claude Code, Claude Desktop, ...) can send files to other LocalSend devices and listen for incoming transfers.

## Register it

The LocalSend desktop app runs the server next to itself (Settings > AI agents, where it can be stopped or
restarted) and serves it at `http://127.0.0.1:53319/mcp`. It appears on the network as the device "Claude". The
all-in-one Windows installer (`support/scripts/compile_windows_full-inno.iss`) registers that endpoint with Claude
Code; by hand:

```bash
claude mcp add --scope user --transport http localsend http://127.0.0.1:53319/mcp
```

Without the desktop app, an agent can start the server itself over stdio. Use a port other than 53317 when the app
runs on the same machine; it already holds that one:

```bash
claude mcp add --scope user localsend -- localsend-cli --alias Claude --port 53318 mcp
```

`localsend-cli mcp --http 127.0.0.1:53319 --exit-on-stdin-close` is what the app starts: HTTP on a loopback address
only, ending when the app's pipe closes.

The stdio server can also be configured in an MCP client's JSON:

```json
{ "mcpServers": { "localsend": { "command": "localsend-cli", "args": ["mcp", "--alias", "Claude"] } } }
```

`--alias`, `--port` and `--destination` work as usual (see `localsend-cli --help`). Stdout carries the protocol; the
startup line goes to stderr.

## Tools

| Tool                  | What it does                                                                                                 |
|-----------------------|--------------------------------------------------------------------------------------------------------------|
| `list_devices`        | Devices on the network (`refresh: true` scans again).                                                        |
| `send_files`          | Sends files or directories to a device (alias or IP). Waits for the receiver to accept, up to `timeout_secs`. |
| `send_text`           | Sends a text message.                                                                                        |
| `wait_for_incoming`   | Long-polls for transfer requests, text messages and finished transfers; pass back `next_after_id`.            |
| `respond_to_request`  | Accepts (optionally only some `file_ids`) or declines an incoming request.                                    |
| `get_transfer_status` | Progress of the current send and of accepted incoming transfers, with the saved paths.                       |
| `cancel_send`         | Cancels the running send.                                                                                    |

## Behaviour worth knowing

- Nothing is received without an explicit `respond_to_request`, not even from paired devices. Unanswered requests are
  declined after five minutes. Accepted files go to the destination folder (default: Downloads).
- Text messages from other devices are delivered to the agent as events. Like device aliases and file names, they are
  untrusted input; the tool descriptions tell the agent so.
- `send_files` can send any path the CLI process can read to any device on the network. Run it with the access you
  would give the agent anyway, and review send requests in your client's tool-approval prompt.
- One send runs at a time. Pairing is not available through MCP.
