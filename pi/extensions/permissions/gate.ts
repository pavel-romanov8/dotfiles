import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { decide, decideBash, display, parsePolicy, stableJSON, type Policy } from "./policy.ts";

export interface Request {
  tool: string;
  input: Record<string, unknown>;
  values?: string[];
  command?: string;
  forceAsk?: string;
  identity?: string;
}
export interface GateContext {
  cwd: string;
  hasUI: boolean;
  signal?: AbortSignal;
  ui: { select(title: string, choices: string[], options?: { signal?: AbortSignal }): Promise<string | undefined> };
}
export type Verdict = { allowed: boolean; reason: string };
const hash = (text: string) => createHash("sha256").update(text).digest("hex");

export class PermissionGate {
  private grants = new Set<string>();
  private signature: string | undefined;
  private queue: Promise<unknown> = Promise.resolve();
  private cancelled = new AbortController();

  readonly policyPath: string;
  constructor(policyPath: string) { this.policyPath = policyPath; }

  clear(): void {
    this.grants.clear();
    this.cancelled.abort();
    this.cancelled = new AbortController();
  }

  inspect(): { policy: Policy; grants: number } {
    return { policy: this.load().policy, grants: this.grants.size };
  }

  private load(): { policy: Policy; signature: string } {
    try {
      const text = readFileSync(this.policyPath, "utf8");
      const signature = hash(text);
      // Revoke old grants even if the new configuration is invalid.
      if (signature !== this.signature) this.grants.clear();
      this.signature = signature;
      return { policy: parsePolicy(text), signature };
    } catch (error) {
      this.grants.clear();
      this.signature = undefined;
      throw error;
    }
  }

  authorize(request: Request, ctx: GateContext): Promise<Verdict> {
    const signal = ctx.signal
      ? AbortSignal.any([ctx.signal, this.cancelled.signal]) : this.cancelled.signal;
    // Serializes MCP fan-out dialogs; also rechecks grants after waiting.
    const result = this.queue.then(() => this.check(request, ctx, signal)).catch(() => ({
      allowed: false, reason: "Permission check failed; blocked",
    }));
    this.queue = result;
    return result;
  }

  private async check(request: Request, ctx: GateContext, signal: AbortSignal): Promise<Verdict> {
    const no = (reason: string): Verdict => ({ allowed: false, reason });
    if (signal.aborted) return no("Permission request cancelled");
    let loaded: ReturnType<PermissionGate["load"]>;
    try { loaded = this.load(); }
    catch { return no(`Missing or invalid policy: ${this.policyPath}. Fix it before retrying.`); }

    const args = stableJSON(request.input);
    const fingerprint = stableJSON(request);
    const key = hash(stableJSON([loaded.signature, ctx.cwd, fingerprint]));
    let decision = request.command === undefined
      ? decide(loaded.policy, request.tool, request.values ?? [args])
      : decideBash(loaded.policy, request.command);
    if (request.forceAsk && decision.action !== "deny") decision = { action: "ask", reason: request.forceAsk };
    if (decision.action === "deny") return no(`Denied by rule: ${decision.reason}`);
    if (decision.action === "allow") return { allowed: true, reason: decision.reason };
    if (this.grants.has(key)) return { allowed: true, reason: "Exact action approved for session" };
    if (!ctx.hasUI) return no(`Approval required (no UI): ${decision.reason}`);

    const detail = display(request.command ?? JSON.stringify(request.input, null, 2));
    // Never approve a call while silently hiding some of its arguments.
    if (detail.length > 16000) return no("Approval details exceed 16,000 characters; split the operation into smaller calls");
    const choice = await ctx.ui.select(
      `Permission: ${display(request.tool)}\nDirectory: ${display(ctx.cwd)}\nRule: ${display(decision.reason)}\n\n${detail}`,
      ["Deny", "Allow once", "Allow exact action for session"],
      { signal },
    );
    if (signal.aborted) return no("Permission request cancelled");
    if (choice !== "Allow once" && choice !== "Allow exact action for session") return no("Rejected or dismissed by user");
    // A policy may have changed while the dialog was open. Never approve against
    // the stale rules, and never approve arguments changed by another callback.
    try {
      if (this.load().signature !== loaded.signature || stableJSON(request) !== fingerprint) {
        return no("Policy or arguments changed during approval; retry the action");
      }
    } catch { return no("Policy became unavailable during approval"); }
    if (choice === "Allow exact action for session") this.grants.add(key);
    return { allowed: true, reason: "Approved by user" };
  }
}
