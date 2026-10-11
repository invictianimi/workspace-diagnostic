# Security and privacy policy

The Workspace Diagnostic Kit is used inside people's working folders, often with an AI agent that can run commands. Problems that could lead to data being changed, exposed, or sent somewhere unexpected are treated as the highest priority.

## Reporting a vulnerability

**Please do not report security problems in public issues.**

Report them privately through GitHub: go to the repository's **Security** tab and choose **Report a vulnerability**. This opens a private advisory that only the maintainers can see.

Please include:

- what the problem is, and what could happen as a result
- the steps or conditions that trigger it, described in general terms
- the AI tool, model, and operating system involved, if relevant

Please do not include real file names, paths, secrets, or other personal data from your own system. Use made-up examples.

Reports are acknowledged as soon as possible, fixes are released as soon as practical, and reporters are credited unless they ask not to be.

## What counts as a security or privacy problem

- The kit leading an agent to create, change, move, or delete files, or change settings, without the user's explicit approval
- The kit leading an agent to open or send secrets (passwords, keys, tokens) or personal data that the rules say it should not
- The monitor scripts writing outside their output folder, reading file contents, using the network, or recording more than documented
- Files created by the kit or monitor being readable by other users of the computer
- Instructions in workspace files or recordings being able to take over the agent's behavior despite the kit's rules (prompt injection)
- Fix instructions in the kit's templates that could lead users into unsafe actions

## What the kit does to protect users

- **Read-only by design.** The agent never applies fixes. Anything that writes needs the user's yes twice.
- **Data minimization.** Files that usually hold secrets are never opened. Settings files are read for their structure, with values hidden. Reports show folders rather than file names where possible and leave out personal details. A private mode applies stricter rules for confidential or regulated workspaces.
- **Local, private storage.** Records and recordings go in a folder outside the workspace that only the user can read. Nothing is uploaded except what the user's own AI agent sends to its provider as part of the conversation.
- **Minimal recordings.** The monitor records program names (never command lines) and file metadata (never contents), can record folders only, and deletes its full file list at the end unless asked to keep it.
- **No dependencies.** The scripts use only what ships with the operating system: no downloads, no installs, and no network use.

## Getting the kit safely

- Download it only from the official repository: https://github.com/invictianimi/workspace-diagnostic
- The monitor scripts are short and readable. Read them before running them, especially if you got the kit from anywhere else.
- The skill does not pre-approve any tools (`allowed-tools` is not set in `SKILL.md`), so your AI tool still asks before each command.
