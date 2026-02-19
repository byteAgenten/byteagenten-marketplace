"""bytcode Terminal UI — Textual app for the bytA workflow orchestrator."""

import subprocess
import sys
import time
from pathlib import Path

from textual import events, work
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
    Markdown,
    RadioButton,
    RadioSet,
    RichLog,
    Select,
    Static,
    TextArea,
)

from .config import COVERAGE_OPTIONS, PHASES, PhaseType, Scope, WorkflowConfig
from .orchestrator import Orchestrator, PhaseResult, PhaseStatus, PreExistingInfo, detect_existing_workflow

# Status indicator symbols
STATUS_ICONS: dict[PhaseStatus, str] = {
    PhaseStatus.PENDING: "[dim]○[/]",
    PhaseStatus.RUNNING: "[yellow]●[/]",
    PhaseStatus.PASSED: "[green]✓[/]",
    PhaseStatus.FAILED: "[red]✗[/]",
    PhaseStatus.AWAITING_APPROVAL: "[cyan]⧖[/]",
    PhaseStatus.AWAITING_PREEXISTING: "[yellow]⚠[/]",
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


class ResizeHandle(Static):
    """Draggable handle to resize adjacent panels."""

    can_focus = False

    def __init__(self, direction: str = "vertical", **kwargs: object) -> None:
        label = "─── drag ───" if direction == "vertical" else ""
        super().__init__(label, **kwargs)
        self.direction = direction
        self._dragging = False
        self._drag_start = 0
        self._initial_before = 0
        self._initial_after = 0
        self._before_widget: object | None = None
        self._after_widget: object | None = None
        self.add_class(f"-{direction}")

    def _find_visible_neighbors(self) -> tuple[object, object] | None:
        """Find the visible widgets immediately before and after this handle."""
        parent = self.parent
        if parent is None:
            return None
        visible = [c for c in parent.children if c.display]
        try:
            idx = visible.index(self)
        except ValueError:
            return None
        if idx == 0 or idx >= len(visible) - 1:
            return None
        return visible[idx - 1], visible[idx + 1]

    def _normalize_sibling_heights(self) -> None:
        """Set ALL visible content panels to pixel-based fr values.

        Without this, dragging two panels to e.g. 25fr/10fr while a third
        panel stays at 1fr (from CSS) causes the third to collapse.
        Normalizing puts everything on the same scale.
        """
        parent = self.parent
        if parent is None:
            return
        for child in parent.children:
            if child.display and not isinstance(child, ResizeHandle):
                h = child.size.height
                if h > 0:
                    child.styles.height = f"{h}fr"

    def on_mouse_down(self, event: events.MouseDown) -> None:
        neighbors = self._find_visible_neighbors()
        if neighbors is None:
            return
        before, after = neighbors
        self._dragging = True
        self._before_widget = before
        self._after_widget = after
        if self.direction == "vertical":
            # Normalize ALL panels to same fr scale before capturing sizes
            self._normalize_sibling_heights()
            self._drag_start = event.screen_y
            self._initial_before = before.size.height
            self._initial_after = after.size.height
        else:
            self._drag_start = event.screen_x
            self._initial_before = before.size.width
            self._initial_after = 0  # horizontal only adjusts 'before'
        self.capture_mouse()
        self.add_class("-dragging")
        event.stop()

    def on_mouse_move(self, event: events.MouseMove) -> None:
        if not self._dragging or self._before_widget is None:
            return
        pos = event.screen_y if self.direction == "vertical" else event.screen_x
        total_delta = pos - self._drag_start
        if total_delta == 0:
            return
        self._apply_resize(total_delta)
        event.stop()

    def on_mouse_up(self, event: events.MouseUp) -> None:
        if self._dragging:
            self._dragging = False
            self._before_widget = None
            self._after_widget = None
            self.release_mouse()
            self.remove_class("-dragging")
            event.stop()

    def _apply_resize(self, total_delta: int) -> None:
        """Apply resize based on total delta from drag start (not incremental).

        Uses fr units so panels always fill 100% of the container.
        Initial pixel sizes are captured once at mouse_down — no stale reads.
        """
        before = self._before_widget
        after = self._after_widget
        if before is None:
            return

        if self.direction == "vertical" and after is not None:
            total = self._initial_before + self._initial_after
            min_size = 4
            new_before = max(min_size, self._initial_before + total_delta)
            new_after = max(min_size, total - new_before)
            new_before = total - new_after
            before.styles.height = f"{new_before}fr"
            after.styles.height = f"{new_after}fr"
        else:
            parent = self.parent
            if parent is None:
                return
            min_size = 15
            max_size = parent.size.width - min_size - 1
            new_before = max(min_size, min(max_size, self._initial_before + total_delta))
            before.styles.width = new_before


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
    """Modal dialog for entering approval feedback (multi-line)."""

    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    def compose(self) -> ComposeResult:
        with Vertical(id="feedback-container"):
            yield Label("Enter feedback for the agent:")
            yield TextArea("", id="feedback-input", language=None)
            with Horizontal(id="feedback-actions"):
                yield Button("Submit", variant="success", id="btn-feedback-submit")
                yield Button("Cancel", variant="default", id="btn-feedback-cancel")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-feedback-submit":
            self.dismiss(self.query_one("#feedback-input", TextArea).text.strip())
        elif event.button.id == "btn-feedback-cancel":
            self.dismiss("")

    def action_cancel(self) -> None:
        self.dismiss("")


class RollbackScreen(ModalScreen[tuple[int, str]]):
    """Modal to select target phase for rollback, with optional feedback.

    Two-step flow:
    1. Select target phase (buttons)
    2. Enter optional feedback explaining what went wrong (input)

    Dismisses with:
    - (phase_number, feedback_text) to roll back
    - (-1, "") to cancel
    """

    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    def __init__(self, current_phase: int, passed_phases: list[int]) -> None:
        super().__init__()
        self.current_phase = current_phase
        self.passed_phases = passed_phases
        self._selected_phase: int = -1

    def compose(self) -> ComposeResult:
        with Vertical(id="rollback-container"):
            yield Label(
                f"[bold yellow]Rollback from Phase {self.current_phase}[/]",
                id="rollback-title",
            )
            yield Label("Select target phase to re-run:", id="rollback-step-label")
            yield Label("")
            with Vertical(id="rollback-buttons"):
                for p_num in self.passed_phases:
                    phase = PHASES[p_num]
                    yield Button(
                        f"Phase {p_num}: {phase.name} ({phase.agent})",
                        variant="warning",
                        id=f"btn-rollback-{p_num}",
                    )
                yield Button("Cancel", variant="default", id="btn-rollback-cancel")
            with Vertical(id="rollback-feedback-box"):
                yield TextArea(
                    "",
                    id="rollback-feedback",
                    language=None,
                )
                with Horizontal(id="rollback-feedback-actions"):
                    yield Button(
                        "Submit", variant="success", id="btn-rollback-submit"
                    )
                    yield Button(
                        "Skip", variant="default", id="btn-rollback-skip"
                    )

    def on_mount(self) -> None:
        # Hide feedback area until phase is selected
        self.query_one("#rollback-feedback-box").display = False

    def on_button_pressed(self, event: Button.Pressed) -> None:
        btn_id = event.button.id or ""
        if btn_id.startswith("btn-rollback-") and btn_id not in (
            "btn-rollback-cancel",
            "btn-rollback-submit",
            "btn-rollback-skip",
        ):
            self._selected_phase = int(btn_id.split("-")[-1])
            # Switch to feedback step
            self.query_one("#rollback-step-label", Label).update(
                f"Rolling back to Phase {self._selected_phase}. "
                "Describe what went wrong (or click Skip):"
            )
            self.query_one("#rollback-buttons").display = False
            feedback_box = self.query_one("#rollback-feedback-box")
            feedback_box.display = True
            self.query_one("#rollback-feedback", TextArea).focus()
        elif btn_id == "btn-rollback-cancel":
            self.dismiss((-1, ""))
        elif btn_id == "btn-rollback-submit":
            text = self.query_one("#rollback-feedback", TextArea).text.strip()
            self.dismiss((self._selected_phase, text))
        elif btn_id == "btn-rollback-skip":
            self.dismiss((self._selected_phase, ""))

    def action_cancel(self) -> None:
        self.dismiss((-1, ""))


class PreExistingScreen(ModalScreen[tuple[int | None, str]]):
    """Modal shown when pre-existing test failures are detected.

    Two-step flow:
    1. Choose action: Fix Frontend / Fix Backend / Fix All / Ignore
    2. Enter feedback describing what to fix (pre-populated with failure list)

    Dismisses with:
    - (target_phase, feedback) to fix via rollback
    - (None, "") to ignore and continue
    """

    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    def __init__(self, pre_existing: PreExistingInfo) -> None:
        super().__init__()
        self.pre_existing = pre_existing
        self._selected_target: int | None = None

    def compose(self) -> ComposeResult:
        fe = self.pre_existing.frontend_failures
        be = self.pre_existing.backend_failures

        with Vertical(id="preexisting-container"):
            yield Label(
                f"[bold yellow]{self.pre_existing.count} Pre-Existing "
                f"Test Failures Detected[/]",
                id="preexisting-title",
            )
            yield Label("")

            if fe:
                yield Label(f"  Frontend: {len(fe)} failures")
            if be:
                yield Label(f"  Backend: {len(be)} failures")

            # Show individual failures (max 10)
            for f in self.pre_existing.failures[:10]:
                test = f.get("test", "")
                file = f.get("file", "?")
                label = f"  [dim]- {test}[/]" if test else f"  [dim]- {file}[/]"
                yield Label(label)
            if len(self.pre_existing.failures) > 10:
                yield Label(
                    f"  [dim]... and {len(self.pre_existing.failures) - 10} more[/]"
                )

            yield Label("")

            with Vertical(id="preexisting-buttons"):
                if fe and be:
                    yield Button(
                        f"Fix All ({len(be)} backend + {len(fe)} frontend)",
                        variant="warning",
                        id="btn-fix-all",
                    )
                if be:
                    yield Button(
                        f"Fix Backend ({len(be)} failures)",
                        variant="warning",
                        id="btn-fix-backend",
                    )
                if fe:
                    yield Button(
                        f"Fix Frontend ({len(fe)} failures)",
                        variant="warning",
                        id="btn-fix-frontend",
                    )
                yield Button(
                    "Ignore (continue without fixing)",
                    variant="default",
                    id="btn-ignore",
                )

            with Vertical(id="preexisting-feedback-box"):
                yield Label("Describe what should be fixed:")
                yield TextArea("", id="preexisting-feedback", language=None)
                with Horizontal(id="preexisting-feedback-actions"):
                    yield Button(
                        "Submit", variant="success", id="btn-preexisting-submit"
                    )
                    yield Button(
                        "Back", variant="default", id="btn-preexisting-back"
                    )

    def on_mount(self) -> None:
        self.query_one("#preexisting-feedback-box").display = False

    def on_button_pressed(self, event: Button.Pressed) -> None:
        btn_id = event.button.id or ""
        if btn_id == "btn-fix-all":
            self._selected_target = 2  # Backend first, then frontend
            self._show_feedback()
        elif btn_id == "btn-fix-backend":
            self._selected_target = 2
            self._show_feedback()
        elif btn_id == "btn-fix-frontend":
            self._selected_target = 3
            self._show_feedback()
        elif btn_id == "btn-ignore":
            self.dismiss((None, ""))
        elif btn_id == "btn-preexisting-submit":
            text = self.query_one("#preexisting-feedback", TextArea).text.strip()
            self.dismiss((self._selected_target, text))
        elif btn_id == "btn-preexisting-back":
            self.query_one("#preexisting-feedback-box").display = False
            self.query_one("#preexisting-buttons").display = True

    def _show_feedback(self) -> None:
        """Switch to feedback step, pre-populated with failure list."""
        self.query_one("#preexisting-buttons").display = False
        fb_box = self.query_one("#preexisting-feedback-box")
        fb_box.display = True

        # Pre-populate with failure list
        lines = ["Fix these pre-existing test failures:"]
        for f in self.pre_existing.failures:
            test = f.get("test", "")
            file = f.get("file", "")
            if test:
                lines.append(f"- {test} ({file})")
            else:
                lines.append(f"- {file}")

        ta = self.query_one("#preexisting-feedback", TextArea)
        ta.text = "\n".join(lines)
        ta.focus()

    def action_cancel(self) -> None:
        self.dismiss((None, ""))


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
                if resume_phase < len(PHASES):
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
        Binding("f3", "rollback", "Rollback"),
        Binding("f5", "resize_up", "Output+"),
        Binding("f6", "resize_down", "Output-"),
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
        self._tick_count: int = 0
        self._resume_from: int = 0

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            yield self._build_sidebar()
            yield ResizeHandle(direction="horizontal")
            with Vertical(id="main-content"):
                main_panel = RichLog(id="main-panel", highlight=True, markup=True)
                main_panel.border_title = "Output"
                yield main_panel
                yield ResizeHandle(direction="vertical", id="summary-handle")
                summary = Markdown(id="summary-panel")
                summary.border_title = "Summary"
                yield summary
                yield ResizeHandle(direction="vertical")
                live_log = RichLog(id="live-log", highlight=True, markup=True)
                live_log.border_title = "Live Activity"
                yield live_log
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
        log = self.query_one("#main-panel", RichLog)
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
            on_live_log=self._on_live_log,
            on_summary=self._on_summary,
        )
        result = await self.orchestrator.run(resume_from=self._resume_from)
        self._handle_phase_result(result)

    def _on_output(self, text: str) -> None:
        self.call_from_thread(self._append_log, text)

    def _append_log(self, text: str) -> None:
        log = self.query_one("#main-panel", RichLog)
        log.write(text)

    def _on_phase_change(self, phase_num: int, status: PhaseStatus) -> None:
        self.call_from_thread(self._update_phase_status, phase_num, status)

    def _on_live_log(self, text: str) -> None:
        self.call_from_thread(self._append_live_log, text)

    def _append_live_log(self, text: str) -> None:
        live = self.query_one("#live-log", RichLog)
        live.write(text)

    def _on_summary(self, title: str, markdown: str) -> None:
        self.call_from_thread(self._update_summary, title, markdown)

    def _update_summary(self, title: str, markdown: str) -> None:
        panel = self.query_one("#summary-panel", Markdown)
        handle = self.query_one("#summary-handle", ResizeHandle)
        panel.border_title = title
        panel.update(markdown)
        if not panel.display:
            panel.display = True
            handle.display = True

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
        self._tick_count += 1
        if self._running_phase is not None:
            self._refresh_sidebar()

    def _refresh_sidebar(self) -> None:
        """Rebuild sidebar content with current status + elapsed time."""
        sidebar = self.query_one("#phase-sidebar", Static)
        lines: list[str] = []
        total_s: float = 0.0

        for phase in PHASES:
            current_status = PhaseStatus.PENDING
            result = None
            if self.orchestrator and phase.number in self.orchestrator.results:
                result = self.orchestrator.results[phase.number]
                current_status = result.status
            if phase.number == self._running_phase:
                current_status = PhaseStatus.RUNNING

            icon = STATUS_ICONS[current_status]
            typ = "A" if phase.phase_type == PhaseType.APPROVAL else " "

            if current_status == PhaseStatus.RUNNING and self.orchestrator:
                # Live elapsed time for running phase — icon pulses
                elapsed = time.monotonic() - self.orchestrator.phase_start_time
                total_s += elapsed
                pulse = "[yellow]●[/]" if self._tick_count % 2 == 0 else "[dim yellow]○[/]"
                line = f"{pulse} {phase.number} {phase.name}"
                line += f"\n    [yellow]{_fmt_elapsed(elapsed)}[/]"
                if self._last_activity:
                    line += f" [dim]{self._last_activity}[/]"
            elif result and result.duration_s > 0:
                # Completed phase — show final duration
                total_s += result.duration_s
                dur = f"[dim]{_fmt_elapsed(result.duration_s)}[/]"
                line = f"{icon} {phase.number} {phase.name} {dur}"
            else:
                line = f"{icon} {phase.number} {phase.name} {typ}"

            lines.append(line)

        # Total time at the bottom
        lines.append("")
        lines.append(f"[bold]Total: {_fmt_elapsed(total_s)}[/]")

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
        """Hide approve/feedback/rollback bindings unless awaiting approval."""
        if action in ("approve", "feedback", "rollback"):
            return self._awaiting_result is not None
        return True

    def _show_approval_bindings(self) -> None:
        self._append_log("")
        self._append_log(
            "[bold cyan]>>> Awaiting approval: "
            "F1=Approve  F2=Feedback  F3=Rollback  Q=Quit[/]"
        )

    def _hide_approval_bindings(self) -> None:
        pass  # check_action handles visibility via _awaiting_result

    def _handle_phase_result(self, result: PhaseResult | None) -> None:
        if result is None:
            self.call_from_thread(self._workflow_complete)
        elif result.status == PhaseStatus.AWAITING_PREEXISTING:
            self._awaiting_result = result
            self.call_from_thread(self._show_preexisting_screen, result)
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

    def action_rollback(self) -> None:
        if not self._awaiting_result or not self.orchestrator:
            return

        current_phase = self._awaiting_result.phase.number

        # Collect passed phases the user can roll back to
        passed: list[int] = []
        for p in PHASES:
            if p.number >= current_phase:
                break
            result = self.orchestrator.results.get(p.number)
            if result and result.status in (PhaseStatus.PASSED, PhaseStatus.AWAITING_APPROVAL):
                passed.append(p.number)

        if not passed:
            self._append_log("[yellow]No earlier phases to roll back to.[/]")
            return

        def on_rollback_choice(result: tuple[int, str]) -> None:
            target, feedback = result
            if target == -1 or not self._awaiting_result or not self.orchestrator:
                return
            phase_num = self._awaiting_result.phase.number
            self._awaiting_result = None
            self._hide_approval_bindings()
            msg = f"[bold yellow]>>> Rollback: Phase {phase_num} → Phase {target}[/]"
            if feedback:
                msg += f"\n[yellow]Feedback: {feedback}[/]"
            self._append_log(msg)
            self._resume_rollback(phase_num, target, feedback)

        self.push_screen(RollbackScreen(current_phase, passed), on_rollback_choice)

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

    @work(thread=True)
    async def _resume_rollback(
        self, current_phase: int, target_phase: int, feedback: str = ""
    ) -> None:
        if not self.orchestrator:
            return
        result = await self.orchestrator.rollback_to_phase(
            current_phase, target_phase, feedback=feedback
        )
        self._handle_phase_result(result)

    def _show_preexisting_screen(self, result: PhaseResult) -> None:
        """Show the pre-existing failures dialog after Phase 4."""
        if not result.pre_existing:
            return

        def on_choice(choice: tuple[int | None, str]) -> None:
            target, feedback = choice
            if not self.orchestrator:
                return
            phase_num = result.phase.number
            self._awaiting_result = None
            if target is not None:
                # Fix — rollback to target phase
                msg = f"[bold yellow]>>> Fix pre-existing: Rollback to Phase {target}[/]"
                if feedback:
                    msg += f"\n[yellow]Feedback: {feedback}[/]"
                self._append_log(msg)
                self._resume_rollback(phase_num, target, feedback)
            else:
                # Ignore — continue from next phase
                self._append_log(
                    "[dim]>>> Ignoring pre-existing failures, continuing...[/]"
                )
                self._resume_after_preexisting(phase_num)

        self.push_screen(PreExistingScreen(result.pre_existing), on_choice)

    @work(thread=True)
    async def _resume_after_preexisting(self, phase_num: int) -> None:
        """Continue workflow after ignoring pre-existing failures."""
        if not self.orchestrator:
            return
        # Treat as approved — mark phase 4 as passed and continue from phase 5
        result = await self.orchestrator.resume_after_approval(
            phase_num, approved=True
        )
        self._handle_phase_result(result)

    def _keyboard_resize(self, delta: int) -> None:
        """Resize Output panel by delta rows (positive=grow, negative=shrink)."""
        # Normalize all panels to same fr scale first
        content = self.query_one("#main-content")
        for child in content.children:
            if child.display and not isinstance(child, ResizeHandle):
                h = child.size.height
                if h > 0:
                    child.styles.height = f"{h}fr"

        main = self.query_one("#main-panel", RichLog)
        live = self.query_one("#live-log", RichLog)
        main_h = main.size.height
        live_h = live.size.height
        total = main_h + live_h
        min_size = 4

        new_main = max(min_size, main_h + delta)
        new_live = max(min_size, total - new_main)
        new_main = total - new_live

        main.styles.height = f"{new_main}fr"
        live.styles.height = f"{new_live}fr"

    def action_resize_up(self) -> None:
        self._keyboard_resize(3)

    def action_resize_down(self) -> None:
        self._keyboard_resize(-3)

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
