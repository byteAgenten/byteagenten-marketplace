"""Phase definitions for the bytcode workflow."""

from dataclasses import dataclass, field
from enum import Enum


class PhaseType(Enum):
    AUTO = "auto"
    APPROVAL = "approval"


class Scope(Enum):
    FULL_STACK = "full-stack"
    FRONTEND_ONLY = "frontend-only"
    BACKEND_ONLY = "backend-only"


COVERAGE_OPTIONS: list[int] = [50, 70, 85, 95]


@dataclass
class WorkflowConfig:
    """User-provided startup configuration."""

    issue_num: int
    issue_title: str = ""
    from_branch: str = "main"
    target_coverage: int = 85
    ui_designer: bool = True
    scope: Scope = Scope.FULL_STACK


@dataclass
class Criterion:
    """A single done-criterion for a phase."""

    type: str  # "glob" or "jq"
    pattern: str  # glob pattern or jq expression
    file: str = ""  # for jq: which file to check (relative to project root)


@dataclass
class Phase:
    """Definition of a single workflow phase."""

    number: int
    name: str
    agent: str
    phase_type: PhaseType
    criteria: list[Criterion] = field(default_factory=list)
    tools: list[str] = field(default_factory=list)  # --tools: restricts available tools
    model: str = ""       # "" = default (opus), or "sonnet", "haiku"
    max_turns: int = 0    # 0 = no limit, >0 = --max-turns safety cap


PHASES: list[Phase] = [
    Phase(
        number=0,
        name="Planning",
        agent="architect-planner",
        phase_type=PhaseType.APPROVAL,
        criteria=[
            Criterion("glob", ".workflow/specs/*-plan-consolidated.md"),
        ],
        tools=["Read", "Glob", "Grep", "Write", "Bash"],
        model="",          # opus — needs deep analysis
        max_turns=60,      # planning is exploration-heavy
    ),
    Phase(
        number=1,
        name="Database",
        agent="postgresql-architect",
        phase_type=PhaseType.AUTO,
        criteria=[
            Criterion("glob", "backend/**/V*.sql"),
            Criterion("glob", ".workflow/specs/*-ph01-*.md"),
        ],
        tools=["Read", "Write", "Edit", "Bash", "Glob", "Grep"],
        model="sonnet",    # migrations are straightforward
        max_turns=30,
    ),
    Phase(
        number=2,
        name="Backend",
        agent="spring-boot-developer",
        phase_type=PhaseType.AUTO,
        criteria=[
            Criterion("glob", ".workflow/specs/*-ph02-*.md"),
        ],
        tools=["Read", "Write", "Edit", "Bash", "Glob", "Grep"],
        model="",          # opus — complex implementation
        max_turns=60,
    ),
    Phase(
        number=3,
        name="Frontend",
        agent="angular-frontend-developer",
        phase_type=PhaseType.AUTO,
        criteria=[
            Criterion("glob", ".workflow/specs/*-ph03-*.md"),
        ],
        tools=["Read", "Write", "Edit", "Bash", "Glob", "Grep"],
        model="",          # opus — complex implementation
        max_turns=60,
    ),
    Phase(
        number=4,
        name="Tests",
        agent="test-engineer",
        phase_type=PhaseType.AUTO,
        criteria=[
            Criterion(
                "jq",
                '.phases["4"].context.testResults.allPassed == true',
                ".workflow/workflow-state.json",
            ),
            Criterion("glob", ".workflow/specs/*-ph04-*.md"),
        ],
        tools=["Read", "Write", "Edit", "Bash", "Glob", "Grep"],
        model="sonnet",    # test writing follows patterns
        max_turns=40,
    ),
    Phase(
        number=5,
        name="Security",
        agent="security-auditor",
        phase_type=PhaseType.APPROVAL,
        criteria=[
            Criterion("glob", ".workflow/specs/*-ph05-*.md"),
        ],
        tools=["Read", "Write", "Edit", "Bash", "Glob", "Grep"],
        model="sonnet",    # audit is read-heavy, pattern-based
        max_turns=30,
    ),
    Phase(
        number=6,
        name="Review",
        agent="code-reviewer",
        phase_type=PhaseType.APPROVAL,
        criteria=[
            Criterion("glob", ".workflow/specs/*-ph06-*.md"),
        ],
        tools=["Read", "Glob", "Grep"],
        model="sonnet",    # review is read-only analysis
        max_turns=25,
    ),
    Phase(
        number=7,
        name="PR Draft",
        agent="pr-writer",
        phase_type=PhaseType.APPROVAL,
        criteria=[
            Criterion("glob", ".workflow/pr-draft.md"),
        ],
        tools=["Read", "Write", "Bash", "Glob", "Grep"],
        model="sonnet",    # summary writing
        max_turns=20,
    ),
    Phase(
        number=8,
        name="Push & PR",
        agent="push-pr",
        phase_type=PhaseType.AUTO,
        criteria=[
            Criterion(
                "jq",
                '.prUrl != null and .prUrl != ""',
                ".workflow/workflow-state.json",
            ),
        ],
        tools=["Bash", "Read", "Glob", "Grep"],
        model="sonnet",    # just git commands
        max_turns=15,
    ),
]
