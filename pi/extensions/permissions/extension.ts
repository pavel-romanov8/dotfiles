import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { join, resolve } from "node:path";
import { PermissionGate } from "./gate.ts";
import { absolutePath, canonicalPath, display, pathInputs, stableJSON, within } from "./policy.ts";

export function registerPermissions(pi: ExtensionAPI, agentDir: string, extensionRoot: string): void {
  const policyPath = join(agentDir, "permissions.json");
  const gate = new PermissionGate(policyPath);
  const protectedFiles = [policyPath, join(agentDir, "settings.json"), join(agentDir, "mcp.json"), join(agentDir, "mcp-auth.json")];
  const protectedDirectories = [extensionRoot, join(agentDir, "extensions")];

  function protects(path: string, cwd: string): boolean {
    const absolute = absolutePath(path, cwd);
    const canonical = canonicalPath(absolute);
    // Compare both names and targets: symlink aliases and replacing the symlink
    // itself must not bypass this check.
    return protectedFiles.some(file => absolute === resolve(file) || canonical === canonicalPath(resolve(file)))
      || protectedDirectories.some(dir => within(absolute, resolve(dir)) || within(canonical, canonicalPath(resolve(dir))));
  }

  pi.on("session_start", (_event, ctx) => {
    gate.clear();
    try {
      gate.inspect();
      if (ctx.hasUI) ctx.ui.setStatus("dotfiles-permissions", "permissions: on");
    } catch {
      if (ctx.hasUI) {
        ctx.ui.setStatus("dotfiles-permissions", "permissions: BLOCKED");
        ctx.ui.notify(`Missing or invalid policy: ${policyPath}. Tool calls will be blocked.`, "error");
      }
    }
  });
  pi.on("session_tree", () => gate.clear());
  pi.on("session_shutdown", () => gate.clear());

  pi.on("tool_call", async (event, ctx) => {
    try {
      const metadata = pi.getAllTools().find(tool => tool.name === event.toolName);
      // Native MCP tools (including calls nested in codemode) pass through this
      // hook by their actual mcp__<server>__<tool> names. No adapter event or
      // separate approval cache is needed.
      const input = event.input as Record<string, unknown>;
      const path = typeof input.path === "string" ? input.path : undefined;
      const fileTool = ["read", "edit", "write", "grep", "find", "ls"].includes(event.toolName);
      const result = await gate.authorize({
        tool: event.toolName,
        input,
        values: fileTool ? pathInputs(path ?? ".", ctx.cwd) : undefined,
        command: event.toolName === "bash" && typeof input.command === "string" ? input.command : undefined,
        forceAsk: (event.toolName === "edit" || event.toolName === "write") && path && protects(path, ctx.cwd)
          ? "Changing permission/extension/MCP configuration requires explicit approval" : undefined,
        identity: metadata ? stableJSON([metadata.sourceInfo, metadata.description, metadata.parameters]) : undefined,
      }, ctx);
      return result.allowed ? undefined : { block: true, reason: result.reason };
    } catch {
      return { block: true, reason: "Permission check failed; blocked" };
    }
  });

  pi.registerCommand("permissions", {
    description: "Inspect global permissions; /permissions clear revokes exact-action session approvals",
    getArgumentCompletions: prefix => ["status", "clear"].filter(value => value.startsWith(prefix)).map(value => ({ value, label: value })),
    handler: async (args, ctx) => {
      const command = args.trim();
      if (command === "clear") {
        gate.clear();
        if (ctx.hasUI) ctx.ui.notify("Permission session approvals cleared", "info");
        return;
      }
      if (command && command !== "status") {
        if (ctx.hasUI) ctx.ui.notify("Usage: /permissions [status|clear]", "warning");
        return;
      }
      try {
        const { policy, grants } = gate.inspect();
        pi.sendMessage({
          customType: "dotfiles-permissions",
          content: `Global policy: ${display(policyPath)}\nExact-action session approvals: ${grants}\nRules are read on every check. Last matching rule wins.\n\n${display(JSON.stringify(policy, null, 2))}`,
          display: true,
        }, { triggerTurn: false });
      } catch {
        if (ctx.hasUI) ctx.ui.notify(`Missing or invalid policy: ${policyPath}. Fix it using your editor.`, "error");
      }
    },
  });
}
