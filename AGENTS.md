# Repository Guidelines

## Project Structure & Module Organization

This repository is a Nix-managed monorepo. The primary Flutter client lives in `app/lib/`, organized into screens, models, and service clients. Shared development infrastructure is defined in `infra/`, with root launchers in `bin/` and shell definitions in `shells/`.

`reliquary/`, `engram/`, and `synapse/` are Git submodules:

- `reliquary/`: Go storage API and Flutter frontend.
- `engram/`: Go API/watcher plus Python ingestion worker.
- `synapse/`: Go reconciliation and transfer workers.

Initialize components with `git submodule update --init --recursive`. Read each component's `README.md` and `CLAUDE.md` before making component-specific changes. Runtime state belongs under `.data/` and must not be committed.

## Build, Test, and Development Commands

Run commands from the repository root unless noted:

- `nix develop`: enter the complete Go, Python, Flutter, and infrastructure environment.
- `start-infra`: start PostgreSQL, RabbitMQ, MinIO, Caddy, and Authentik.
- `dev`: launch the backends, ingestion worker, Synapse worker, and desktop app in tmux.
- `start-app`: run only the main Flutter Linux client.
- `shutdown-infra`: stop managed infrastructure.
- `cd app && flutter analyze`: run Dart static analysis.
- `cd app && flutter test`: run Flutter tests.
- `cd reliquary/backend && go test ./...`: run the current Go unit tests.
- `cd engram && bin/test-ingest`: exercise Engram's end-to-end ingestion path.

## Coding Style & Naming Conventions

Use standard formatters: `gofmt` for Go and `dart format .` for Dart. Follow `flutter_lints` from `app/analysis_options.yaml`. Python uses four-space indentation, `snake_case` functions/modules, and type hints where they clarify interfaces. Use `PascalCase` for Dart types, `lowerCamelCase` for Dart members, and idiomatic Go exported/unexported naming. Keep environment variables uppercase, for example `RABBITMQ_AMQP_PORT`.

## Testing Guidelines

Place Go tests beside source as `*_test.go`, Flutter tests under `test/` as `*_test.dart`, and Python tests as `test_*.py`. Add focused tests for changed behavior; use integration scripts when changes cross storage, queues, or databases. Run the relevant component suite before submitting.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, often scoped by component, such as `gallery: add tag filter` or `dev shell: add tesseract`. Keep commits focused. For submodule changes, commit inside the submodule first, then update the root pointer explicitly.

Pull requests should explain behavior, list verification commands, link relevant issues, and include screenshots for Flutter UI changes. Call out schema, infrastructure, environment-variable, or submodule updates.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->
