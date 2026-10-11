---
name: workspace-diagnostic
description: Guided, read-only diagnosis of why a local workspace has become slow to work in with an AI agent (slow replies, long start-up, heavy searching, sessions filling up, editor or computer lag). Interviews the user, measures the workspace, optionally records activity while they work, and explains findings in plain language with step-by-step fixes the user applies themselves. Use when the user asks to run the workspace diagnostic or diagnostic kit, or says their workspace, agent, or sessions have become slow. Never changes files to fix anything.
compatibility: Works with any agent that supports Agent Skills and can run shell commands with user approval; can also guide a user who runs commands themselves. Windows (PowerShell 5.1+), Linux, or macOS.
metadata:
  version: "1.0"
---

# Workspace Diagnostic

This skill runs the Workspace Diagnostic Kit. The full instructions are in [workspace-diagnostic-kit.md](workspace-diagnostic-kit.md), in this skill's folder.

## How to start

1. Read `workspace-diagnostic-kit.md` in full before doing anything else.
2. Decide how you were started:
   - **The user started this skill on purpose**, by its name, a slash command such as `/workspace-diagnostic`, or by asking to run the workspace diagnostic or diagnostic kit. Treat that as their yes to interactive mode. Do not ask "Would you like me to start the kit in interactive mode now?" Go straight to "Start-up" in the section "The kit".
   - **You picked this skill yourself** because the user mentioned slowness without asking for the kit. Ask the question from "For the AI agent reading this file" first, and start only if they say yes.
3. From then on, follow "The kit" exactly, including the ground rules: nothing is changed to fix problems, nothing is written without the user's yes twice, and everything is explained in plain language.

## Files in this skill

- `workspace-diagnostic-kit.md`: the kit. It is also usable on its own by agents without skill support.
- `scripts/workspace-monitor.ps1`: the Phase 2 monitor for Windows.
- `scripts/workspace-monitor.sh`: the Phase 2 monitor for Linux and macOS.

The scripts run from this folder. Do not copy or modify them, and do not run them yourself unless the user asks and approves as the kit describes.

The workspace being diagnosed is the folder your session started in, not this skill's folder.
