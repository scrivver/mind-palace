# Quickstart: Sanctuary Health Status Page

## Prerequisites

- Working Mind Palace development environment (`nix develop`)
- Running full stack: `dev` or at minimum `start-infra` + `start-app`
- Both Engram and Reliquary services must be running

## Validation Scenarios

### Scenario 1: Status Page Renders Correctly

**Setup**: Full stack running with some ingested files.

**Steps**:
1. Open the Mind Palace app
2. Click **Status** in the sidebar
3. Observe the Sanctuary Health dashboard

**Expected**:
- [ ] Header shows "Sanctuary Health" with subtitle
- [ ] Engram Engine card displays with efficiency, active process, sync frequency
- [ ] Three metric tiles visible: Latency, Sync Speed, Uptime
- [ ] Storage Capacity section shows total/used bar and category breakdown
- [ ] Recent Activity section lists entries with icons and timestamps
- [ ] "View Archive" link appears if more than 20 activities exist

---

### Scenario 2: Activity Feed Shows Meaningful Entries

**Setup**: At least one file has been ingested and processed by Engram.

**Steps**:
1. Navigate to Status page
2. Scroll to Recent Activity section

**Expected**:
- [ ] Activity entries show with correct Material icons
- [ ] Descriptions reference actual filenames from the system
- [ ] Timestamps show relative times (e.g., "2 mins ago", "1 hour ago")
- [ ] Entries are ordered newest-first

---

### Scenario 3: Storage Data Matches File System

**Setup**: Files have been uploaded via the gallery upload flow.

**Steps**:
1. Upload 2–3 files of different types (e.g., image, PDF, text file)
2. Navigate to Status page
3. Compare Storage Capacity breakdown

**Expected**:
- [ ] Storage total increases after upload
- [ ] Uploaded image counts under "Media" category
- [ ] Uploaded PDF counts under "Documents" category
- [ ] Total file count in the Engram card matches gallery file count

---

### Scenario 4: Error Handling

**Setup**: Stop the Engram API service.

**Steps**:
1. While on the Status page, stop Engram: `pkill engram-api` (or stop via
   process-compose)
2. Pull to refresh the Status page

**Expected**:
- [ ] Engram Engine card shows degraded/error state
- [ ] Storage Capacity section still renders (from Reliquary)
- [ ] Activity section shows error state or "Unable to load" message
- [ ] The page does not crash
- [ ] Restarting Engram and refreshing restores full display

---

## Verification Commands

### Flutter Analysis

```bash
cd app && flutter analyze lib/screens/status_screen.dart
```

### Flutter Tests

```bash
cd app && flutter test
```

### Engram Go Tests

```bash
cd engram && go test ./backend/...
```

### Manual E2E Test

```bash
# Start full stack
dev

# Open http://localhost:2080 (or the Flutter desktop app)
# Navigate to Status page via sidebar
```

## Data Model and Contracts Reference

- **Data model**: [data-model.md](./data-model.md)
- **Engram Stats API**: [contracts/engram-stats-api.md](./contracts/engram-stats-api.md)
- **Engram Activity API**: [contracts/engram-activity-api.md](./contracts/engram-activity-api.md)
