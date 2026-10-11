# Security and privacy policy

The Workspace Diagnostic Kit is used inside people's working folders, often with an AI agent that can run commands. This page describes the protections built into the kit, what to look out for if you adapt it, and what to do if you find a problem.

**This project is provided as is, as a starting point, and is not actively maintained.** Nobody monitors it for reports, and there is no private reporting channel. You are responsible for reviewing the kit and the scripts before you use them, and for any copy you adapt.

## If you find a problem

- **Fix it in your own copy.** Fork the repository, fix the problem, and consider sharing your fork so others can benefit.
- **Warn other users if it helps.** You can open a public issue so that others who find this repository can see the problem and a fix or workaround. Describe it in general terms, and do not include step-by-step instructions for misusing it.
- **Never share private data.** Do not include real file names, paths, secrets, or other personal data from your own system. Use made-up examples.

Do not expect a response to issues or pull requests.

## What to look out for

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

- Download it from the original repository (https://github.com/invictianimi/workspace-diagnostic) or from a fork you trust.
- The monitor scripts are short and readable. Read them before running them, especially if you got the kit from a fork or anywhere else.
- The skill does not pre-approve any tools (`allowed-tools` is not set in `SKILL.md`), so your AI tool still asks before each command.
