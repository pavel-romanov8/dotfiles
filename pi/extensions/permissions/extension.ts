import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { join, resolve } from "node:path";
import { PermissionGate } from "./gate.ts";
import { absolutePath, canonicalPath, display, pathInputs, stableJSON, within } from "./policy.ts";

export const MCP_APPROVAL_EVENT = "pi-mcp-adapter:tool-approval-request";
const ADAPTER_SOURCE = "npm:pi-mcp-adapter@2.34.0";
interface McpApprovalRequest {
  serverName: string;
  originalToolName: string;
  args: Record<string, unknown>;
  signal?: AbortSignal;
  claim(handler: () => Promise<"allow_once" | "deny">): boolean;
}

export function registerPermissions(pi: ExtensionAPI, agentDir: string, extensionRoot: string): void {
  const policyPath = join(agentDir, "permissions.json");
  const gate = new PermissionGate(policyPath);
  let context: ExtensionContext | undefined;
  const protectedFiles = [policyPath, join(agentDir, "settings.json"), join(agentDir, "mcp.json")];
  const protectedDirectories = [extensionRoot, join(agentDir, "extensions")];

  function protects(path: string, cwd: string): boolean {
    const absolute = absolutePath(path, cwd);
    const canonical = canonicalPath(absolute);
    // Compare both names and targets: symlink aliases and replacing the symlink
    // itself must not bypass this check.
    return protectedFiles.some(file => absolute === resolve(file) || canonical === canonicalPath(resolve(file)))
      || protectedDirectories.some(dir => within(absolute, resolve(dir)) || within(canonical, canonicalPath(resolve(dir))));
  }

  const unsubscribe = pi.events.on(MCP_APPROVAL_EVENT, raw => {
    const request = raw as McpApprovalRequest;
    // Claim synchronously. The adapter otherwise falls back to its own UI/cache.
    request.claim(async () => {
      const ctx = context;
      if (!ctx) return "deny";
      const result = await gate.authorize({
        tool: `${request.serverName}/${request.originalToolName}`,
        input: request.args,
        // Keep the original argument object to detect mutation during a prompt.
        values: [stableJSON(request.args)],
      }, { cwd: ctx.cwd, hasUI: ctx.hasUI, ui: ctx.ui, signal: request.signal ?? ctx.signal });
      if (!result.allowed && ctx.hasUI) ctx.ui.notify(display(result.reason), "warning");
      // Own our grants; don't populate the adapter's separately persisted cache.
      // Broker decisions override that cache, including existing old approvals.
      return result.allowed ? "allow_once" : "deny";
    });
  });

  pi.on("session_start", (_event, ctx) => {
    context = ctx;
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
  pi.on("session_shutdown", () => {
    gate.clear();
    unsubscribe();
    context = undefined;
  });

  pi.on("tool_call", async (event, ctx) => {
    context = ctx;
    try {
      const metadata = pi.getAllTools().find(tool => tool.name === event.toolName);
      if (metadata?.sourceInfo.source === ADAPTER_SOURCE) {
        // Every resolved MCP tool/resource call is checked by the broker, no
        // matter whether it came from proxy, direct, namespace, script or iframe.
        // Discovery/connect/auth have no resolved tool call and remain available.
        if (event.toolName !== "mcp" || (event.input as Record<string, unknown>).action !== "install") return;
        const result = await gate.authorize({
          tool: "mcp/install", input: event.input,
          forceAsk: "Installing a server changes MCP configuration",
        }, ctx);
        return result.allowed ? undefined : { block: true, reason: result.reason };
      }

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
