#!/usr/bin/env node
/**
 * PreToolUse hook for app-planner.
 *
 * Blocks any file-writing tool call (Write, Edit, MultiEdit,
 * NotebookEdit) whose path is not:
 *   .ai/runs/<YYYY-MM-DD>-<slug>/plan.md
 *
 * Claude Code invokes this hook before every such tool call
 * spawned by the app-planner subagent. The hook reads the tool input
 * from stdin (JSON), inspects the target path, and exits:
 *   - 0  → allow the tool call
 *   - 2  → block the tool call (stderr is injected back to the model)
 *
 * Path rules:
 *   - Plan path: relative to PROJECT_ROOT, must match
 *     `.ai/runs/<YYYY-MM-DD>-<slug>/plan.md` exactly.
 *   - <slug> is kebab-case ASCII: [a-z0-9][a-z0-9-]*.
 *
 * No other target is allowed. Path containment is checked
 * lexically: `..` segments and paths resolving outside the project
 * root are rejected. Symlinks are not resolved.
 */

import { readFileSync } from "node:fs";
import { resolve, relative, isAbsolute } from "node:path";

const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const PLAN_PATH_REGEX =
  /^\.ai\/runs\/\d{4}-\d{2}-\d{2}-[a-z0-9][a-z0-9-]*\/plan\.md$/;

function block(reason) {
  process.stderr.write(`[validate-plan-write] BLOCKED: ${reason}\n`);
  process.exit(2);
}

function allow() {
  process.exit(0);
}

let payload;
try {
  const raw = readFileSync(0, "utf8");
  payload = JSON.parse(raw);
} catch (err) {
  block(`could not parse hook input: ${err.message}`);
}

const toolName = payload.tool_name || payload.toolName;
const toolInput = payload.tool_input || payload.toolInput || {};

const WRITE_TOOLS = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit"]);

if (!WRITE_TOOLS.has(toolName)) {
  allow();
}

const targetPath = toolInput.file_path || toolInput.notebook_path ||
  toolInput.path || toolInput.filePath;

if (!targetPath || typeof targetPath !== "string") {
  block(`tool ${toolName} called without a string path field`);
}

if (targetPath.split(/[\/\\]/).includes("..")) {
  block(`path contains '..' segment: ${targetPath}`);
}

const absoluteTarget = isAbsolute(targetPath)
  ? resolve(targetPath)
  : resolve(PROJECT_ROOT, targetPath);

const relativeToRoot = relative(PROJECT_ROOT, absoluteTarget);

if (relativeToRoot.startsWith("..") || isAbsolute(relativeToRoot)) {
  block(`path escapes project root: ${targetPath}`);
}

const normalized = relativeToRoot.split("\\").join("/");

if (PLAN_PATH_REGEX.test(normalized)) {
  allow();
}

block(
  `planner may only write to .ai/runs/<YYYY-MM-DD>-<slug>/plan.md, ` +
    `got: ${normalized}`,
);
