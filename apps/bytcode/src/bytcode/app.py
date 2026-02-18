"""bytcode Terminal UI — Textual app for the bytA workflow orchestrator."""

import subprocess
import sys
import time
from pathlib import Path

from textual import work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Center, Horizontal, Vertical
from textual.screen import ModalScreen
from textual.timer import Timer
from textual.widgets import (
    Button,
    Footer,
    Header,
    Input,
    Label,
    RadioButton,
    RadioSet,
    RichLog,
    Select,
    Static,
)

from .config import COVERAGE_OPTIONS, PHASES, PhaseType, Scope, WorkflowConfig
from .orchestrator import Orchestrator, PhaseResult, PhaseStatus, detect_existing_workflow

# Status indicator symbols
STATUS_ICONS: dict[PhaseStatus, str] = {
    PhaseStatus.PENDING: "[dim]○[/]",
    PhaseStatus.RUNNING: "[yellow]●[/]",
    PhaseStatus.PASSED: "[green]✓[/]",
    PhaseStatus.FAILED: "[red]✗[/]",
    PhaseStatus.AWAITING_APPROVAL: "[cyan]⧖[/]",
}


def _fmt_elapsed(seconds: float) -> str:
    """Format elapsed seconds as M:SS."""
    m, s = divmod(int(seconds), 60)
    return f"{m}:{s:02d}"


def _fetch_branches(project_dir: Path) -> list[str]:
    """Get available remote branches via git."""
    try:
        result = subprocess.run(
            ["git", "branch", "-r", "--no-color"],
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            timeout=10,
        )
        if result.returncode != 0:
            return ["main"]
        branches: list[str] = []
        for line in result.stdout.splitlines():
            name = line.strip()
            if not name or "HEAD" in name:
                continue
            if "/" in name:
                name = name.split("/", 1)[1]
            if name not in branches:
                branches.append(name)
        return branches if branches else ["main"]
    except Exception:
        return ["main"]


class SetupScreen(ModalScreen[WorkflowConfig | None]):
    """Startup screen to collect workflow configuration."""

    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    def __init__(self, issue_num: int, branches: list[str]) -> None:
        super().__init__()
        self.issue_num = issue_num
        self.branches = branches

    def compose(self) -> ComposeResult:
        with Vertical(id="setup-container"):
            yield Label(
                f"[bold]bytcode Setup[/] — Issue #{self.issue_num}",
                id="setup-title",
            )

            yield Label("From Branch:")
            branch_options = [(b, b) for b in self.branches]
            default = "main" if "main" in self.branches else self.branches[0]
            yield Select(
                branch_options, value=default, allow_blank=False, id="select-branch"
            )

            yield Label("Coverage Target:")
            cov_options = [(f"{c}%", c) for c in COVERAGE_OPTIONS]
            yield Select(
                cov_options, value=85, allow_blank=False, id="select-coverage"
            )

            yield Label("UI Designer:")
            with RadioSet(id="radio-ui-designer"):
                yield RadioButton("Yes", value=True)
                yield RadioButton("No")

            yield Label("Scope:")
            with RadioSet(id="radio-scope"):
                yield RadioButton("Full-Stack", value=True)
                yield RadioButton("Frontend-only")
                yield RadioButton("Backend-only")

            with Center():
                yield Button("Start Workflow", variant="primary", id="btn-start")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-start":
            self._submit()

    def _submit(self) -> None:
        branch_select = self.query_one("#select-branch", Select)
        coverage_select = self.query_one("#select-coverage", Select)
        ui_radio = self.query_one("#radio-ui-designer", RadioSet)
        scope_radio = self.query_one("#radio-scope", RadioSet)

        from_branch = str(branch_select.value) if branch_select.value else "main"
        coverage = int(coverage_select.value) if coverage_select.value else 85

        ui_designer = True
        if ui_radio.pressed_index == 1:
            ui_designer = False

        scope = Scope.FULL_STACK
        if scope_radio.pressed_index == 1:
            scope = Scope.FRONTEND_ONLY
        elif scope_radio.pressed_index == 2:
            scope = Scope.BACKEND_ONLY

        config = WorkflowConfig(
            issue_num=self.issue_num,
            from_branch=from_branch,
            target_coverage=coverage,
            ui_designer=ui_designer,
            scope=scope,
        )
        self.dismiss(config)

    def action_cancel(self) -> None:
        self.dismiss(None)


class FeedbackScreen(ModalScreen[str]):
    """Modal dialog for entering approval feedback."""

    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    def compose(self) -> ComposeResult:
        with Vertical(id="feedback-container"):
            yield Label("Enter feedback for the agent:")
            yield Input(placeholder="Your feedback...", id="feedback-input")

    def on_input_submitted(self, event: Input.Submitted) -> None:
        self.dismiss(event.value)

    def action_cancel(self) -> None:
        self.dismiss("")


class ResumeScreen(ModalScreen[int]):
    """Modal shown when an existing workflow is detected.

    Dismisses with:
    - phase number to resume from (e.g. 4)
    - 0 to start fresh
    - -1 to cancel
    """

    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    def __init__(self, issue_num: int, state: dict) -> None:
        super().__init__()
        self.issue_num = issue_num
        self.state = state

    def compose(self) -> ComposeResult:
        phases = self.state.get("phases", {})

        # Find first non-passed phase
        resume_phase = 0
        for p in PHASES:
            pdata = phases.get(str(p.number), {})
            if pdata.get("status") == "passed":
                resume_phase = p.number + 1
            else:
                break

        with Vertical(id="resume-container"):
            yield Label(
                f"[bold]Existing Workflow Found[/] — Issue #{self.issue_num}",
                id="resume-title",
            )

            # Show phase status summary
            yield Label("")
            for p in PHASES:
                pdata = phases.get(str(p.number), {})
                status = pdata.get("status", "pending")
                if status == "passed":
                    icon = "[green]✓[/]"
                elif status == "failed":
                    icon = "[red]✗[/]"
                else:
                    icon = "[dim]○[/]"
                attempts = pdata.get("attempts", "")
                att_str = f" ({attempts} attempts)" if attempts else ""
                yield Label(f"  {icon} Phase {p.number}: {p.name}{att_str}")

            yield Label("")
            with Vertical(id="resume-buttons"):
                if resume_phase <= 7:
                    phase_name = PHASES[resume_phase].name if resume_phase < len(PHASES) else "?"
                    yield Button(
                        f"Resume from Phase {resume_phase} ({phase_name})",
                        variant="primary",
                        id=f"btn-resume-{resume_phase}",
                    )
                yield Button("Start Fresh", variant="warning", id="btn-fresh")
                yield Button("Cancel", variant="default", id="btn-cancel")

        self._resume_phase = resume_phase

    def on_button_pressed(self, event: Button.Pressed) -> None:
        btn_id = event.button.id or ""
        if btn_id.startswith("btn-resume-"):
            phase = int(btn_id.split("-")[-1])
            self.dismiss(phase)
        elif btn_id == "btn-fresh":
            self.dismiss(0)
        elif btn_id == "btn-cancel":
            self.dismiss(-1)

    def action_cancel(self) -> None:
        self.dismiss(-1)


class BytcodeApp(App[None]):
    """Main bytcode application."""

    CSS_PATH = "styles.tcss"

    TITLE = "bytcode"

    BINDINGS = [
        Binding("f1", "approve", "Approve"),
        Binding("f2", "feedback", "Feedback"),
        Binding("q", "quit", "Quit"),
    ]

    def __init__(self, issue_num: int, project_dir: Path) -> None:
        super().__init__()
        self.issue_num = issue_num
        self.project_dir = project_dir
        self.config: WorkflowConfig | None = None
        self.orchestrator: Orchestrator | None = None
        self._awaiting_result: PhaseResult | None = None
        self._running_phase: int | None = None
        self._last_activity: str = ""
        self._tick_timer: Timer | None = None
        self._resume_from: int = 0

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            yield self._build_sidebar()
            yield RichLog(id="log-panel", highlight=True, markup=True)
        yield Footer()

    def _build_sidebar(self) -> Static:
        lines: list[str] = []
        for phase in PHASES:
            icon = STATUS_ICONS[PhaseStatus.PENDING]
            typ = "A" if phase.phase_type == PhaseType.APPROVAL else " "
            lines.append(f"{icon} {phase.number} {phase.name} {typ}")
        return Static("\n".join(lines), id="phase-sidebar")

    def on_mount(self) -> None:
        self.sub_title = f"Issue #{self.issue_num}"

        # Check for existing workflow
        existing = detect_existing_workflow(self.project_dir, self.issue_num)
        if existing:
            self.push_screen(
                ResumeScreen(self.issue_num, existing), self._on_resume_choice
            )
        else:
            self._show_setup()

    def _show_setup(self) -> None:
        branches = _fetch_branches(self.project_dir)
        self.push_screen(
            SetupScreen(self.issue_num, branches), self._on_setup_complete
        )

    def _on_resume_choice(self, choice: int) -> None:
        if choice == -1:
            # Cancel
            self.exit()
        elif choice == 0:
            # Start fresh
            self._show_setup()
        else:
            # Resume from specific phase — load config from existing state
            self._resume_from = choice
            self._load_config_from_state()

    def _load_config_from_state(self) -> None:
        """Load WorkflowConfig from existing workflow-state.json for resume."""
        import json

        state_file = self.project_dir / ".workflow" / "workflow-state.json"
        try:
            state = json.loads(state_file.read_text(encoding="utf-8"))
            scope_str = state.get("scope", "full-stack")
            scope = Scope.FULL_STACK
            if scope_str == "frontend-only":
                scope = Scope.FRONTEND_ONLY
            elif scope_str == "backend-only":
                scope = Scope.BACKEND_ONLY

            self.config = WorkflowConfig(
                issue_num=self.issue_num,
                issue_title=state.get("issue", {}).get("title", ""),
                from_branch=state.get("fromBranch", "main"),
                target_coverage=state.get("targetCoverage", 85),
                ui_designer=state.get("uiDesigner", True),
                scope=scope,
            )
        except Exception:
            self.config = WorkflowConfig(issue_num=self.issue_num)

        self._log_config_and_start()

    def _on_setup_complete(self, config: WorkflowConfig | None) -> None:
        if config is None:
            self.exit()
            return
        self.config = config
        self._resume_from = 0
        self._log_config_and_start()

    def _log_config_and_start(self) -> None:
        config = self.config
        if not config:
            return
        log = self.query_one("#log-panel", RichLog)
        log.write("[bold]bytcode v0.1.0[/]")
        log.write(f"Issue:    #{config.issue_num}")
        log.write(f"Branch:   {config.from_branch}")
        log.write(f"Coverage: {config.target_coverage}%")
        log.write(f"UI:       {'Yes' if config.ui_designer else 'No'}")
        log.write(f"Scope:    {config.scope.value}")
        log.write(f"Project:  {self.project_dir}")
        if self._resume_from > 0:
            log.write(f"[bold yellow]Resume:   from Phase {self._resume_from}[/]")
        log.write("")
        self._start_workflow()

    @work(thread=True)
    async def _start_workflow(self) -> None:
        if not self.config:
            return
        self.orchestrator = Orchestrator(
            config=self.config,
            project_dir=self.project_dir,
            on_output=self._on_output,
            on_phase_change=self._on_phase_change,
            on_activity=self._on_activity,
        )
        result = await self.orchestrator.run(resume_from=self._resume_from)
        self._handle_phase_result(result)

    def _on_output(self, text: str) -> None:
        self.call_from_thread(self._append_log, text)

    def _append_log(self, text: str) -> None:
        log = self.query_one("#log-panel", RichLog)
        log.write(text)

    def _on_phase_change(self, phase_num: int, status: PhaseStatus) -> None:
        self.call_from_thread(self._update_phase_status, phase_num, status)

    def _on_activity(self, activity: str) -> None:
        """Called from orchestrator when agent uses a tool."""
        self._last_activity = activity
        # Sidebar refresh happens via tick timer

    def _start_tick_timer(self) -> None:
        """Start 1-second timer to update sidebar with elapsed time."""
        if self._tick_timer is None:
            self._tick_timer = self.set_interval(1.0, self._tick)

    def _stop_tick_timer(self) -> None:
        """Stop the sidebar tick timer."""
        if self._tick_timer is not None:
            self._tick_timer.stop()
            self._tick_timer = None

    def _tick(self) -> None:
        """Called every second to refresh sidebar with elapsed time."""
        if self._running_phase is not None:
            self._refresh_sidebar()

    def _refresh_sidebar(self) -> None:
        """Rebuild sidebar content with current status + elapsed time."""
        sidebar = self.query_one("#phase-sidebar", Static)
        lines: list[str] = []

        for phase in PHASES:
            current_status = PhaseStatus.PENDING
            if self.orchestrator and phase.number in self.orchestrator.results:
                current_status = self.orchestrator.results[phase.number].status
            if phase.number == self._running_phase:
                current_status = PhaseStatus.RUNNING

            icon = STATUS_ICONS[current_status]
            typ = "A" if phase.phase_type == PhaseType.APPROVAL else " "
            line = f"{icon} {phase.number} {phase.name} {typ}"

            # Add elapsed time + activity for running phase
            if current_status == PhaseStatus.RUNNING and self.orchestrator:
                elapsed = time.monotonic() - self.orchestrator.phase_start_time
                line = f"{icon} {phase.number} {phase.name}"
                line += f"\n    [yellow]{_fmt_elapsed(elapsed)}[/]"
                if self._last_activity:
                    line += f" [dim]{self._last_activity}[/]"

            lines.append(line)

        sidebar.update("\n".join(lines))

    def _update_phase_status(self, phase_num: int, status: PhaseStatus) -> None:
        if status == PhaseStatus.RUNNING:
            self._running_phase = phase_num
            self._last_activity = ""
            self._start_tick_timer()
        elif self._running_phase == phase_num:
            self._running_phase = None
            self._last_activity = ""
            self._stop_tick_timer()

        self._refresh_sidebar()

        if status == PhaseStatus.AWAITING_APPROVAL:
            self._show_approval_bindings()

    def check_action(self, action: str, parameters: tuple[object, ...]) -> bool | None:
        """Hide approve/feedback bindings unless awaiting approval."""
        if action in ("approve", "feedback"):
            return self._awaiting_result is not None
        return True

    def _show_approval_bindings(self) -> None:
        self._append_log("")
        self._append_log(
            "[bold cyan]>>> Awaiting approval: "
            "F1=Approve  F2=Feedback  Q=Quit[/]"
        )

    def _hide_approval_bindings(self) -> None:
        pass  # check_action handles visibility via _awaiting_result

    def _handle_phase_result(self, result: PhaseResult | None) -> None:
        if result is None:
            self.call_from_thread(self._workflow_complete)
        else:
            self._awaiting_result = result

    def _workflow_complete(self) -> None:
        self._stop_tick_timer()
        self._append_log("")
        if self.orchestrator:
            if self.orchestrator.abort_reason:
                self._append_log(
                    f"[bold red]Workflow aborted: {self.orchestrator.abort_reason}[/]"
                )
            elif any(
                r.status == PhaseStatus.FAILED
                for r in self.orchestrator.results.values()
            ):
                self._append_log("[bold red]Workflow finished with errors.[/]")
            else:
                self._append_log("[bold green]Workflow completed successfully![/]")
        self._append_log("[dim]Press Q to exit.[/]")

    def action_approve(self) -> None:
        if not self._awaiting_result or not self.orchestrator:
            return
        phase_num = self._awaiting_result.phase.number
        self._awaiting_result = None
        self._hide_approval_bindings()
        self._append_log("[green]>>> Approved[/]")
        self._resume_workflow(phase_num, approved=True)

    def action_feedback(self) -> None:
        if not self._awaiting_result:
            return

        def on_feedback(feedback: str) -> None:
            if not feedback or not self._awaiting_result or not self.orchestrator:
                return
            phase_num = self._awaiting_result.phase.number
            self._awaiting_result = None
            self._hide_approval_bindings()
            self._append_log(f"[yellow]>>> Feedback: {feedback}[/]")
            self._resume_workflow(phase_num, approved=False, feedback=feedback)

        self.push_screen(FeedbackScreen(), on_feedback)

    @work(thread=True)
    async def _resume_workflow(
        self, from_phase: int, *, approved: bool = True, feedback: str = ""
    ) -> None:
        if not self.orchestrator:
            return
        result = await self.orchestrator.resume_after_approval(
            from_phase, approved=approved, feedback=feedback
        )
        self._handle_phase_result(result)

    def action_quit(self) -> None:
        self._stop_tick_timer()
        if self.orchestrator:
            self.orchestrator.cancel()
        self.exit()


def main() -> None:
    """CLI entry point: bytcode run <issue> [--project <dir>]"""
    import argparse

    parser = argparse.ArgumentParser(
        prog="bytcode",
        description="bytcode — External workflow orchestrator for bytA",
    )
    sub = parser.add_subparsers(dest="command")

    run_parser = sub.add_parser("run", help="Run workflow for an issue")
    run_parser.add_argument("issue", type=int, help="GitHub issue number")
    run_parser.add_argument(
        "--project",
        type=Path,
        default=Path.cwd(),
        help="Project directory (default: current directory)",
    )

    args = parser.parse_args()

    if args.command != "run":
        parser.print_help()
        sys.exit(1)

    project_dir = args.project.resolve()
    if not project_dir.is_dir():
        print(f"Error: {project_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    app = BytcodeApp(issue_num=args.issue, project_dir=project_dir)
    app.run()


if __name__ == "__main__":
    main()
