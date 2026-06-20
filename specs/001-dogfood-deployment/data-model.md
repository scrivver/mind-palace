# Data Model: Dogfood Deployment

This feature models operational configuration and verification artifacts rather
than application domain records.

## DeploymentPath

**Purpose**: Represents a supported way to run Mind Palace for dogfooding.

**Fields**:
- `name`: `local-dev` or `packaged-compose`
- `entry_command`: documented command that starts the path
- `public_entrypoint`: URL or application entry point participants use
- `state_locations`: reusable and disposable state locations
- `shutdown_command`: documented command that stops the path
- `reset_command`: documented command that removes state after explicit consent
- `known_differences`: expected behavior differences from the other path

**Validation rules**:
- Must have exactly one documented startup path.
- Must document shutdown and reset separately.
- Must identify whether internal services are exposed.
- Must identify where logs and service status can be inspected.

**State transitions**:
- `not-prepared` -> `starting` -> `healthy`
- `starting` -> `failed`
- `healthy` -> `degraded`
- `healthy` or `degraded` -> `stopped`
- `stopped` -> `reset`

## ServiceGroup

**Purpose**: Groups related managed processes for status, logs, and deployment.

**Fields**:
- `name`: infrastructure, identity, storage, metadata, movement, app, ingress
- `services`: concrete services in the group
- `health_signal`: command, endpoint, or status condition used for readiness
- `dependencies`: service groups that must be ready first
- `log_source`: where a participant reads logs

**Validation rules**:
- Each service must belong to one primary group.
- Health checks must be observable from the deployment path.
- Dependencies must avoid cycles.

## RuntimeConfiguration

**Purpose**: Captures configuration values required to start a deployment path.

**Fields**:
- `name`: variable or setting name
- `used_by`: service or service group
- `default_value`: safe local default or placeholder
- `required_for_startup`: boolean
- `secret`: boolean
- `shared_use_requires_change`: boolean
- `documentation`: human-readable description

**Validation rules**:
- Secret values in examples must be obvious placeholders.
- Packaged deployment must mark secrets that require replacement before sharing.
- Runtime state must live under `.data/` for local dev or documented volumes for
  packaged Compose.

## DogfoodSmokeTest

**Purpose**: Defines the repeatable verification that proves the environment is
usable for dogfooding.

**Fields**:
- `deployment_path`: local-dev or packaged-compose
- `preconditions`: prerequisites and clean/reused state note
- `steps`: ordered participant actions
- `expected_results`: observable results
- `diagnostics_on_failure`: status/log/config data to collect

**Validation rules**:
- Must cover startup and shutdown.
- Must verify the public entry point.
- Must include at least one storage, metadata, and movement or reconciliation
  check when those capabilities are present.
- Must not require copying secrets into reports.

## FailureReport

**Purpose**: Standardizes dogfooding feedback when startup or smoke tests fail.

**Fields**:
- `deployment_path`: local-dev or packaged-compose
- `state_freshness`: fresh, reused, migrated, or unknown
- `failed_service`: service name or unknown
- `status_snapshot`: process-compose or compose status output
- `log_excerpt`: relevant sanitized logs
- `configuration_source`: `.env`, shell environment, or generated config
- `reproduction_steps`: concise ordered steps

**Validation rules**:
- Must not include credentials, tokens, or generated secrets.
- Must include the deployment path and state freshness.
- Must identify whether the failure happened during startup, smoke testing, or
  shutdown/reset.
