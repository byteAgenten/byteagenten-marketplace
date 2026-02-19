"""Codebase context generator for bytcode.

Two layers:
1. structure.md  — Auto-generated (Python, no LLM): file tree, tech stack, key files
2. architecture.md — Agent-maintained (LLM): entities, endpoints, patterns, relationships

structure.md is regenerated before each phase.
architecture.md is updated by agents after each phase.
"""

import subprocess
from pathlib import Path

# Directories to skip in tree generation
_SKIP_DIRS = {
    "node_modules", ".git", "target", "dist", "build", ".gradle",
    ".idea", ".vscode", ".workflow", "__pycache__", ".angular",
    ".next", "coverage", ".nyc_output", "out", "tmp",
}

# File extensions to include in key-file inventory
_BACKEND_ENTITY = "**/entity/*.java"
_BACKEND_MODEL = "**/model/*.java"
_BACKEND_CONTROLLER = "**/controller/*.java"
_BACKEND_RESOURCE = "**/resource/*.java"
_BACKEND_SERVICE = "**/service/*.java"
_BACKEND_REPOSITORY = "**/repository/*.java"
_BACKEND_DTO = "**/dto/**/*.java"
_BACKEND_MIGRATION = "**/migration/V*.sql"
_FRONTEND_COMPONENT = "**/*.component.ts"
_FRONTEND_SERVICE = "**/services/*.service.ts"
_FRONTEND_MODEL = "**/models/*.model.ts"
_FRONTEND_ROUTE = "**/app.routes.ts"


def generate_structure(project_dir: Path) -> str:
    """Generate structure.md content: file tree + tech stack + key files."""
    parts: list[str] = [
        "# Codebase Structure",
        f"Project: {project_dir.name}",
        "",
    ]

    # 1. Tech stack detection
    tech = _detect_tech_stack(project_dir)
    if tech:
        parts.append("## Tech Stack")
        for key, value in tech.items():
            parts.append(f"- **{key}**: {value}")
        parts.append("")

    # 2. Directory tree (depth-limited, compact)
    tree = _generate_tree(project_dir, max_depth=2)
    parts.append("## Directory Tree")
    parts.append("```")
    parts.extend(tree)
    parts.append("```")
    parts.append("")

    # 3. Database migrations (shows schema evolution)
    migrations = sorted(project_dir.rglob("V*.sql"))
    migrations = [m for m in migrations if not any(s in str(m) for s in _SKIP_DIRS)]
    if migrations:
        parts.append("## Database Migrations")
        for m in migrations:
            parts.append(f"- {m.relative_to(project_dir)}")
        parts.append("")

    # 4. Backend entity fields (quick parse)
    entities = _parse_java_entities(project_dir)
    if entities:
        parts.append("## Entity Summary")
        for entity_name, fields in entities.items():
            field_str = ", ".join(fields[:15])  # limit to 15 fields
            if len(fields) > 15:
                field_str += ", ..."
            parts.append(f"- **{entity_name}**: {field_str}")
        parts.append("")

    # 5. Frontend component list
    components = _list_frontend_components(project_dir)
    if components:
        parts.append("## Frontend Components")
        for comp in components:
            parts.append(f"- {comp}")
        parts.append("")

    # 6. API endpoints (quick grep)
    endpoints = _find_api_endpoints(project_dir)
    if endpoints:
        parts.append("## API Endpoints")
        for ep in endpoints:
            parts.append(f"- {ep}")
        parts.append("")

    return "\n".join(parts)


def ensure_context_dir(project_dir: Path) -> Path:
    """Ensure .workflow/context/ directory exists."""
    ctx_dir = project_dir / ".workflow" / "context"
    ctx_dir.mkdir(parents=True, exist_ok=True)
    return ctx_dir


def write_structure(project_dir: Path) -> None:
    """Generate and write structure.md to .workflow/context/."""
    ctx_dir = ensure_context_dir(project_dir)
    content = generate_structure(project_dir)
    (ctx_dir / "structure.md").write_text(content, encoding="utf-8")


def init_architecture(project_dir: Path) -> None:
    """Create architecture.md template if it doesn't exist yet."""
    ctx_dir = ensure_context_dir(project_dir)
    arch_file = ctx_dir / "architecture.md"
    if arch_file.exists():
        return

    template = (
        "# Architecture Context\n\n"
        "This file is maintained by agents across workflow phases.\n"
        "Each agent reads this at the start and updates it after completing work.\n\n"
        "## Entities & Data Model\n\n"
        "_No entities documented yet._\n\n"
        "## API Endpoints\n\n"
        "_No endpoints documented yet._\n\n"
        "## Frontend Components\n\n"
        "_No components documented yet._\n\n"
        "## Key Patterns & Conventions\n\n"
        "_No patterns documented yet._\n\n"
        "## Relationships & Dependencies\n\n"
        "_No relationships documented yet._\n"
    )
    arch_file.write_text(template, encoding="utf-8")


def read_context(project_dir: Path) -> str:
    """Read all context files and return combined content for prompt injection."""
    ctx_dir = project_dir / ".workflow" / "context"
    if not ctx_dir.exists():
        return ""

    parts: list[str] = []

    structure = ctx_dir / "structure.md"
    if structure.exists():
        parts.append(structure.read_text(encoding="utf-8", errors="replace"))

    architecture = ctx_dir / "architecture.md"
    if architecture.exists():
        parts.append(architecture.read_text(encoding="utf-8", errors="replace"))

    return "\n\n---\n\n".join(parts)


# --- Internal helpers ---


def _detect_tech_stack(project_dir: Path) -> dict[str, str]:
    """Detect tech stack from config files."""
    tech: dict[str, str] = {}

    # Angular
    angular_json = project_dir / "frontend" / "angular.json"
    if not angular_json.exists():
        angular_json = project_dir / "angular.json"
    if angular_json.exists():
        tech["Frontend"] = "Angular"
        # Try to get version from package.json
        pkg = angular_json.parent / "package.json"
        if pkg.exists():
            try:
                import json
                data = json.loads(pkg.read_text(encoding="utf-8"))
                deps = {**data.get("dependencies", {}), **data.get("devDependencies", {})}
                if "@angular/core" in deps:
                    tech["Angular Version"] = deps["@angular/core"]
            except Exception:
                pass

    # Spring Boot
    pom = project_dir / "backend" / "pom.xml"
    if not pom.exists():
        pom = project_dir / "pom.xml"
    if pom.exists():
        tech["Backend"] = "Spring Boot (Maven)"
    else:
        gradle = project_dir / "backend" / "build.gradle"
        if not gradle.exists():
            gradle = project_dir / "build.gradle"
        if gradle.exists():
            tech["Backend"] = "Spring Boot (Gradle)"

    # Database
    for migration_dir in project_dir.rglob("migration"):
        if migration_dir.is_dir() and any(migration_dir.glob("V*.sql")):
            tech["Database"] = "PostgreSQL (Flyway migrations)"
            break

    return tech


def _generate_tree(root: Path, max_depth: int = 4) -> list[str]:
    """Generate a filtered directory tree."""
    lines: list[str] = [root.name + "/"]
    _tree_recurse(root, "", max_depth, 0, lines)
    return lines


def _tree_recurse(
    directory: Path, prefix: str, max_depth: int, depth: int, lines: list[str]
) -> None:
    if depth >= max_depth:
        return

    try:
        entries = sorted(directory.iterdir(), key=lambda p: (not p.is_dir(), p.name))
    except PermissionError:
        return

    # Filter out skip directories and hidden files (except config files)
    filtered = [
        e for e in entries
        if e.name not in _SKIP_DIRS
        and not (e.name.startswith(".") and e.is_dir() and e.name != ".workflow")
    ]

    for i, entry in enumerate(filtered):
        is_last = i == len(filtered) - 1
        connector = "`-- " if is_last else "|-- "
        child_prefix = prefix + ("    " if is_last else "|   ")

        if entry.is_dir():
            lines.append(f"{prefix}{connector}{entry.name}/")
            _tree_recurse(entry, child_prefix, max_depth, depth + 1, lines)
        else:
            lines.append(f"{prefix}{connector}{entry.name}")


def _collect_inventory(project_dir: Path) -> dict[str, list[str]]:
    """Collect key files by category."""
    inventory: dict[str, list[str]] = {}

    patterns = {
        "Backend Entities": [_BACKEND_ENTITY, _BACKEND_MODEL],
        "Backend Controllers": [_BACKEND_CONTROLLER, _BACKEND_RESOURCE],
        "Backend Services": [_BACKEND_SERVICE],
        "Backend Repositories": [_BACKEND_REPOSITORY],
        "Backend DTOs": [_BACKEND_DTO],
        "Database Migrations": [_BACKEND_MIGRATION],
        "Frontend Components": [_FRONTEND_COMPONENT],
        "Frontend Services": [_FRONTEND_SERVICE],
        "Frontend Models": [_FRONTEND_MODEL],
    }

    for category, globs in patterns.items():
        files: list[str] = []
        for pattern in globs:
            for f in project_dir.rglob(pattern.replace("**/", "")):
                if not any(skip in str(f) for skip in _SKIP_DIRS):
                    rel = f.relative_to(project_dir)
                    files.append(str(rel))
        if files:
            inventory[category] = sorted(files)

    return inventory


def _parse_java_entities(project_dir: Path) -> dict[str, list[str]]:
    """Quick-parse Java entity files for field names."""
    entities: dict[str, list[str]] = {}

    for pattern in [_BACKEND_ENTITY, _BACKEND_MODEL]:
        for f in project_dir.rglob(pattern.replace("**/", "")):
            if any(skip in str(f) for skip in _SKIP_DIRS):
                continue
            if "Test" in f.name:
                continue

            entity_name = f.stem
            fields: list[str] = []

            try:
                content = f.read_text(encoding="utf-8", errors="replace")
                for line in content.splitlines():
                    line = line.strip()
                    # Match: private Type fieldName; or private Type fieldName =
                    if line.startswith("private ") and (";" in line or "=" in line):
                        # Skip static fields
                        if "static " in line:
                            continue
                        parts = line.split()
                        if len(parts) >= 3:
                            field_name = parts[2].rstrip(";").rstrip("=").strip()
                            field_type = parts[1]
                            fields.append(f"{field_name}:{field_type}")
            except Exception:
                continue

            if fields:
                entities[entity_name] = fields

    return entities


def _list_frontend_components(project_dir: Path) -> list[str]:
    """List Angular component selectors or file names."""
    components: list[str] = []

    for f in project_dir.rglob("*.component.ts"):
        if any(skip in str(f) for skip in _SKIP_DIRS):
            continue
        if ".spec." in f.name:
            continue
        rel = f.relative_to(project_dir)
        components.append(str(rel))

    return sorted(components)


def _find_api_endpoints(project_dir: Path) -> list[str]:
    """Find REST endpoints grouped by controller."""
    by_controller: dict[str, list[str]] = {}

    try:
        result = subprocess.run(
            ["grep", "-rn", "--include=*.java",
             "-E", "@(Request|Get|Post|Put|Delete|Patch)Mapping"],
            capture_output=True, text=True,
            cwd=str(project_dir), timeout=10,
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                parts = line.split(":", 2)
                if len(parts) >= 3:
                    # Extract controller name from path
                    rel_path = parts[0]
                    controller = Path(rel_path).stem
                    annotation = parts[2].strip()
                    by_controller.setdefault(controller, []).append(annotation)
    except Exception:
        pass

    # Format as compact grouped output
    endpoints: list[str] = []
    for controller, annotations in sorted(by_controller.items()):
        methods = []
        for a in annotations:
            # Extract just the HTTP method and path
            a = a.strip()
            if "@RequestMapping" in a:
                # Class-level base path
                endpoints.append(f"**{controller}** {a}")
            else:
                methods.append(a)
        if methods:
            if not any(f"**{controller}**" in e for e in endpoints):
                endpoints.append(f"**{controller}**")
            for m in methods[:8]:  # limit per controller
                endpoints.append(f"  {m}")
            if len(methods) > 8:
                endpoints.append(f"  ... +{len(methods) - 8} more")

    return endpoints
