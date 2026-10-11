# Workspace Diagnostic Kit

**Find out why your workspace has become slow to work in with an AI agent, in plain language, without anything being changed.**

The kit is a set of instructions your AI coding agent follows. It interviews you about the slowness, measures your workspace, can optionally record what happens on your computer while you work, and then explains what it found and gives you step-by-step fixes to apply yourself.

- **Works with any AI agent and any model.** Claude Code, GitHub Copilot, Cursor, OpenAI Codex, Gemini CLI, Windsurf, Cline, Aider, and others.
- **Read-only.** The agent never changes, moves, or deletes your files to fix anything. It only writes reports or recordings when you say yes, twice.
- **Plain language.** Every number comes with what it means and whether it is a problem. Every command is explained before it runs.
- **Two ways to run it.** As a skill with one command, or by asking any agent to read one file.
- **Not tied to one methodology.** It has built-in checks for workspaces that use ICM (Interpretable Context Methodology), and it works with any other folder layout.

> **Status: a starting point, provided as is.** The kit has been designed carefully but not yet tested widely across tools and operating systems. In particular, the Phase 2 monitor scripts have not yet been verified on every platform. **This repository is not actively maintained**: issues and pull requests may not get a response. Review the kit and scripts before you use them, and fork the repository to adapt it to your needs; see [Adapting and contributing](#adapting-and-contributing).

---

## Contents

- [Who this is for](#who-this-is-for)
- [How it works: three phases](#how-it-works-three-phases)
- [Requirements](#requirements)
- [Install and run](#install-and-run)
- [What a session looks like](#what-a-session-looks-like)
- [What you get](#what-you-get)
- [Safety and privacy](#safety-and-privacy)
- [The Phase 2 monitor](#the-phase-2-monitor)
- [Troubleshooting and FAQ](#troubleshooting-and-faq)
- [Known limitations](#known-limitations)
- [Adapting and contributing](#adapting-and-contributing)
- [License](#license)

---

## Who this is for

Anyone who works in a local folder with an AI coding agent and has noticed things getting slower, for example:

- the agent takes a long time before it starts real work
- replies drag, or the agent searches around a lot and gets confused
- sessions fill up or summarize themselves ("compact") often
- you hit usage limits sooner than you used to
- your editor, file explorer, or whole computer lags while you work

You do not need to be technical. The agent explains everything as it goes.

## How it works: three phases

You always start with Phase 1. The other two are only for when you need them.

| Phase | What happens | When to use it |
|---|---|---|
| **1. Check-up** | The agent asks about the problem, measures the workspace once (file counts and sizes, the instruction files your agent reads, settings, add-ons, storage speed), and gives you a report with fix instructions. | Always. Often this is all you need. |
| **2. Watch while you work** | A small script records how busy your computer is, which programs are using it, and which files change, for a time you choose (for example an hour). You mark moments that feel slow. The agent then studies the recording. | Only if Phase 1 recommends it, usually because the slowness comes and goes, builds up over time, or seems to come from outside the workspace (antivirus, cloud sync, indexing, the editor). |
| **3. Follow-up** | After you have applied fixes, the agent repeats the same measurements, compares before and after, and tells you what helped and what is left. | After you have made changes. |

Each phase ends with the agent stopping and waiting for you. You can do each phase in a fresh session; the agent can find the records from earlier sessions if you let it save them.

## Requirements

- An AI coding agent that can read files. Being able to run shell commands is best; if your agent cannot, it gives you the commands to run and you paste back the results.
- Windows (PowerShell 5.1 or later, which comes with Windows 10 and 11), macOS, or Linux.
- For the Phase 2 monitor on Linux: the standard `top` program (procps-ng), which most distributions include.
- No installs, no network access, and no extra software.

## Install and run

First, get the files. Either download this repository as a ZIP from the green **Code** button on GitHub and unzip it, or clone it:

```sh
git clone https://github.com/invictianimi/workspace-diagnostic.git
```

Keep the `workspace-diagnostic` folder together. The kit file, `SKILL.md`, and the `scripts` folder belong together.

Get the kit from this repository or from a fork you trust, and read the two short monitor scripts before running them.

### Option 1: As a skill

Most current AI coding tools support the open [Agent Skills](https://agentskills.io) format. Installing the kit as a skill lets you start it with one command.

**1. Install once.** Copy the whole `workspace-diagnostic` folder into your tool's personal skills folder:

| Tool | Personal skills folder |
|---|---|
| Claude Code | `~/.claude/skills/` (Windows: `C:\Users\<you>\.claude\skills\`) |
| GitHub Copilot in VS Code | `~/.copilot/skills/`, `~/.agents/skills/`, or `~/.claude/skills/` |
| Cursor | `~/.cursor/skills/` or `~/.agents/skills/` |
| Most other tools | `~/.agents/skills/` is the most widely shared location. Check your tool's documentation. |

`~` means your home folder. The result should look like `~/.claude/skills/workspace-diagnostic/SKILL.md`. The folder must be named `workspace-diagnostic`, because the skill's name has to match its folder name.

Use your personal skills folder, not a project's skills folder. A personal install works in every workspace, and it keeps the kit out of the workspace it is measuring.

Tip: if you use several tools, you can install once in `~/.agents/skills/` and create links to it from the other tools' folders instead of keeping several copies.

**2. Run it.** Open your AI agent in the main folder of the workspace you want checked, start a fresh session, and type:

```
/workspace-diagnostic
```

or ask "run the workspace diagnostic". The agent starts the interview right away.

### Option 2: Ask your agent to read the kit

No installing needed. Put the folder anywhere, for example `C:\Tools\workspace-diagnostic` or `~/tools/workspace-diagnostic`.

Open your AI agent in the main folder of the workspace you want checked, start a fresh session, and say:

> Read C:\Tools\workspace-diagnostic\workspace-diagnostic-kit.md

The agent briefly describes the kit and asks whether to start interactive mode. Say yes, and it takes over. If your agent summarizes the file instead of asking, say "start the diagnostic kit in interactive mode".

### Either way

- Start the agent **in the workspace you want checked**. The kit measures the folder your session starts in, not the folder the kit is in.
- Keep the agent in its **normal ask-before-acting mode**. Do not use an auto-approve, "yolo", or bypass mode for this session.
- To come back for Phase 2 or 3 later, start a new session the same way. The agent asks which phase you are on.

## What a session looks like

1. **Start-up.** The agent confirms which folder it will check, and asks which phase you are on.
2. **Briefing.** It tells you what it will do, what it will read, and how this can affect your system, and asks for your go-ahead. Nothing runs before you say yes.
3. **Interview.** A few plain questions at a time: what exactly is slow, when it started, what changed, how you work, what tools and add-ons you use, and whether the folder is in a cloud-sync location.
4. **Plan.** It tells you what it suspects and proposes a short list of checks, each with what it checks and why. You approve the plan.
5. **Checks.** It runs read-only commands, explaining each in a sentence. Your tool may also ask its own permission for each command.
6. **Report.** Findings, fixes, a recommendation about Phase 2, and a baseline record. It offers to save the report to a records folder outside your workspace.
7. **Stop.** It waits for you. You apply whichever fixes you choose, in your own time.

## What you get

The Phase 1 report contains:

- **The short version:** the most likely cause and the one or two things that would help most, in a few sentences.
- **What was checked and what was not**, with reasons.
- **Findings**, most important first, each rated **Big / Medium / Small** for how much it matters and **Sure / Fairly sure / Best guess** for confidence, with the evidence explained in plain words. For example: *"Your main instruction file is about 6,000 tokens, which is roughly 12 pages of text the agent reads before every task. Under about 1,000 is typical, so this is large."*
- **Fix instructions** for each finding, grouped as *Quick and safe*, *Bigger changes*, and *Outside the workspace*. Each fix includes the expected effect, time needed, risk, who does it, what to do first (including backups), numbered steps with ready-to-copy commands for your system, how to check it worked, and how to undo it.
- **Whether you need Phase 2**, with the reason, and whether to do it before or after the fixes.
- **Open questions** the agent could not settle.
- **A baseline record:** every measurement with the exact command used, so the Phase 3 follow-up can compare like with like.

The Phase 2 report adds a timeline of what happened during the recording. The Phase 3 report gives a verdict (**Better / Partly better / No change / Worse**), a before-and-after table, a check of each fix you applied, and what to do next.

### Where records are saved

Only if you agree, reports, baseline records, and recordings are saved in a folder outside your workspace:

- Windows: `C:\Users\<you>\workspace-diagnostics\<workspace-name>\`
- macOS and Linux: `~/workspace-diagnostics/<workspace-name>/`

If your home folder is synced to the cloud, the agent suggests another place. You can delete this folder at any time.

## Safety and privacy

**What the agent will not do.** It will not create, edit, move, rename, or delete anything to fix a problem, change settings, install anything, or run git commands that write. It will not offer to apply fixes. If you ask it to, it reminds you that the session is for diagnosis and gives you the instructions instead.

**What it may write, with your permission.** A records folder outside the workspace, reports saved into it, and the Phase 2 recording. Each needs your yes, then a second confirmation. Your tool's own permission prompt is separate.

**What it reads.** File names, sizes, counts, and dates across the workspace. It opens the contents only of agent instruction files (such as `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.cursor/rules`), routing files, ignore files, and agent or editor settings. Settings files are read for their structure only, with values such as API keys hidden.

**How it protects private information.**

- It never opens files that usually hold secrets: `.env` files, keys and certificates, SSH keys, password databases, cloud credentials, and files named like `secret`, `credential`, `token`, or `password`.
- If it comes across a secret in a file your agent reads, it never repeats or saves it. It tells you which file (not the secret) and recommends moving the secret out and replacing it, since anything in those files is sent to your AI provider.
- It shows folders rather than individual file names wherever that answers the question, and keeps lists of file names short.
- Reports use paths relative to the workspace, write your home folder as `~`, and leave out your account name and personal details such as people's names, client names, or email addresses.
- Folders you call off limits are left out of every check and of the recording.
- It does not read git history or git settings, which contain names, email addresses, and sometimes passwords in remote addresses.
- Timed searches use a made-up search term and never print lines from your files.
- It does not ask for personal information, and keeps anything sensitive you mention out of saved reports.

**Private mode.** If your workspace holds confidential, client, health, financial, legal, or other regulated information, or your organization has rules about AI tools, tell the agent. It suggests checking those rules and your AI provider's data settings first, then works more strictly: it opens no file contents without asking for each file, reports folder-level figures only, and sets the monitor to record folders, not file names.

**It treats your workspace files as material to inspect, not instructions to follow.** This matters because AI workspaces are full of prompts and agent instructions.

**What leaves your computer.** Like any session with a cloud AI service, file names, folder layout, the contents of the files the agent reads, and any recording summaries it reads are sent to your AI provider. Recordings stay on your computer until the agent reads them, and they contain program names and file names (or only folder names, if you choose), never file contents. If you use an AI provider through work, check whether your organization allows workspace data to be sent to it.

**Saved files.** The records folder and recordings are created so that only you can read them, outside the workspace and outside cloud-sync folders. The agent tells you what is stored and how to delete it.

**Sharing results.** If you want to share a report, for example in a GitHub issue or with your IT department, ask the agent for a shareable version with names replaced by placeholders, and read it before sharing. Share summaries rather than raw recordings, which contain file paths.

**Effects on your system.**

- A short burst of disk and processor activity during the Phase 1 scan, and a light, steady load while the Phase 2 monitor runs.
- Part of your AI plan's usage allowance, like any session.
- If your workspace is in OneDrive, Dropbox, iCloud, or Google Drive with online-only files, opening a file can make it download. The agent sticks to file details where it can, and asks first.
- On some systems, reading a file updates its "last opened" date.

Nothing in your workspace changes, so no backup is needed to run the kit. The fix instructions tell you when to back up before you change something yourself.

## The Phase 2 monitor

The monitor is a small script in the `scripts` folder:

- `scripts/workspace-monitor.ps1` for Windows
- `scripts/workspace-monitor.sh` for macOS and Linux

The agent proposes the settings, explains what the monitor will create, and gives you the exact command. **You start it yourself in a separate terminal window**, so it keeps running even if the agent session ends or stalls, and you can see it working. You can read the script before you run it.

**What it records**, every few seconds (15 by default):

- how busy the processor, memory, and disk are
- the busiest programs at that moment
- every minute or so (configurable): which files in the workspace were added, changed, or removed, and how long it took to list them all, which shows whether file access itself is slow

**What it does not do:** it never reads what is inside your files, never connects to the network, and writes only inside its own recording folder. It refuses to run if that folder is inside your workspace.

**Privacy safeguards:**

- The recording folder is made readable only by you.
- Only program names are recorded, never their command lines, which can contain private details.
- Optionally, it records only the first few folder levels of each changed file (for example `outputs/run-12/*`), so no file names are stored. The agent recommends this in private mode.
- The full list of files is kept in memory (Windows) or in a temporary file that is deleted at the end (macOS and Linux). It is only kept if you ask.
- Values in the CSV files are protected so that spreadsheet programs such as Excel do not run them as formulas.
- Keep the notes you type when marking slow moments free of personal details, and delete the recording folder when you no longer need it.

**Marking slow moments.** While you work, run a one-line command (the agent gives it to you, filled in) whenever something feels slow, with a short note such as "agent stalled before first reply". The analysis lines these up with what the computer was doing at that moment.

**Stopping.** It stops on its own when the time is up or if the recording grows past a size limit (50 MB by default). To stop early, press Ctrl+C in its window, or create a file named `STOP` in the recording folder.

**Recording files:**

| File | Contents |
|---|---|
| `meta.txt` | Settings, system details, start and end time, why it stopped |
| `system.csv` | Processor, memory, disk, and load readings |
| `procs.csv` | The busiest programs at each reading |
| `scan.csv` | File count, total size, and how long each file listing took |
| `changes.csv` | Files added, changed, or removed between listings |
| `markers.csv` | The slow moments you marked |
| `snapshot-end.tsv` | The full file list at the end, only if you ask for it |

On Windows, the start command uses `-ExecutionPolicy Bypass`, which lets that single PowerShell window run a script saved on your computer. It does not change any system setting. On macOS, putting `caffeinate -i` in front of the command stops the computer from sleeping during the recording.

## Troubleshooting and FAQ

**The skill does not appear in my tool.**
Check that the folder is named exactly `workspace-diagnostic`, that `SKILL.md` is directly inside it, and that it is in the right skills folder for your tool (see the table above). Some tools only load skills when a new session starts. If it still does not appear, use Option 2.

**The agent summarized the kit instead of starting.**
Say "start the diagnostic kit in interactive mode". Some agents are cautious about following instructions found in files, which is a good habit in general.

**My agent cannot run commands.**
That is fine. It gives you each command with a plain explanation, and you run it and paste back the output.

**The agent says my copy of the kit is incomplete.**
The `scripts` folder is missing. Download the whole repository again and keep the folder together.

**Will the kit fix things for me?**
No, by design. It gives you instructions to follow. This keeps you in control of a workspace you depend on.

**Does it work with local or open-weight models?**
The kit is plain instructions and does not depend on a particular model. How well it works depends on how well your agent and model follow long, multi-step instructions and run shell commands.

**Do I need to use ICM?**
No. ICM checks are applied only if your workspace uses it. For other layouts, the agent asks how your agent is meant to find files, or applies general checks.

**Windows says the script is not digitally signed.**
Use the start command the agent gives you, which includes `-ExecutionPolicy Bypass` for that one window. If your computer is managed by an IT department, scripts may be blocked by policy; ask them, or skip Phase 2.

**Can I delete the records afterwards?**
Yes. Delete the `workspace-diagnostics` folder in your home folder, or just the subfolder for one workspace.

## Known limitations

- **The analysis is done by your AI model,** so its quality depends on the model. The kit asks the agent to label how sure it is about each finding, but treat fix instructions with normal care, especially menu names in settings screens, which differ between program versions.
- **The token estimate is approximate.** Characters divided by four is a rough rule for English text; different models count differently.
- **The monitor cannot see** the AI service's own speed, your network, how full the agent's session is, or usage limits. If your computer was quiet during slow moments, the report says the cause is probably one of these.
- **File changes are detected by comparing file lists,** so a file created and deleted between two listings is not seen.
- **On Linux,** a customized `~/.toprc` that changes `top`'s columns breaks the program readings. File names containing tabs or line breaks are not handled on macOS or Linux.
- **On Windows,** excluded folders are still walked during each listing, so they still cost time.
- **Tool details change.** File names and skill folders for each AI tool are listed in the kit's Appendix A and in this README, and may go out of date.

---

## Adapting and contributing

This repository is a starting point and is not actively maintained. The best way to improve the kit is to **fork it** and adapt it for your own needs or your team's. Pull requests and issues are welcome, but may never be reviewed or answered.

The guidance below is for anyone adapting the kit, so that forks stay safe, consistent, and useful.

### Ways to help

- **Test reports.** Run the kit, and open an issue describing your setup and what happened, so others can see what works. Do not paste raw reports, recordings, file paths, or names you consider private; ask the agent for a shareable version, and read it before posting.
- **Monitor testing.** Run the monitor scripts on your OS version and report whether the readings look right. This is the most needed help right now.
- **Tool coverage.** Add or correct instruction file names, ignore files, and skills folders for AI tools.
- **Methodology modules.** Add checks for other workspace methodologies alongside ICM.
- **Wording.** Make instructions clearer or plainer.

### Repository layout

```
workspace-diagnostic/
├── SKILL.md                      Skill entry point (Agent Skills format). Short; points to the kit.
├── workspace-diagnostic-kit.md   The kit: all instructions the agent follows. Usable on its own.
├── README.md                     This file.
├── SECURITY.md                   Built-in protections, and what to do if you find a problem.
├── LICENSE                       MIT license.
├── .gitattributes                Keeps the shell script's line endings correct.
├── .gitignore                    Stops recordings and reports from being committed by accident.
└── scripts/
    ├── workspace-monitor.ps1     Phase 2 monitor for Windows (PowerShell 5.1+).
    └── workspace-monitor.sh      Phase 2 monitor for macOS and Linux (POSIX sh).
```

The repository root is the skill folder, so a clone or download can be installed as a skill directly.

### How the kit file is organized

| Section | Purpose |
|---|---|
| For the AI agent reading this file | The launch handshake: offer interactive mode, start only on yes. |
| For people: how to use this kit | Short human instructions and the safety summary. |
| The kit → How the kit works, Start-up | Phases, records folder, finding the workspace, choosing a phase. |
| Ground rules | Read-only rules, the two-step approval, conduct, and the plain-language rules. |
| How to write fix instructions | The fix template every phase uses. |
| Phase 1, Phase 2, Phase 3 | Step-by-step instructions for each phase. |
| Appendix A | Instruction, configuration, and ignore files by AI tool. |
| Appendix B | Methodology modules (generic, ICM). |
| Appendix C | Monitor output files, marker and start commands, limits. |
| Appendix D | Plain-language explanations of technical terms. |

### Design principles

Please keep changes consistent with these. They are what make the kit trustworthy.

1. **Universal.** No dependence on a particular model, vendor, or tool. Tool-specific details belong in tables (Appendix A, the README) with examples, never as assumptions in the instructions. Do not rely on features only one tool has.
2. **Read-only and user in control.** The agent never applies fixes and never offers to. Anything that writes goes through the two-step approval. Do not add steps that weaken this.
3. **Plain language.** Write for someone who is not technical. Short sentences, everyday words, technical terms explained on first use, every number given a meaning.
4. **One source of truth.** Instructions live in `workspace-diagnostic-kit.md`. `SKILL.md` stays a thin pointer. The monitor scripts live only in `scripts/`.
5. **No dependencies.** The scripts use only what ships with the operating system: no installs, no network, no Python or other runtimes.
6. **Metadata, not contents.** The kit and the monitor work from file names, sizes, and dates. Opening file contents is limited to instruction, routing, ignore, and settings files.
7. **Collect as little as possible.** Never open files that usually hold secrets, read settings files with values hidden, prefer folders over file names, keep personal details out of reports and recordings, and keep anything saved private to the user and easy to delete. New checks must follow "Protecting private information" in the kit.
8. **Honest about certainty.** Findings say whether they are measured or inferred. Thresholds are presented as rules of thumb.

### Writing style for the kit

- Address the agent directly ("Ask the user...", "Do not..."). Refer to the person as "the user".
- Instructions the agent shows the user (such as fix steps) address the user directly ("Open...", "Copy this command...").
- One instruction per sentence where possible. Prefer lists to long paragraphs.
- Keep ratings consistent: Big / Medium / Small, Sure / Fairly sure / Best guess, Better / Partly better / No change / Worse.
- If you add a technical term the user will see, add it to Appendix D.

### Changing the monitor scripts

- Keep both scripts producing the **same files with the same columns** (see Appendix C). Leave a column empty when a platform cannot provide it, rather than changing the layout.
- Keep the safety checks: refuse an output folder inside the workspace, refuse to reuse a folder with data, write only inside the output folder, and stop on time, size cap, `STOP` file, or Ctrl+C.
- Windows: stay compatible with Windows PowerShell 5.1 (no `??`, ternaries, or other 7-only syntax). Avoid performance counter names, which are translated on non-English Windows; use the CIM classes as the script does.
- macOS and Linux: stay POSIX `sh` (no bash-only features), and use only tools present by default.
- The shell script must keep LF line endings. `.gitattributes` enforces this; do not override it.
- Update Appendix C and the README if you change outputs, options, or limits.

**Manual test checklist** (please include your results in the pull request):

1. Run for 3 to 5 minutes against a small test folder, with an output folder outside it.
2. While it runs, add, edit, and delete a few files in the test folder, and add one marker.
3. Check that `system.csv` and `procs.csv` have a row every interval with sensible values, `changes.csv` shows your edits, and `markers.csv` has your marker.
4. Stop it early once with a `STOP` file and once with Ctrl+C. Check that `meta.txt` records the end time and stop reason, and that no file list (`snapshot-end.tsv` or `.snap.*`) is left behind. Repeat with the keep-file-list option and check that `snapshot-end.tsv` is kept.
5. Run with a path depth of 2 and check that `changes.csv` contains only folder paths ending in `*`, with no file names.
6. Check that the output folder is readable only by you: `ls -ld` on macOS and Linux (should show `drwx------`), or `icacls <folder>` on Windows (only your account and SYSTEM).
7. Create a test file whose name starts with `=`, and check that its `changes.csv` entry starts with `'`, so a spreadsheet will not treat it as a formula.
8. Check that it refuses an output folder inside the workspace and an output folder that already holds data.
9. State your OS and version, and your shell or PowerShell version.

### Changing SKILL.md

- Follow the [Agent Skills specification](https://agentskills.io/specification): `name` must stay `workspace-diagnostic` and match the folder name; `description` must stay under 1024 characters.
- Validate with the reference tool if you can: `skills-ref validate ./workspace-diagnostic`.
- Bump `metadata.version` in `SKILL.md` when behavior changes.

### Testing changes to the kit

There is no automated test suite; the kit is instructions, so testing means running it. Before opening a pull request that changes the kit:

1. Run Phase 1 in at least one AI tool against a real or test workspace, starting it both ways (skill and "read the file") if your change affects start-up.
2. Check that the agent still asks before every command, never offers to apply fixes, and explains things plainly.
3. Mention which tool, model, and OS you tested with.

### Sharing changes back

Pull requests may not be reviewed or merged. If you still want to offer one:

1. Fork the repository and create a branch for your change.
2. Keep each pull request focused on one change.
3. Describe what you changed, why, and how you tested it.
4. By contributing, you agree that your contribution is licensed under the MIT license.

### If you find a security or privacy problem

If you find a way the kit could lead an agent to change or delete files, expose secrets or personal data, or act without the user's approval, fix it in your copy and consider sharing the fix. You can open a public issue to warn others, described in general terms and without step-by-step instructions for misuse. See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE). Use it, change it, and share it, with attribution.
