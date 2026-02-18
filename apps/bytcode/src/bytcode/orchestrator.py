"""Phase-loop orchestrator: runs Claude per phase with streaming output."""

import asyncio
import io
import json
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Callable, TextIO

from .codebase import init_architecture, write_structure
from .config import PHASES, Phase, PhaseType, WorkflowConfig
from .prompts import build_prompt
from .verify import verify_phase

import re


def _extract_section(markdown: str, heading: str) -> str:
    """Extract content under a ## heading, stopping at the next ## heading."""
    pattern = rf"^##\s+{re.escape(heading)}\s*$"
    lines = markdown.splitlines()
    start = None
    for i, line in enumerate(lines):
        if re.match(pattern, line, re.IGNORECASE):
            start = i + 1
            break
    if start is None:
        return ""
    result: list[str] = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        result.append(line)
    # Strip leading/trailing blank lines
    text = "\n".join(result).strip()
    return text


class PhaseStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    PASSED = "passed"
    FAILED = "failed"
    AWAITING_APPROVAL = "awaiting_approval"


@dataclass
class PhaseResult:
    phase: Phase
    status: PhaseStatus
    message: str = ""
    attempts: int = 0
    duration_s: float = 0.0


OutputCallback = Callable[[str], None]
PhaseCallback = Callable[[int, PhaseStatus], None]
ActivityCallback = Callable[[str], None]    # short activity string for sidebar
LiveLogCallback = Callable[[str], None]     # detailed tool activity for live-log panel
SummaryCallback = Callable[[str, str], None]  # (title, markdown) for summary panel


class PhaseLog:
    """Manages transcript (.md) and raw (.jsonl) log files for a phase."""

    def __init__(self, logs_dir: Path, phase_num: int, agent_name: str):
        self.transcript_path = logs_dir / f"phase-{phase_num}-{agent_name}.md"
        self.jsonl_path = logs_dir / f"phase-{phase_num}-{agent_name}.jsonl"
        self._transcript: TextIO | None = None
        self._jsonl: TextIO | None = None

    def open(self, attempt: int) -> None:
        """Open log files. Append mode so retries accumulate."""
        mode = "a" if attempt > 1 else "w"
        self._transcript = open(self.transcript_path, mode, encoding="utf-8")
        self._jsonl = open(self.jsonl_path, mode, encoding="utf-8")
        if attempt > 1:
            self._transcript.write(f"\n\n---\n\n## Attempt {attempt}\n\n")

    def close(self) -> None:
        if self._transcript:
            self._transcript.close()
            self._transcript = None
        if self._jsonl:
            self._jsonl.close()
            self._jsonl = None

    def write_raw(self, line: str) -> None:
        """Write a raw stream-json line to the JSONL file."""
        if self._jsonl:
            self._jsonl.write(line + "\n")
            self._jsonl.flush()

    def write_transcript(self, text: str) -> None:
        """Write a line to the human-readable transcript."""
        if self._transcript:
            self._transcript.write(text + "\n")
            self._transcript.flush()

    def write_header(
        self, phase_num: int, phase_name: str, agent: str, attempt: int
    ) -> None:
        if not self._transcript:
            return
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self._transcript.write(
            f"# Phase {phase_num}: {phase_name}\n"
            f"Agent: {agent}\n"
            f"Started: {ts}\n"
            f"Attempt: {attempt}\n\n"
        )
        self._transcript.flush()

    def write_tool_call(self, tool: str, activity: str) -> None:
        if self._transcript:
            self._transcript.write(f"**[{tool}]** {activity}\n")
            self._transcript.flush()

    def write_agent_text(self, text: str) -> None:
        if self._transcript:
            self._transcript.write(f"\n{text}\n\n")
            self._transcript.flush()

    def write_result(self, cost: float, duration_ms: int, turns: int) -> None:
        if self._transcript:
            self._transcript.write(
                f"\n---\n"
                f"Cost: ${cost:.4f} | "
                f"Duration: {duration_ms / 1000:.1f}s | "
                f"Turns: {turns}\n"
            )
            self._transcript.flush()

    def write_verification(self, passed: bool, message: str) -> None:
        if self._transcript:
            status = "PASSED" if passed else "FAILED"
            self._transcript.write(f"\n**Verification {status}:** {message}\n")
            self._transcript.flush()


class Orchestrator:
    """Runs the bytA workflow: phase loop with Ralph-Loop retries."""

    MAX_RETRIES = 3

    def __init__(
        self,
        config: WorkflowConfig,
        project_dir: Path,
        *,
        on_output: OutputCallback | None = None,
        on_phase_change: PhaseCallback | None = None,
        on_activity: ActivityCallback | None = None,
        on_live_log: LiveLogCallback | None = None,
        on_summary: SummaryCallback | None = None,
    ):
        self.config = config
        self.project_dir = project_dir
        self.on_output = on_output
        self.on_phase_change = on_phase_change
        self.on_activity = on_activity
        self.on_live_log = on_live_log
        self.on_summary = on_summary
        self.results: dict[int, PhaseResult] = {}
        self.abort_reason: str | None = None
        self.phase_start_time: float = 0.0
        self._cancelled = False
        self._current_process: asyncio.subprocess.Process | None = None
        self._current_log: PhaseLog | None = None
        self._logs_dir = project_dir / ".workflow" / "logs"

    def cancel(self) -> None:
        self._cancelled = True
        if self._current_process and self._current_process.returncode is None:
            self._current_process.terminate()

    async def run(self, resume_from: int = 0) -> PhaseResult | None:
        """Run all phases sequentially. Returns PhaseResult if waiting for approval.

        If resume_from > 0, skip phases below that number (they already passed).
        """
        self._ensure_workflow_dir()

        if resume_from == 0:
            # Fresh start: clean workflow state but preserve architecture context
            self._clean_workflow_state()
            self._ensure_workflow_dir()  # Re-create dirs after cleanup

            ok = await self._fetch_issue()
            if not ok:
                self.abort_reason = "GitHub Issue could not be loaded."
                return None

            self._write_initial_state()

            ok = await self._setup_branch()
            if not ok:
                self.abort_reason = "Git branch setup failed."
                return None
        else:
            # Resume: load existing state, skip branch setup
            self._load_existing_state()
            self._emit(f"[bold]Resuming workflow from Phase {resume_from}[/]")

        for phase in PHASES:
            if self._cancelled:
                break

            if phase.number < resume_from:
                self._emit(f"[dim]  Skipping Phase {phase.number}: {phase.name} (already passed)[/]")
                self.results[phase.number] = PhaseResult(
                    phase, PhaseStatus.PASSED, "Skipped (resume)", 0
                )
                self._notify_phase(phase.number, PhaseStatus.PASSED)
                continue

            result = await self._run_phase(phase)
            self.results[phase.number] = result
            self._persist_phase_status(phase.number, result)

            if result.status == PhaseStatus.FAILED:
                self._emit(
                    f"\n--- Phase {phase.number} failed after "
                    f"{result.attempts} attempt(s): {result.message}"
                )
                break

            if result.status == PhaseStatus.AWAITING_APPROVAL:
                return result

        return None

    async def resume_after_approval(
        self,
        from_phase: int,
        *,
        approved: bool = True,
        feedback: str = "",
    ) -> PhaseResult | None:
        """Resume workflow after user approval/feedback at an APPROVAL phase."""
        if not approved:
            self._emit(f"\nUser feedback: {feedback}")
            phase = PHASES[from_phase]
            result = await self._run_phase(
                phase, extra_context=f"User feedback on your output: {feedback}"
            )
            self.results[phase.number] = result
            self._persist_phase_status(phase.number, result)
            if result.status in (PhaseStatus.FAILED, PhaseStatus.AWAITING_APPROVAL):
                return result
        else:
            # Mark approved phase as passed
            self._persist_phase_status(
                from_phase,
                self.results.get(from_phase, PhaseResult(PHASES[from_phase], PhaseStatus.PASSED)),
            )

        start = from_phase + 1
        for phase in PHASES[start:]:
            if self._cancelled:
                break

            result = await self._run_phase(phase)
            self.results[phase.number] = result
            self._persist_phase_status(phase.number, result)

            if result.status == PhaseStatus.FAILED:
                self._emit(
                    f"\n--- Phase {phase.number} failed: {result.message}"
                )
                break

            if result.status == PhaseStatus.AWAITING_APPROVAL:
                return result

        return None

    async def _run_phase(
        self, phase: Phase, extra_context: str = ""
    ) -> PhaseResult:
        # Regenerate codebase context before each phase
        self._update_codebase_context()

        self.phase_start_time = time.monotonic()
        self._notify_phase(phase.number, PhaseStatus.RUNNING)
        self._emit(f"\n{'=' * 60}")
        self._emit(f"  Phase {phase.number}: {phase.name} ({phase.agent})")
        self._emit(f"{'=' * 60}\n")

        # Create phase log
        phase_log = PhaseLog(self._logs_dir, phase.number, phase.agent)
        self._current_log = phase_log

        last_failure: str = ""  # Carries verification error to next attempt

        for attempt in range(1, self.MAX_RETRIES + 1):
            if self._cancelled:
                elapsed = time.monotonic() - self.phase_start_time
                phase_log.close()
                self._current_log = None
                return PhaseResult(phase, PhaseStatus.FAILED, "Cancelled", attempt, elapsed)

            if self.MAX_RETRIES > 1:
                self._emit(f"--- Attempt {attempt}/{self.MAX_RETRIES}")

            # Open log files (append on retries)
            phase_log.open(attempt)
            phase_log.write_header(phase.number, phase.name, phase.agent, attempt)

            prompt = build_prompt(
                phase, self.config, self.project_dir
            )
            if extra_context:
                prompt += f"\n\n## Additional Context\n{extra_context}"

            # On retry: inject the verification error so the agent knows what went wrong
            if last_failure:
                prompt += (
                    f"\n\n## RETRY — Previous Attempt Failed\n"
                    f"This is attempt {attempt}/{self.MAX_RETRIES}. "
                    f"The previous attempt failed verification:\n\n"
                    f"**Error:** {last_failure}\n\n"
                    f"Fix this issue before completing your work. "
                    f"Make sure all required output files are written."
                )

            success = await self._run_claude(phase, prompt)

            if not success:
                last_failure = "Claude process exited with non-zero exit code"
                self._emit(f"--- Claude process failed (attempt {attempt})")
                phase_log.write_verification(False, "Claude process failed")
                phase_log.close()
                continue

            ok, msg = verify_phase(phase, self.project_dir)
            phase_log.write_verification(ok, msg)

            if ok:
                elapsed = time.monotonic() - self.phase_start_time
                self._emit(f"\n  Verification passed: {msg} ({elapsed:.0f}s)")
                phase_log.close()
                self._current_log = None

                # Show summaries after phase completion
                if phase.number == 0:
                    self._show_plan_summary()
                elif phase.number == 7:
                    self._show_pr_draft()
                elif phase.number != 8:
                    self._show_phase_summary(phase)

                if phase.phase_type == PhaseType.APPROVAL:
                    self._notify_phase(phase.number, PhaseStatus.AWAITING_APPROVAL)
                    return PhaseResult(
                        phase, PhaseStatus.AWAITING_APPROVAL, msg, attempt, elapsed
                    )
                self._notify_phase(phase.number, PhaseStatus.PASSED)
                return PhaseResult(phase, PhaseStatus.PASSED, msg, attempt, elapsed)

            last_failure = msg
            self._emit(f"\n  Verification failed: {msg}")
            phase_log.close()

        self._current_log = None
        total_elapsed = time.monotonic() - self.phase_start_time
        self._notify_phase(phase.number, PhaseStatus.FAILED)
        return PhaseResult(
            phase, PhaseStatus.FAILED, "Max retries exceeded", self.MAX_RETRIES, total_elapsed
        )

    async def _run_claude(self, phase: Phase, prompt: str) -> bool:
        """Invoke claude -p with stream-json output for live activity."""
        tools = ",".join(phase.tools)
        cmd = [
            "claude",
            "-p",
            prompt,
            "--tools",
            tools,
            "--output-format",
            "stream-json",
            "--verbose",
            "--dangerously-skip-permissions",
        ]
        if phase.model:
            cmd.extend(["--model", phase.model])
        if phase.max_turns > 0:
            cmd.extend(["--max-turns", str(phase.max_turns)])

        env: dict[str, str] = {"CLAUDECODE": ""}  # Prevent nested-session error

        try:
            import os
            run_env = {**os.environ, **env}

            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(self.project_dir),
                env=run_env,
                limit=4 * 1024 * 1024,  # 4 MB line buffer (stream-json events can be large)
            )
            self._current_process = process

            if process.stdout:
                async for line in process.stdout:
                    text = line.decode("utf-8", errors="replace").rstrip()
                    if not text:
                        continue
                    # Write raw line to JSONL log
                    if self._current_log:
                        self._current_log.write_raw(text)
                    self._process_stream_event(text)

            await process.wait()
            self._current_process = None

            if process.returncode != 0:
                if process.stderr:
                    stderr = await process.stderr.read()
                    err = stderr.decode("utf-8", errors="replace").strip()
                    if err:
                        self._emit_live(f"[dim red]stderr: {err}[/]")
                return False

            return True

        except FileNotFoundError:
            self._emit("Error: 'claude' CLI not found in PATH")
            return False
        except Exception as e:
            self._emit(f"Error: {e}")
            return False

    def _process_stream_event(self, raw_line: str) -> None:
        """Parse a stream-json line and emit human-readable activity."""
        try:
            event = json.loads(raw_line)
        except json.JSONDecodeError:
            return

        event_type = event.get("type", "")
        log = self._current_log

        if event_type == "assistant":
            message = event.get("message", {})
            content_blocks = message.get("content", [])
            for block in content_blocks:
                block_type = block.get("type", "")

                if block_type == "tool_use":
                    tool_name = block.get("name", "?")
                    tool_input = block.get("input", {})
                    activity = self._format_tool_activity(tool_name, tool_input)
                    self._emit_live(f"[cyan]  [{tool_name}][/] {activity}")
                    self._notify_activity(f"{tool_name}")
                    if log:
                        log.write_tool_call(tool_name, activity)

                elif block_type == "text":
                    text = block.get("text", "")
                    if text.strip():
                        import textwrap
                        # Show first 300 chars of agent text, word-wrapped
                        preview = text.strip()[:300]
                        if len(text.strip()) > 300:
                            preview += " ..."
                        wrapped = textwrap.fill(preview, width=76, initial_indent="  ", subsequent_indent="  ")
                        self._emit_live(f"[dim]{wrapped}[/]")
                        # Write full text to transcript (not truncated)
                        if log:
                            log.write_agent_text(text.strip())

        elif event_type == "result":
            cost = event.get("total_cost_usd", 0)
            duration = event.get("duration_ms", 0)
            turns = event.get("num_turns", 0)
            if cost or duration:
                self._emit_live(
                    f"[dim]  Cost: ${cost:.4f} | "
                    f"Duration: {duration / 1000:.1f}s | "
                    f"Turns: {turns}[/]"
                )
                if log:
                    log.write_result(cost, duration, turns)
            self._notify_activity("")

    def _format_tool_activity(self, tool: str, inp: dict) -> str:
        """Format a short description of a tool call."""
        if tool == "Read":
            path = inp.get("file_path", "")
            return _short_path(path)
        elif tool == "Write":
            path = inp.get("file_path", "")
            return _short_path(path)
        elif tool == "Edit":
            path = inp.get("file_path", "")
            return _short_path(path)
        elif tool == "Glob":
            return inp.get("pattern", "")
        elif tool == "Grep":
            pattern = inp.get("pattern", "")
            return f'"{pattern}"'
        elif tool == "Bash":
            cmd = inp.get("command", "")
            # Show first 80 chars of command
            if len(cmd) > 80:
                cmd = cmd[:77] + "..."
            return cmd
        elif tool == "Task":
            return inp.get("description", "subagent")
        return ""

    async def _fetch_issue(self) -> bool:
        """Fetch GitHub issue and persist to .workflow/issue.json."""
        issue_num = self.config.issue_num
        self._emit(f"Fetching GitHub issue #{issue_num}...")

        try:
            proc = await asyncio.create_subprocess_exec(
                "gh", "issue", "view", str(issue_num),
                "--json", "number,title,body,labels,assignees,state,url",
                cwd=str(self.project_dir),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout_raw = await proc.stdout.read() if proc.stdout else b""
            stderr_raw = await proc.stderr.read() if proc.stderr else b""
            await proc.wait()

            if proc.returncode != 0:
                err = stderr_raw.decode("utf-8", errors="replace").strip()
                self._emit(f"[ERROR] Could not fetch issue #{issue_num}: {err}")
                self._emit("Is 'gh' installed and authenticated? Does the issue exist?")
                return False

            issue_data = json.loads(stdout_raw.decode("utf-8"))

            if not issue_data.get("title"):
                self._emit(f"[ERROR] Issue #{issue_num} has no title — does it exist?")
                return False

            # Reject pull requests — only issues are valid
            issue_url = issue_data.get("url", "")
            if "/pull/" in issue_url:
                self._emit(f"[ERROR] #{issue_num} is a Pull Request, not an Issue.")
                self._emit(f"URL: {issue_url}")
                self._emit("bytcode only works with GitHub Issues.")
                return False

            # Persist to disk
            issue_file = self.project_dir / ".workflow" / "issue.json"
            issue_file.write_text(
                json.dumps(issue_data, indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )

            # Store title in config for state file
            self.config.issue_title = issue_data["title"]

            title = issue_data["title"]
            labels = ", ".join(l["name"] for l in issue_data.get("labels", []))
            state = issue_data.get("state", "")
            self._emit(f"Issue #{issue_num}: {title}")
            if labels:
                self._emit(f"Labels: {labels}")
            if state and state != "OPEN":
                self._emit(f"[WARN] Issue state: {state}")
            self._emit(f"Persisted to .workflow/issue.json")

            return True

        except FileNotFoundError:
            self._emit("[ERROR] 'gh' CLI not found in PATH")
            self._emit("Install: https://cli.github.com/")
            return False
        except json.JSONDecodeError as e:
            self._emit(f"[ERROR] Failed to parse issue JSON: {e}")
            return False
        except Exception as e:
            self._emit(f"[ERROR] Unexpected error fetching issue: {e}")
            return False

    async def _setup_branch(self) -> bool:
        """Checkout from_branch and create feature branch."""
        cfg = self.config
        branch_name = f"feature/issue-{cfg.issue_num}"

        self._emit(f"Setting up branch: {branch_name} (from {cfg.from_branch})")

        try:
            # Fetch latest
            proc = await asyncio.create_subprocess_exec(
                "git", "fetch", "--prune",
                cwd=str(self.project_dir),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await proc.wait()

            # Checkout base branch
            proc = await asyncio.create_subprocess_exec(
                "git", "checkout", cfg.from_branch,
                cwd=str(self.project_dir),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await proc.wait()
            if proc.returncode != 0:
                stderr = await proc.stderr.read() if proc.stderr else b""
                self._emit(f"Failed to checkout {cfg.from_branch}: {stderr.decode()}")
                return False

            # Create feature branch
            proc = await asyncio.create_subprocess_exec(
                "git", "checkout", "-b", branch_name,
                cwd=str(self.project_dir),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await proc.wait()
            if proc.returncode != 0:
                # Branch might already exist, try switching to it
                proc = await asyncio.create_subprocess_exec(
                    "git", "checkout", branch_name,
                    cwd=str(self.project_dir),
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
                await proc.wait()
                if proc.returncode != 0:
                    stderr = await proc.stderr.read() if proc.stderr else b""
                    self._emit(f"Failed to create/switch to {branch_name}: {stderr.decode()}")
                    return False
                self._emit(f"Switched to existing branch: {branch_name}")
            else:
                self._emit(f"Created branch: {branch_name}")

            return True

        except Exception as e:
            self._emit(f"Git error: {e}")
            return False

    def _write_initial_state(self) -> None:
        """Write workflow-state.json with startup configuration."""
        cfg = self.config
        state = {
            "workflow": "bytcode",
            "status": "active",
            "issue": {
                "number": cfg.issue_num,
                "title": cfg.issue_title,
            },
            "branch": f"feature/issue-{cfg.issue_num}",
            "fromBranch": cfg.from_branch,
            "targetCoverage": cfg.target_coverage,
            "uiDesigner": cfg.ui_designer,
            "scope": cfg.scope.value,
            "currentPhase": 0,
            "startedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "phases": {},
            "context": {},
        }
        state_file = self.project_dir / ".workflow" / "workflow-state.json"
        state_file.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        self._emit(f"Wrote {state_file.relative_to(self.project_dir)}")

    def _persist_phase_status(self, phase_num: int, result: PhaseResult) -> None:
        """Write phase result to workflow-state.json for resume capability."""
        state_file = self.project_dir / ".workflow" / "workflow-state.json"
        if not state_file.exists():
            return

        try:
            state = json.loads(state_file.read_text(encoding="utf-8"))
            state.setdefault("phases", {})
            status_str = result.status.value
            if result.status == PhaseStatus.AWAITING_APPROVAL:
                status_str = "passed"  # approval phases that reach here are done
            state["phases"][str(phase_num)] = {
                "status": status_str,
                "agent": result.phase.agent,
                "attempts": result.attempts,
            }
            state["currentPhase"] = phase_num
            state_file.write_text(
                json.dumps(state, indent=2) + "\n", encoding="utf-8"
            )
        except Exception:
            pass  # Non-critical, don't fail the workflow

    def _load_existing_state(self) -> None:
        """Load config from existing workflow-state.json for resume."""
        state_file = self.project_dir / ".workflow" / "workflow-state.json"
        if not state_file.exists():
            return

        try:
            state = json.loads(state_file.read_text(encoding="utf-8"))
            self.config.issue_title = state.get("issue", {}).get("title", "")
        except Exception:
            pass

    def _ensure_workflow_dir(self) -> None:
        wf_dir = self.project_dir / ".workflow" / "specs"
        wf_dir.mkdir(parents=True, exist_ok=True)
        self._logs_dir.mkdir(parents=True, exist_ok=True)

    def _clean_workflow_state(self) -> None:
        """Remove workflow-specific files but preserve persistent context.

        Preserved: .workflow/context/architecture.md (agent-maintained knowledge)
        Deleted:   workflow-state.json, issue.json, specs/*, logs/*
        """
        import shutil

        wf_dir = self.project_dir / ".workflow"
        if not wf_dir.exists():
            return

        # Delete workflow-specific files
        for f in ("workflow-state.json", "issue.json"):
            path = wf_dir / f
            if path.exists():
                path.unlink()

        # Clear specs and logs directories (but keep the dirs)
        for subdir in ("specs", "logs"):
            path = wf_dir / subdir
            if path.exists():
                shutil.rmtree(path)

        # context/architecture.md is preserved (agent-maintained knowledge)
        # context/structure.md is preserved (regenerated before each phase anyway)

    def _show_plan_summary(self) -> None:
        """Send Executive Summary as markdown to the summary panel."""
        specs_dir = self.project_dir / ".workflow" / "specs"
        if not specs_dir.exists():
            return

        plan_files = list(specs_dir.glob("*plan-consolidated.md"))
        if not plan_files:
            return

        spec_content = plan_files[0].read_text(encoding="utf-8", errors="replace")

        # Try to extract ## Executive Summary section
        summary = _extract_section(spec_content, "Executive Summary")
        heading = "Executive Summary"

        # Fallback: try ## Architecture Overview
        if not summary:
            summary = _extract_section(spec_content, "Architecture Overview")
            heading = "Architecture Overview"

        # Fallback: show first lines
        if not summary:
            lines = spec_content.strip().splitlines()[:12]
            summary = "\n".join(lines)
            heading = "Plan"

        if summary:
            self._emit_summary(
                "Plan Summary",
                f"## {heading}\n\n{summary}",
            )

    def _show_pr_draft(self) -> None:
        """Send PR draft as markdown to the summary panel."""
        draft_file = self.project_dir / ".workflow" / "pr-draft.md"
        if not draft_file.exists():
            return

        content = draft_file.read_text(encoding="utf-8", errors="replace").strip()
        if content:
            self._emit_summary("PR Draft", content)

    def _show_phase_summary(self, phase: Phase) -> None:
        """Send phase spec summary as markdown to the summary panel."""
        specs_dir = self.project_dir / ".workflow" / "specs"
        if not specs_dir.exists():
            return

        pattern = f"*-ph{phase.number:02d}-*.md"
        spec_files = list(specs_dir.glob(pattern))
        if not spec_files:
            return

        content = spec_files[0].read_text(encoding="utf-8", errors="replace")
        summary = _extract_section(content, "Phase Summary")

        if not summary:
            lines = [l for l in content.strip().splitlines() if l.strip()][:8]
            summary = "\n".join(lines)

        if summary:
            self._emit_summary(
                f"Phase {phase.number}: {phase.name}",
                f"## Phase Summary\n\n{summary}",
            )

    def _update_codebase_context(self) -> None:
        """Regenerate structure.md and ensure architecture.md exists."""
        self._emit("[dim]Updating codebase context...[/]")
        write_structure(self.project_dir)
        init_architecture(self.project_dir)

    def _emit(self, text: str) -> None:
        if self.on_output:
            self.on_output(text)

    def _emit_live(self, text: str) -> None:
        if self.on_live_log:
            self.on_live_log(text)

    def _emit_summary(self, title: str, markdown: str) -> None:
        if self.on_summary:
            self.on_summary(title, markdown)

    def _notify_phase(self, phase_num: int, status: PhaseStatus) -> None:
        if self.on_phase_change:
            self.on_phase_change(phase_num, status)

    def _notify_activity(self, activity: str) -> None:
        if self.on_activity:
            self.on_activity(activity)


def detect_existing_workflow(project_dir: Path, issue_num: int) -> dict | None:
    """Check if an existing workflow-state.json exists for this issue.

    Returns the state dict if found, None otherwise.
    """
    state_file = project_dir / ".workflow" / "workflow-state.json"
    if not state_file.exists():
        return None

    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
        # Must match issue number
        if state.get("issue", {}).get("number") != issue_num:
            return None
        # Must have at least one completed phase
        phases = state.get("phases", {})
        if not phases:
            return None
        return state
    except Exception:
        return None


def _short_path(path: str, max_len: int = 60) -> str:
    """Shorten a file path for display."""
    if len(path) <= max_len:
        return path
    parts = path.split("/")
    if len(parts) <= 2:
        return path
    return f".../{'/'.join(parts[-2:])}"
