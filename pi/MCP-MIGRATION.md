# Migrating Pi MCP from `pi-mcp-adapter` to built-in MCP

Pi 0.99.1 includes MCP. `pi-mcp-adapter` **replaces** the built-in `/mcp` in sessions while installed. These instructions apply to other machines that previously ran `./pi/setup-mcp.sh`; on a fresh machine, just run that script (it no longer installs the adapter). Close running Pi sessions before editing machine-local settings.

1. Back up private config (keep backups private and out of this repo):

   ```bash
   umask 077
   stamp=$(date +%Y%m%d-%H%M%S)
   cp -p ~/.pi/agent/mcp.json ~/.pi/agent/mcp.json.bak.pre-native-"$stamp"
   if test -f ~/.pi/agent/permissions.json; then
     cp -p ~/.pi/agent/permissions.json ~/.pi/agent/permissions.json.bak.pre-native-"$stamp"
   fi
   ```

   If using `$PI_CODING_AGENT_DIR`, substitute that directory. Keep each backup rather than overwriting an earlier one.

2. Convert **your existing** `mcp.json` in place, preserving any extra servers. The shared `pi/mcp.json` is a native-format template, but `./pi/setup-mcp.sh` deliberately does **not** overwrite a private file. Remove the adapter-only top-level `settings` and per-server `lifecycle`, `inheritEnv`, `auth`, and `bearerToken` fields. Keep the Playwright `command`/`args` and GitHub `url`. For GitHub use native `headers` instead of `auth`/`bearerToken`:

   ```json
   "headers": { "Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" }
   ```

   Supply the environment variable before starting Pi. If this machine used 1Password's `!op read` to return a **bare token**, you can preserve that mechanism with a private header that emits the *whole* header value:

   ```json
   "headers": { "Authorization": "!printf 'Bearer %s' \"$(op read 'op://Developer/GitHub-MCP/credential')\"" }
   ```

   Never commit credentials. Native `!command` occupies the whole header value, not just the token. If your old command already emitted `Bearer ...`, use it without the `printf` wrapper. Alternatively, omit the header and try `pi mcp login GitHub` if your server supports Pi's OAuth flow.

3. If the dotfiles permissions extension is installed, keep its **Bash** rules but remove any old `GitHub/*`, `playwright/*`, `mcp__*`, or resource-read `ask` rules from the private `permissions.json`. The shared `pi/permissions.json` now has no MCP approval rules. Existing private policies are intentionally not overwritten by setup. Native MCP calls (including nested `codemode` calls) are allowed without another approval prompt by default; their permissions come from the MCP server and its credentials. Other explicit policy rules, such as `"*": "ask"`, can still affect MCP.

4. From a shell, check `pi mcp list`. This command uses native MCP **even while the adapter is installed**. Resolve `needs-auth`/connection failures before continuing. Playwright may need its browser installed; GitHub may need an authenticated 1Password CLI or environment variable.

5. Remove only the MCP adapter package (not the optional observational-memory package or the Bash permissions extension):

   ```bash
   cd ~/.pi/agent
   pi --no-approve remove npm:pi-mcp-adapter@2.34.0
   pi list
   pi mcp list
   ```

   Restart Pi (or `/reload` in a running session), then inspect `/mcp`. If GitHub/Playwright appear with tools, Pi is using the built-in manager. `pi mcp list` returning success is the connection check; it does not itself test a model-issued tool call. Test an MCP call in Pi to confirm there are no extra approval prompts.

## Behavior changes

- Native Pi connects enabled servers at session startup; the old lazy lifecycle option does not apply. Native stdio servers inherit Pi's process environment; `inheritEnv: false` has no equivalent in this configuration. Limit Pi's launch environment or wrap the server command if isolation is important.
- Default MCP exposure is `codemode`: Pi activates `codemode` and keeps large tool lists out of the model's direct declarations. `/mcp` can change exposure to `direct`, `deferred`, `codemode-deferred`, or `hidden` per server; `toolExposure` in `mcp.json` overrides individual tools.
- `/mcp setup`, adapter approval settings, host-config discovery, scripting and sampling options are gone. Use `/mcp` to manage servers, `pi mcp add|remove|list|login|logout` from a shell, and `/reload` after changes. Built-in MCP does not provide the adapter's approval dialogs. Server permissions still depend on the credentials you configure; Pi's local tool exposure is not an authorization boundary.
- This migration does not modify OpenCode or automatically sync its MCP configuration.
