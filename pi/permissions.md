# Pi permissions

A dotfiles-owned, dependency-free Pi extension providing OpenCode-inspired
`allow` / `ask` / `deny` workflow rules. This is not a sandbox or a complete
implementation of OpenCode's permission system.

## Install

With Pi installed, close Pi and run from the dotfiles checkout:

```bash
python3 pi/setup_permissions.py
```

Setup links `pi/extensions/permissions/` to
`~/.pi/agent/extensions/dotfiles-permissions/` and seeds
`~/.pi/agent/permissions.json` from `pi/permissions.example.json` **only if absent**.
`PI_CODING_AGENT_DIR` is supported. Existing valid policies are preserved,
including symlinks. Invalid policies, broken symlinks, and conflicting extension
paths stop setup rather than being replaced. No packages are installed and no
Pi settings or credentials are changed.

Restart Pi or run `/reload`, then `/permissions`. Extension code follows this
checkout; use `/reload` after pulling updates. Policy changes are read on every
permission check, so editing the JSON does not require reload.

`./setup.sh` still configures appearance only. Permission and MCP installation
are separate opt-in commands. The MCP integration requires the reviewed adapter
version **`pi-mcp-adapter@2.34.0`**, installed by `./pi/setup-mcp.sh`.

## Policy

Edit `~/.pi/agent/permissions.json` with your editor. No project policies load in
this version, so a repository cannot override the global policy via a local
permissions file.

```json
{
  "permission": {
    "*": "ask",
    "read": "allow",
    "edit": "allow",
    "write": "allow",
    "bash": {
      "*": "ask",
      "git status": "allow",
      "git status --short": "allow",
      "git push*": "ask",
      "sudo": "deny",
      "sudo *": "deny"
    },
    "GitHub/*": "ask",
    "GitHub/get_me": "allow",
    "playwright/*": "ask"
  }
}
```

The supplied template also allows `ls`, `grep`, `find`, `pwd`, and a few exact
Git inspection commands. It does **not** auto-allow arbitrary `git *`, `npm *`,
Python, or other interpreters.

### Matching

- Rules use **case-sensitive, anchored** wildcard matching: `*` matches any
  sequence (including separators), `?` matches one character. Everything else
  is literal; this is not regex or filesystem glob syntax.
- Outer patterns match the Pi tool name, or `<server>/<original-tool-name>` for
  MCP. Use `GitHub/get_me`, not `GitHub_get_me`. Server names are case-sensitive.
- String rules set the action for that tool. Nested objects match tool input.
- **Last matching rule wins**, in JSON property order, at both levels. Put `*`
  first and exceptions later. A nested rule that does not match leaves the prior
  decision in effect. Without any match the result is `ask`.
- For Bash, nested patterns match the command. Simple commands have surrounding
  spaces/tabs removed and internal spaces/tabs collapsed for matching; the
  original command is executed, not rewritten.
- For file tools, patterns match either the normalized cwd-relative path,
  absolute path, or canonical symlink target. `~/` input patterns expand to the
  user's home directory. `*` spans directory separators. Missing optional paths
  in `ls`, `find`, and `grep` mean the current directory.
- For other tools and MCP calls, nested patterns match compact JSON arguments
  with recursively sorted object keys. Prefer tool-level rules for these; JSON
  pattern rules are textual, not semantic argument validation.
- Only the `permission` top-level key is accepted. Malformed JSON, misspelled
  actions, invalid rule shapes, missing files, and policies over 64 KiB block
  gated calls. Recover using your editor; the agent cannot fix a missing policy
  through a blocked tool.

### Shell scope

Auto-allow is intentionally limited to a single command made of unquoted literal
words. Quotes, escapes, variable/command/process substitution, redirections,
comments, globbing, assignments, compound commands, and unsupported syntax
require approval **even if a broad allow rule matches**. An explicit matching
`deny` still blocks.

Flat command lists such as `git status && sudo reboot` are additionally checked
for per-command denials. If any of those simple commands is denied, the whole
call is blocked. Otherwise compound calls still ask once for the entire command.
This is a small conservative recognizer, not a general Bash parser. An opaque
form such as `sh -c 'sudo reboot'` asks unless a rule denies the whole command;
it is not guaranteed to discover every nested denied action.

An approved script, interpreter, shell function, executable or Git command can
have effects beyond its command-line spelling. For example, allowing `npm test`
trusts repository scripts, and Git behavior can depend on repository settings.
Rules do not inspect those implementations. Review the full command when asked.

## Prompts and session approvals

For `ask`, the dialog shows the tool, cwd, matched rule/reason, and complete
arguments. Choices are **Deny** (initial selection), **Allow once**, and
**Allow exact action for session**. Oversized details (over 16,000 characters)
are blocked instead of silently truncated for approval; split the operation.

Session grants are in-memory SHA-256 identities, not wildcard approvals. They
match the tool/action, exact arguments, working directory, and policy contents.
They are **not** approval of the executable's contents, repository state, or a
remote server's future implementation. Clear grants after changing server
configuration or when you want to review an action again. No arguments or grants
are written to disk by this extension (Pi still records normal tool calls).

Grants clear on policy changes observed by a check, `/permissions clear`, tree
navigation, `/reload`, restart, or session replacement. They are not restored
on `/resume`. Parallel MCP requests queue their dialogs and recheck grants after
waiting. Cancellation/dismissal, UI exceptions, and unavailable UI fail closed.
Policy/argument changes while an approval dialog is open invalidate approval.

Commands:

```text
/permissions          Show global policy and session-grant count
/permissions status   Same as above
/permissions clear    Revoke session grants and cancel pending approval prompts
```

## MCP integration

The extension synchronously claims the adapter's
`pi-mcp-adapter:tool-approval-request` event. It makes the decision for each
resolved tool/resource call, covering proxy, direct, namespace, scripting, and
iframe origins supported by the pinned adapter. It returns `allow_once` or
`deny` to the adapter, keeping session grants in this extension, so there is no
second approval dialog and no new adapter-persisted grant. Broker decisions
also supersede old adapter grants.

Keep `settings.approveTools: true` in MCP configuration as a fallback if this
extension is disabled. While our broker is active, its global rules govern
resolved calls even if the adapter's per-server approval settings differ.
Scripting and sampling remain disabled in the trial configuration.

Adapter-owned tool wrappers defer to the broker only when their Pi provenance
identifies the pinned npm package; unrelated tools with similar names do not
get this exemption. With another adapter version, wrappers may prompt as ordinary
tools as well; review/test the integration before changing the pin.

Discovery, connecting configured servers, authentication, and MCP prompt
retrieval are **not resolved tool calls** and aren't gated by this policy.
Model-initiated `mcp` URL installation gets a separate `mcp/install` check and
requires approval even if normally allowed. MCP server startup can execute
configured programs before any individual tool approval. Only configure trusted
servers and use appropriately scoped credentials.

## Boundaries

- Normal file edits are allowed. Direct `write`/`edit` changes to the policy,
  global Pi settings/MCP config, global extensions directory, or this
  extension's source directory require explicit approval (or are denied by a
  matching deny rule). Checks include symlink targets and existing parents of
  new files. These are guardrails, not a race-free filesystem security boundary.
- This does not police indirect file changes from an approved command or MCP
  tool, `!`/`!!` commands typed by the user, extension commands, extension code,
  subagents running another Pi process, or calls outside Pi's tool-call pipeline.
- Trusted extensions can run arbitrary code and alter tool arguments after this
  extension has checked them. Project **permissions** cannot weaken global rules,
  but trusting executable project extensions is still a full trust decision.
- `--no-extensions`, uninstalling/disabling this extension, or an extension-load
  failure means no permission enforcement. Check the `permissions: on` footer
  and `/permissions`; a missing footer/command is not a fail-closed launcher.

## Verify / uninstall

Tests require Node 22.6+ (TypeScript strip support) or current Node 24:

```bash
node --experimental-strip-types --test pi/tests/permissions.test.ts
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s pi -p 'test_*.py'
```

To disable, remove only the `extensions/dotfiles-permissions` symlink from your
Pi agent directory, then restart Pi. Keep `permissions.json` for a later
reinstall. This does not remove MCP's own approval fallback.
