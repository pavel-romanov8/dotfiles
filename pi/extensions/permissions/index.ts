import { getAgentDir, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { registerPermissions } from "./extension.ts";

export default function permissions(pi: ExtensionAPI): void {
  registerPermissions(pi, getAgentDir(), dirname(fileURLToPath(import.meta.url)));
}
