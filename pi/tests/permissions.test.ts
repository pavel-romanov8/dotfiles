import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { decide, decideBash, matches, parsePolicy, stableJSON, canonicalPath, pathInputs, display } from "../extensions/permissions/policy.ts";
import { PermissionGate } from "../extensions/permissions/gate.ts";
import { registerPermissions, MCP_APPROVAL_EVENT } from "../extensions/permissions/extension.ts";

const policy = parsePolicy(readFileSync(new URL("../permissions.example.json", import.meta.url), "utf8"));
const askAll = { permission: { "*": "ask" } };
function fixture(t: any, initial: unknown = policy) {
  const dir = canonicalPath(mkdtempSync(join(tmpdir(), "pi-permissions-test-")));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const path = join(dir, "permissions.json");
  const save = (value: unknown) => writeFileSync(path, JSON.stringify(value));
  save(initial);
  const gate = new PermissionGate(path);
  let prompts = 0;
  let choose = async (_title: string, _choices: string[], _options?: any): Promise<string | undefined> => "Allow once";
  const ctx = {
    cwd: dir, hasUI: true, signal: undefined as AbortSignal | undefined,
    ui: { select: async (title: string, choices: string[], options?: any) => { prompts++; return choose(title, choices, options); } },
  };
  return { dir, path, gate, save, ctx, prompts: () => prompts, choose: (fn: typeof choose) => { choose = fn; } };
}
const bash = (command: string) => ({ tool: "bash", input: { command }, command });

test("strict policy validation", () => {
  for (const text of ['null', '[]', '{}', '{"permission":[]}', '{"permission":{"bash":"alow"}}', '{"permission":{"bash":{}}}', '{"permission":{},"permision":{}}']) {
    assert.throws(() => parsePolicy(text));
  }
  assert.throws(() => parsePolicy(" ".repeat(65537)));
  const fallback = decide(parsePolicy('{"permission":{}}'), "unknown", [""]);
  assert.equal(fallback.action, "allow");
  assert.match(fallback.reason, /default allow/);
});

test("anchored glob literals, wildcards and case sensitivity", () => {
  assert.ok(matches("GitHub/*", "GitHub/get_me"));
  assert.ok(matches("a?c*", "abc"));
  assert.ok(matches("*a*b", "xxayb"));
  assert.ok(matches("*.env", "nested/.env"));
  assert.ok(matches("a.b", "a.b"));
  assert.ok(!matches("a.b", "axb"));
  assert.ok(!matches("GitHub/*", "github/get_me"));
  assert.ok(!matches("sudo *", "echo sudo test"));
});

test("last matching rule wins at both levels; nested misses retain fallback", () => {
  const p = parsePolicy('{"permission":{"*":"ask","bash":{"*":"deny","git *":"allow","git push*":"ask"},"GitHub/*":"deny","GitHub/get_me":"allow"}}');
  assert.equal(decide(p, "bash", ["git status"]).action, "allow");
  assert.equal(decide(p, "bash", ["git push origin main"]).action, "ask");
  assert.equal(decide(p, "bash", ["rm file"]).action, "deny");
  assert.equal(decide(p, "GitHub/get_me", ["{}"]).action, "allow");
  assert.equal(decide(p, "GitHub/delete_repository", ["{}"]).action, "deny");
  assert.equal(decide(parsePolicy('{"permission":{"*":"deny","bash":{"pwd":"allow"}}}'), "bash", ["ls"]).action, "deny");
});

test("permissive Bash defaults retain destructive-operation guardrails", () => {
  assert.equal(decideBash(policy, " git\tstatus ").action, "allow");
  assert.equal(decideBash(policy, "git status --untracked-files=all").action, "allow");
  assert.equal(decideBash(policy, "git checkout feature-branch").action, "allow");
  for (const command of [
    "rm file", "rmdir build", "unlink output", "truncate -s 0 data",
    "git clean -fd", "git reset --hard HEAD", "git restore file",
    "git checkout -- file", "git push origin main", "git status && rm -rf build",
  ]) assert.equal(decideBash(policy, command).action, "ask", command);
  assert.equal(decideBash(policy, "sudo").action, "deny");
  assert.equal(decideBash(policy, "git status && sudo reboot").action, "deny");
});

test("Bash checks parsed command lists without treating normal syntax as suspicious", () => {
  const p = parsePolicy('{"permission":{"bash":{"*":"allow","git push*":"ask","sudo":"deny","sudo *":"deny"}}}');
  for (const command of [
    "printf 'x;y' | grep x", "printf '%s' 'sudo reboot'", 'echo "$TOKEN" > file',
    "echo '*.env' # literal glob", 'git status && git diff --stat', 'A=1 npm test', '(git status)',
    'python3 - <<\'PY\'\nprint(\'sudo reboot\')\nPY',
  ]) assert.equal(decideBash(p, command).action, "allow", command);
  assert.equal(decideBash(p, "git status && git push origin main").action, "ask");
  assert.equal(decideBash(p, "echo ok | sudo tee file").action, "deny");
  assert.equal(decideBash(p, "if true; then sudo reboot; fi").action, "deny");
  assert.equal(decideBash(p, 'echo "$(sudo reboot)"').action, "deny");
  assert.equal(decideBash(p, "cat <<EOF\n$(sudo reboot)\nEOF").action, "deny");
  assert.equal(decideBash(p, "echo `git push origin main`").action, "ask");
  assert.equal(decideBash(p, "").action, "ask");
});

test("compound commands are allowed when every parsed command is allowlisted", () => {
  const p = parsePolicy('{"permission":{"bash":{"*":"ask","git status*":"allow","git diff*":"allow"}}}');
  assert.equal(decideBash(p, "git status --short && git diff --stat").action, "allow");
  assert.equal(decideBash(p, "git status && npm test").action, "ask");
});

test("stable argument identities and safe terminal display", () => {
  assert.equal(stableJSON({ b: 2, a: [1, 2] }), stableJSON({ a: [1, 2], b: 2 }));
  assert.notEqual(stableJSON([1, 2]), stableJSON([2, 1]));
  assert.equal(display("a\x1b[31mb\u202ec"), "a\\u001b[31mb\\u202ec");
});

test("canonical paths include new files under symlinked parents", t => {
  const f = fixture(t);
  mkdirSync(join(f.dir, "real"));
  symlinkSync(join(f.dir, "real"), join(f.dir, "alias"));
  assert.equal(canonicalPath(join(f.dir, "alias/new/file")), join(f.dir, "real/new/file"));
  assert.ok(pathInputs("@alias/new/file", f.dir).includes(join(f.dir, "real/new/file")));
});

test("allow and deny do not prompt; file edits are allowed", async t => {
  const f = fixture(t);
  assert.ok((await f.gate.authorize(bash("git status"), f.ctx)).allowed);
  assert.ok(!(await f.gate.authorize(bash("sudo reboot"), f.ctx)).allowed);
  assert.ok((await f.gate.authorize({ tool: "edit", input: { path: "src/file" } }, f.ctx)).allowed);
  assert.equal(f.prompts(), 0);
});

test("unmatched tools are allowed without prompting", async t => {
  const f = fixture(t);
  const request = { tool: "custom_tool", input: { value: 1 } };
  assert.ok((await f.gate.authorize(request, f.ctx)).allowed);
  assert.equal(f.prompts(), 0);
});

test("explicit ask rules fail closed on dismissal, denial, UI errors and no UI", async t => {
  const f = fixture(t, askAll);
  const request = { tool: "custom_tool", input: { value: 1 } };
  for (const choice of [undefined, "Deny"]) {
    f.choose(async () => choice);
    assert.ok(!(await f.gate.authorize(request, f.ctx)).allowed);
  }
  f.choose(async () => { throw new Error("UI failed"); });
  assert.ok(!(await f.gate.authorize(request, f.ctx)).allowed);
  f.ctx.hasUI = false;
  assert.ok(!(await f.gate.authorize(request, f.ctx)).allowed);
  assert.equal(f.prompts(), 3);
});

test("session grants match exact args, tool, cwd and policy, and can be cleared", async t => {
  const f = fixture(t, askAll);
  f.choose(async () => "Allow exact action for session");
  const req = { tool: "GitHub/search", input: { b: 2, a: 1 } };
  assert.ok((await f.gate.authorize(req, f.ctx)).allowed);
  assert.ok((await f.gate.authorize({ ...req, input: { a: 1, b: 2 } }, f.ctx)).allowed);
  assert.equal(f.prompts(), 1);
  await f.gate.authorize({ ...req, input: { a: 1 } }, f.ctx);
  await f.gate.authorize({ ...req, tool: "GitHub/write" }, f.ctx);
  await f.gate.authorize(req, { ...f.ctx, cwd: join(f.dir, "other") });
  assert.equal(f.prompts(), 4);
  f.gate.clear();
  await f.gate.authorize(req, f.ctx);
  assert.equal(f.prompts(), 5);
  f.save({ permission: { "*": "deny" } });
  assert.ok(!(await f.gate.authorize(req, f.ctx)).allowed);
  f.save(askAll);
  await f.gate.authorize(req, f.ctx);
  assert.equal(f.prompts(), 6);
});

test("Allow once never grants later actions", async t => {
  const f = fixture(t, askAll);
  await f.gate.authorize(bash("git push"), f.ctx);
  await f.gate.authorize(bash("git push"), f.ctx);
  assert.equal(f.prompts(), 2);
});

test("missing, invalid and oversized policies block without approval", async t => {
  const f = fixture(t);
  for (const invalid of ["broken", " ".repeat(65537)]) {
    writeFileSync(f.path, invalid);
    assert.ok(!(await f.gate.authorize(bash("git status"), f.ctx)).allowed);
  }
  rmSync(f.path);
  assert.ok(!(await f.gate.authorize(bash("git status"), f.ctx)).allowed);
  assert.equal(f.prompts(), 0);
});

test("policy changes during approval invalidate that approval", async t => {
  const f = fixture(t, askAll);
  f.choose(async () => { f.save(policy); return "Allow once"; });
  assert.ok(!(await f.gate.authorize(bash("git push"), f.ctx)).allowed);
});

test("arguments changing during approval invalidate that approval", async t => {
  const f = fixture(t, askAll);
  const request = { tool: "GitHub/action", input: { name: "original" } };
  f.choose(async () => { request.input.name = "changed"; return "Allow once"; });
  assert.ok(!(await f.gate.authorize(request, f.ctx)).allowed);
});

test("cancellation and revocation during approval fail closed", async t => {
  const f = fixture(t, askAll);
  const controller = new AbortController();
  f.ctx.signal = controller.signal;
  f.choose(async () => { controller.abort(); return "Allow once"; });
  assert.ok(!(await f.gate.authorize(bash("git push"), f.ctx)).allowed);
  f.ctx.signal = undefined;
  f.choose(async () => { f.gate.clear(); return "Allow once"; });
  assert.ok(!(await f.gate.authorize(bash("git push"), f.ctx)).allowed);
});

test("parallel MCP approvals serialize and reuse only exact grants", async t => {
  const f = fixture(t, askAll);
  let active = 0, maxActive = 0;
  f.choose(async () => {
    maxActive = Math.max(maxActive, ++active);
    await new Promise(resolve => setTimeout(resolve, 5));
    active--;
    return "Allow exact action for session";
  });
  const req = { tool: "GitHub/action", input: {} };
  const results = await Promise.all([f.gate.authorize(req, f.ctx), f.gate.authorize(req, f.ctx), f.gate.authorize({ ...req, input: { x: 1 } }, f.ctx)]);
  assert.ok(results.every(r => r.allowed));
  assert.equal(maxActive, 1);
  assert.equal(f.prompts(), 2);
});

test("large approval details block rather than hide arguments", async t => {
  const f = fixture(t, askAll);
  assert.ok(!(await f.gate.authorize(bash("x".repeat(16001)), f.ctx)).allowed);
  assert.equal(f.prompts(), 0);
});

function extensionFixture(t: any) {
  const f = fixture(t);
  const hooks = new Map<string, any>(), commands = new Map<string, any>(), listeners = new Map<string, any>();
  const tools: any[] = [];
  const messages: any[] = [];
  const pi: any = {
    on: (event: string, handler: any) => hooks.set(event, handler),
    events: { on: (event: string, handler: any) => { listeners.set(event, handler); return () => listeners.delete(event); } },
    getAllTools: () => tools,
    registerCommand: (name: string, command: any) => commands.set(name, command),
    sendMessage: (message: any) => messages.push(message),
  };
  const ctx = { ...f.ctx, ui: { ...f.ctx.ui, notify() {}, setStatus() {} } };
  const root = join(f.dir, "source");
  mkdirSync(root);
  registerPermissions(pi, f.dir, root);
  hooks.get("session_start")({}, ctx);
  const call = (toolName: string, input: any) => hooks.get("tool_call")({ toolName, input }, ctx);
  const mcp = async (serverName: string, originalToolName: string, args: any = {}) => {
    let handler: any;
    listeners.get(MCP_APPROVAL_EVENT)({ serverName, originalToolName, args, claim: (fn: any) => { handler = fn; return true; } });
    assert.ok(handler, "broker must claim synchronously");
    return handler();
  };
  return { ...f, ctx, root, hooks, commands, tools, listeners, messages, call, mcp };
}

test("extension protects config/code and symlink aliases, not normal edits", async t => {
  const f = extensionFixture(t);
  f.choose(async () => "Deny");
  assert.equal(await f.call("write", { path: "ordinary.txt", content: "hello" }), undefined);
  for (const path of [f.path, join(f.root, "index.ts"), join(f.dir, "settings.json"), join(f.dir, "extensions/new.ts"), join(f.dir, "mcp.json")]) {
    assert.equal((await f.call("write", { path, content: "hello" })).block, true);
  }
  symlinkSync(f.path, join(f.dir, "alias.json"));
  assert.equal((await f.call("edit", { path: "@alias.json", edits: [] })).block, true);
});

test("MCP uses original server/tool names and broker rejects despite fallback grants", async t => {
  const f = extensionFixture(t);
  assert.equal(await f.mcp("GitHub", "get_me"), "allow_once");
  f.choose(async () => "Deny");
  assert.equal(await f.mcp("GitHub", "create_repository", { name: "example" }), "deny");
  f.save({ permission: { "*": "deny" } });
  assert.equal(await f.mcp("GitHub", "get_me"), "deny");
});

test("adapter surfaces defer to broker, install asks, unrelated lookalikes do not bypass", async t => {
  const f = extensionFixture(t);
  f.choose(async () => "Deny");
  for (const name of ["mcp", "mcp__GitHub", "mcpScript", "GitHub_get_me"]) {
    f.tools.push({ name, sourceInfo: { source: "npm:pi-mcp-adapter@2.34.0" } });
    assert.equal(await f.call(name, name === "mcp" ? { tool: "GitHub_get_me", args: {} } : {}), undefined);
  }
  assert.equal(f.prompts(), 0);
  assert.equal((await f.call("mcp", { action: "install", url: "https://example.com/mcp" })).block, true);
  f.tools.length = 0;
  f.save({ permission: { "mcp__GitHub": "ask" } });
  assert.equal((await f.call("mcp__GitHub", { tool: "get_me" })).block, true);
});

test("commands inspect/clear and tree navigation clear broker grants; shutdown unsubscribes", async t => {
  const f = extensionFixture(t);
  f.choose(async () => "Allow exact action for session");
  await f.mcp("GitHub", "create_repository", { name: "example" });
  await f.mcp("GitHub", "create_repository", { name: "example" });
  assert.equal(f.prompts(), 1);
  await f.commands.get("permissions").handler("", f.ctx);
  assert.match(f.messages[0].content, /Exact-action session approvals: 1/);
  await f.commands.get("permissions").handler("clear", f.ctx);
  await f.mcp("GitHub", "create_repository", { name: "example" });
  f.hooks.get("session_tree")({}, f.ctx);
  await f.mcp("GitHub", "create_repository", { name: "example" });
  assert.equal(f.prompts(), 3);
  f.hooks.get("session_shutdown")({}, f.ctx);
  assert.ok(!f.listeners.has(MCP_APPROVAL_EVENT));
});
