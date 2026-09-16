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

// This is a small shell scanner, not an execution sandbox. It splits ordinary
// command lists outside quotes, recursively checks command/process
// substitutions, ignores comments and heredoc bodies, and leaves the original
// command untouched. Interpreters and wrapper commands remain trust boundaries.
type HereDoc = { delimiter: string; stripTabs: boolean; expand: boolean };

function matchingParen(text: string, open: number): number | undefined {
  let depth = 1;
  let quote: "'" | '"' | "`" | undefined;
  for (let i = open + 1; i < text.length; i++) {
    const char = text[i];
    if (char === "\\" && quote !== "'") { i++; continue; }
    if (quote) {
      if (char === quote) quote = undefined;
      continue;
    }
    if (char === "'" || char === '"' || char === "`") { quote = char; continue; }
    if (char === "(") depth++;
    else if (char === ")" && --depth === 0) return i;
  }
}

function matchingBacktick(text: string, open: number): number | undefined {
  for (let i = open + 1; i < text.length; i++) {
    if (text[i] === "\\") i++;
    else if (text[i] === "`") return i;
  }
}

function heredocAt(text: string, index: number): { doc: HereDoc; end: number } | undefined {
  if (text[index] !== "<" || text[index + 1] !== "<" || text[index + 2] === "<") return;
  let cursor = index + 2;
  const stripTabs = text[cursor] === "-";
  if (stripTabs) cursor++;
  while (text[cursor] === " " || text[cursor] === "\t") cursor++;
  const quote = text[cursor] === "'" || text[cursor] === '"' ? text[cursor++] : undefined;
  const start = cursor;
  if (quote) {
    while (cursor < text.length && text[cursor] !== quote) cursor++;
    if (cursor === text.length || cursor === start) return;
    return { doc: { delimiter: text.slice(start, cursor), stripTabs, expand: false }, end: cursor };
  }
  while (cursor < text.length && !/[ \t\r\n;&|()<>]/.test(text[cursor])) cursor++;
  if (cursor === start) return;
  const raw = text.slice(start, cursor);
  return {
    doc: { delimiter: raw.replace(/\\/g, ""), stripTabs, expand: !raw.includes("\\") },
    end: cursor - 1,
  };
}

function shellExpansions(text: string, commands: string[], depth: number): boolean {
  if (depth > 32) return false;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === "\\") { i++; continue; }
    if (char === "`") {
      const close = matchingBacktick(text, i);
      if (close === undefined || !shellCommands(text.slice(i + 1, close), commands, depth + 1)) return false;
      i = close;
    } else if (char === "$" && text[i + 1] === "(") {
      const open = i + 1;
      const close = matchingParen(text, open);
      if (close === undefined) return false;
      const body = text.slice(open + 1, close);
      if (text[i + 2] === "(") {
        if (!shellExpansions(body, commands, depth + 1)) return false;
      } else if (!shellCommands(body, commands, depth + 1)) return false;
      i = close;
    }
  }
  return true;
}

function skipHeredocs(
  text: string, start: number, docs: HereDoc[], commands: string[], depth: number,
): number | undefined {
  let cursor = start;
  for (const doc of docs) {
    const bodyStart = cursor;
    let found = false;
    while (cursor <= text.length) {
      const lineStart = cursor;
      const newline = text.indexOf("\n", cursor);
      const end = newline < 0 ? text.length : newline;
      const line = text.slice(cursor, end).replace(/\r$/, "");
      if ((doc.stripTabs ? line.replace(/^\t+/, "") : line) === doc.delimiter) {
        if (doc.expand && !shellExpansions(text.slice(bodyStart, lineStart), commands, depth)) return;
        cursor = newline < 0 ? text.length : newline + 1;
        found = true;
        break;
      }
      if (newline < 0) break;
      cursor = newline + 1;
    }
    if (!found) return;
  }
  return cursor;
}

function normalizeShellCommand(command: string): string {
  let result = "", whitespace = false;
  let quote: "'" | '"' | undefined;
  for (let i = 0; i < command.length; i++) {
    const char = command[i];
    if (char === "\\" && quote !== "'") {
      if (whitespace && result) result += " ";
      whitespace = false;
      result += char + (command[++i] ?? "");
      continue;
    }
    if (quote) {
      result += char;
      if (char === quote) quote = undefined;
      continue;
    }
    if (char === "'" || char === '"') {
      if (whitespace && result) result += " ";
      whitespace = false;
      quote = char;
      result += char;
    } else if (char === " " || char === "\t" || char === "\r") whitespace = true;
    else {
      if (whitespace && result) result += " ";
      whitespace = false;
      result += char;
    }
  }
  let normalized = result.trim();
  // Control-flow words introduce a command but are not part of its permission
  // pattern. This also prevents `then sudo ...` from bypassing a sudo rule.
  const control = /^(?:!|then|do|else|elif|if|while|until|time)(?:\s+|$)/;
  while (control.test(normalized)) normalized = normalized.replace(control, "").trimStart();
  return normalized;
}

function shellCommands(text: string, commands: string[], depth = 0): boolean {
  if (depth > 32) return false;
  let start = 0;
  let quote: "'" | '"' | undefined;
  let heredocs: HereDoc[] = [];
  const add = (end: number) => {
    const command = normalizeShellCommand(text.slice(start, end));
    if (command) commands.push(command);
  };

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === "\\" && quote !== "'") { i++; continue; }
    if (quote === "'") {
      if (char === "'") quote = undefined;
      continue;
    }
    if (!quote && char === "'") { quote = "'"; continue; }
    if (char === '"') { quote = quote === '"' ? undefined : '"'; continue; }
    if (quote === '"' && char !== "$" && char !== "`") continue;

    if (
      char === "`"
      || (char === "$" && text[i + 1] === "(")
      || ((char === "<" || char === ">") && text[i + 1] === "(")
    ) {
      if (char === "`") {
        const close = matchingBacktick(text, i);
        if (close === undefined || !shellCommands(text.slice(i + 1, close), commands, depth + 1)) return false;
        i = close;
        continue;
      }
      const open = i + 1;
      const close = matchingParen(text, open);
      if (close === undefined) return false;
      const body = text.slice(open + 1, close);
      // Arithmetic is not a command, but substitutions inside it still are.
      if (char === "$" && text[i + 2] === "(") {
        if (!shellExpansions(body, commands, depth + 1)) return false;
      } else if (!shellCommands(body, commands, depth + 1)) return false;
      i = close;
      continue;
    }

    if (!quote && char === "<") {
      const parsed = heredocAt(text, i);
      if (parsed) { heredocs.push(parsed.doc); i = parsed.end; continue; }
    }
    if (!quote && char === "#" && (i === start || /\s/.test(text[i - 1]))) {
      add(i);
      const newline = text.indexOf("\n", i);
      if (newline < 0) { start = text.length; break; }
      i = newline - 1;
      start = newline;
      continue;
    }
    if (!quote && char === "\n") {
      add(i);
      if (heredocs.length) {
        const next = skipHeredocs(text, i + 1, heredocs, commands, depth);
        if (next === undefined) return false;
        i = next - 1;
        heredocs = [];
        start = next;
      } else start = i + 1;
      continue;
    }
    if (!quote && (char === ";" || char === "|" || char === "&" || char === "(" || char === ")")) {
      // The ampersand in a redirection such as 2>&1 is not a command separator.
      if (char === "&" && (text[i - 1] === ">" || text[i - 1] === "<" || text[i + 1] === ">")) continue;
      add(i);
      if ((char === ";" && text[i + 1] === ";") || (char === "&" && text[i + 1] === "&")
        || (char === "|" && (text[i + 1] === "|" || text[i + 1] === "&"))) i++;
      start = i + 1;
    }
  }
  if (quote || heredocs.length) return false;
  add(text.length);
  return true;
}

export function decideBash(policy: Policy, command: string): Decision {
  if (!command.trim()) return { action: "ask", reason: "Empty shell command" };
  const commands: string[] = [];
  if (!shellCommands(command, commands) || !commands.length) {
    const direct = decide(policy, "bash", [normalizeShellCommand(command)]);
    return { ...direct, reason: `Shell command could not be split; ${direct.reason}` };
  }

  let approval: Decision | undefined;
  for (const parsed of commands) {
    const decision = decide(policy, "bash", [parsed]);
    if (decision.action === "deny") return decision;
    if (decision.action === "ask") approval ??= decision;
  }
  if (approval) return approval;
  return commands.length === 1
    ? decide(policy, "bash", [commands[0]])
    : { action: "allow", reason: `All ${commands.length} parsed shell commands are allowed` };
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
