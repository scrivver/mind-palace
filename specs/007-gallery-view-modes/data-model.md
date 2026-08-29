# Data Model: Gallery View Modes

## GalleryViewMode

Represents the visual layout used for visible gallery items.

**Fields**

- `grid`: Current thumbnail/card layout.
- `list`: Dense row layout for scanning metadata.

**Validation Rules**

- Unknown route values default to `grid`.
- Changing view mode must not change search, filters, grouping mode, current folder path, or loaded files.

## GalleryGroupingMode

Represents how files are organized before rendering.

**Fields**

- `folders`: Show derived folder entries plus files directly inside the current folder.
- `allFiles`: Show all matching files in one flat result set with path context.

**Validation Rules**

- Unknown route values default to the implementation default, expected to be `allFiles` if preserving current behavior is prioritized or `folders` if folder browsing becomes the new primary default.
- Changing to `allFiles` ignores current folder path for visibility but does not need to erase it.
- Changing to `folders` restores folder navigation using the current path if valid, otherwise root.

## GalleryFolderPath

Frontend-normalized directory path for folder navigation.

**Fields**

- `segments`: Ordered directory names.
- `path`: Slash-joined path, empty string for root.

**Validation Rules**

- No leading or trailing slash.
- Empty path means folder root.
- Reject or normalize `.` and `..` segments.
- If the path no longer exists in the visible file set, fall back to the nearest existing ancestor or root.
- Must be URL-encoded when stored in `/vault?path=...`.

**State Transitions**

- `openFolder(childPath)`: sets `path` to the child folder.
- `goUp()`: removes the last segment; root remains root.
- `setGrouping(allFiles)`: preserves the value but visibility ignores it.
- `setGrouping(folders)`: validates the path against visible folder data.

## FolderEntry

Frontend-derived item representing a directory that contains at least one visible descendant file.

**Fields**

- `name`: Last segment of the folder path.
- `path`: Normalized full folder path from gallery root.
- `count`: Number of visible descendant files or visible direct/descendant items, depending implementation copy.

**Relationships**

- Derived from one or more `EngramFile` records.
- Rendered as a folder card in grid mode or folder row in list mode.

**Validation Rules**

- Folder entries must not be emitted during global search unless implementation explicitly supports folder search results.
- Root is not a `FolderEntry`; it is represented by empty `GalleryFolderPath`.
- Entries are sorted predictably, folders before files.

## GalleryFileProjection

Frontend projection of an existing `EngramFile` for the active view/grouping mode.

**Fields**

- `file`: Source `EngramFile`.
- `displayName`: Existing `filename`.
- `displayPath`: User-facing path with storage/user prefixes removed where possible.
- `directoryPath`: Parent directory of `displayPath`, empty for root.
- `relativeLabel`: File label relative to the current folder or full display path in all-files/search mode.
- `typeLabel`: Short MIME/type label for rows and cards.
- `sizeLabel`: Existing formatted size.
- `modifiedLabel`: Existing relative or date-formatted modified time.

**Validation Rules**

- `displayPath` must never be empty; fall back to `filename` or basename of `filePath`.
- Duplicate filenames in different directories must remain distinguishable in all-files mode.
- Projection must not mutate `EngramFile` or backend data.

## GalleryRouteState

Route-level representation of gallery UI state.

**Fields**

- `q`: Existing search query.
- `type`: Existing file-type filter.
- `tags`: Existing comma-separated tag filter.
- `view`: `grid` or `list`.
- `group`: `folders` or `all`.
- `path`: URL-encoded normalized folder path.

**Validation Rules**

- Omit default values from generated route URLs where practical.
- Invalid `view`, `group`, or `path` values must not crash the gallery.
- Existing query parameters for search/type/tags must continue to round-trip.
