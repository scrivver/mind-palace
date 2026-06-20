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

## ContainerBuildJob

**Purpose**: Represents a Nix build output that produces one local OCI/Docker
image tarball before packaged Compose startup.

**Fields**:
- `owner_repo`: repository that owns the build job, for example `engram` or
  `synapse`
- `target`: owning flake package target, for example `api-container` or
  `worker-container`
- `platform_image_name`: root Compose image name after load/tag, for example
  `mind-palace-engram-api:latest`
- `source_component`: root, Reliquary, Engram, or Synapse
- `build_artifact`: binary package, Python runtime, static assets, or image
  tarball produced by Nix
- `loaded_image`: local image name and tag expected by `docker-compose.yml`
- `runtime_entrypoint`: executable used as the container entrypoint
- `healthcheck`: command or endpoint used by Compose
- `dependencies`: other build jobs or component lock files required for a
  reproducible build

**Validation rules**:
- Every application image referenced by Compose must have a build job.
- Component implementation build jobs must live in the owning child repo.
- Build jobs must be runnable from the owning repo with `nix build .#<target>`.
- Build jobs must be runnable by root orchestration with
  `nix build path:$PROJECT_ROOT/<component>#<target>`.
- Build jobs must not require source bind mounts at runtime.
- Build jobs must fail during build if required locked dependencies are missing.
- Runtime dependency downloads during Compose startup are not allowed.
- Root build jobs must remain thin aliases, image tags, or root-owned app/ingress
  artifacts; they must not duplicate component dependency packaging.

**State transitions**:
- `not-built` -> `building` -> `loaded`
- `building` -> `failed`
- `loaded` -> `stale` when source, lock files, or image targets change

## ContainerImage

**Purpose**: Describes a loaded application image used by packaged Compose.

**Fields**:
- `image_name`: stable local image name, for example
  `mind-palace-synapse-worker:latest`
- `service`: Compose service that runs the image
- `component`: owner component
- `entrypoint`: binary or script started as PID 1
- `ports`: exposed container ports, if any
- `environment`: required environment variables
- `runtime_tools`: non-application tools needed in the image, such as
  `curl`, `cacert`, `libmagic`, OCR tools, or media extraction tools

**Validation rules**:
- Image names must match the packaged Compose contract.
- API images must expose a health endpoint or healthcheck command.
- Worker images may use a PID liveness healthcheck when no HTTP endpoint exists.
- Images must include CA certificates when calling HTTPS services.
- Secret values must be provided by Compose environment, not baked into the
  image.

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
