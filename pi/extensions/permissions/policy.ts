import { realpathSync } from "node:fs";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";
import { homedir } from "node:os";

export type Action = "allow" | "ask" | "deny";
export type Policy = { permission: Record<string, Action | Record<string, Action>> };
export type Decision = { action: Action; reason: string };
const actions = new Set(["allow", "ask", "deny"]);
const object = (v: unknown): v is Record<string, unknown> =>
  v !== null && typeof v === "object" && !Array.isArray(v);

export function parsePolicy(text: string): Policy {
  if (Buffer.byteLength(text) > 65536) throw new Error("Policy exceeds 64 KiB");
  const data: unknown = JSON.parse(text);
  if (!object(data) || Object.keys(data).some(k => k !== "permission") || !object(data.permission)) {
    throw new Error('Expected { "permission": { ...rules } } with no unknown top-level keys');
  }
  for (const [tool, rule] of Object.entries(data.permission)) {
    if (!tool.trim()) throw new Error("Empty tool pattern");
    if (typeof rule === "string" && actions.has(rule)) continue;
    if (!object(rule) || !Object.keys(rule).length) throw new Error(`Invalid rule for ${tool}`);
    for (const [pattern, action] of Object.entries(rule)) {
      if (!pattern || typeof action !== "string" || !actions.has(action)) {
        throw new Error(`Invalid input rule for ${tool}`);
      }
    }
  }
  return data as Policy;
}

// Anchored, case-sensitive * / ? matching. No regex interpretation or glob deps.
export function matches(pattern: string, value: string): boolean {
  let p = 0, v = 0, star = -1, retry = 0;
  while (v < value.length) {
    if (pattern[p] === "?" || (pattern[p] !== "*" && pattern[p] === value[v])) { p++; v++; }
    else if (pattern[p] === "*") { star = p++; retry = v; }
    else if (star >= 0) { p = star + 1; v = ++retry; }
    else return false;
  }
  while (pattern[p] === "*") p++;
  return p === pattern.length;
}

export function decide(policy: Policy, tool: string, inputs: string[]): Decision {
  let result: Decision = { action: "ask", reason: "No matching rule (default ask)" };
  for (const [pattern, rule] of Object.entries(policy.permission)) {
    if (!matches(pattern, tool)) continue;
    if (typeof rule === "string") result = { action: rule, reason: `${pattern}: ${rule}` };
    else for (const [inputPattern, action] of Object.entries(rule)) {
      const expanded = inputPattern.startsWith("~/") ? homedir() + inputPattern.slice(1) : inputPattern;
      if (inputs.some(input => matches(expanded, input))) {
        result = { action, reason: `${pattern} → ${inputPattern}: ${action}` };
      }
    }
  }
  return result;
}

// Deliberately NOT a general Bash parser. Only unquoted literal words can be
// auto-allowed. Everything else asks. We also inspect flat command lists for
// explicit denials, but never auto-allow a compound command.
const literalCommand = /^[A-Za-z_./][A-Za-z0-9_./:+@%,=-]*(?:[ \t]+[A-Za-z0-9_./:+@%,=-]+)*$/;
function normalizeSimple(command: string): string | undefined {
  if (!literalCommand.test(command) || command.split(/[ \t]/)[0].includes("=")) return;
  return command.replace(/[ \t]+/g, " ");
}

export function decideBash(policy: Policy, command: string): Decision {
  // Do not trim away newlines or other shell constructs before classifying.
  const text = command.replace(/^[ \t]+|[ \t]+$/g, "");
  const simple = normalizeSimple(text);
  const direct = decide(policy, "bash", [simple ?? text]);
  if (direct.action === "deny" || simple !== undefined) return direct;
  const pieces = text.split(/(?:&&|\|\||[;|\n])/).map(s => s.trim());
  if (pieces.length > 1 && pieces.every(s => normalizeSimple(s) !== undefined)) {
    for (const piece of pieces) {
      const decision = decide(policy, "bash", [normalizeSimple(piece)!]);
      if (decision.action === "deny") return decision;
    }
  }
  return { action: "ask", reason: `Complex/unsupported shell syntax; approval required (${direct.reason})` };
}

export function stableJSON(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJSON).join(",")}]`;
  if (object(value)) return `{${Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${stableJSON(value[k])}`).join(",")}}`;
  return JSON.stringify(value) ?? "null";
}

export function absolutePath(path: string, cwd: string): string {
  const stripped = path.startsWith("@") ? path.slice(1) : path;
  const expanded = stripped === "~" ? homedir() : stripped.startsWith("~/") ? homedir() + stripped.slice(1) : stripped;
  return resolve(cwd, expanded);
}

// Resolve existing ancestors too, for a new file inside a symlinked directory.
export function canonicalPath(path: string): string {
  try { return realpathSync(path); }
  catch (error) {
    if (!["ENOENT", "ENOTDIR"].includes((error as NodeJS.ErrnoException).code ?? "")) throw error;
    const parent = dirname(path);
    if (parent === path) return path;
    return resolve(canonicalPath(parent), relative(parent, path));
  }
}

export function within(path: string, root: string): boolean {
  const rel = relative(root, path);
  return rel === "" || (!isAbsolute(rel) && rel !== ".." && !rel.startsWith(`..${sep}`));
}

export function pathInputs(path: string, cwd: string): string[] {
  const abs = absolutePath(path, cwd);
  return [...new Set([relative(cwd, abs), abs, canonicalPath(abs)].map(p => p.split(sep).join("/")))];
}

// Show control characters literally; never let arguments inject terminal escapes.
export function display(text: string): string {
  return text.replace(/[\x00-\x08\x0b-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/g,
    c => `\\u${c.charCodeAt(0).toString(16).padStart(4, "0")}`);
}
