# Native gameplay

Color Flow is an offline queue-management puzzle. Three authored 10 × 10 levels progress through easy, medium, and hard. Easy has three active bucket slots; medium and hard have two. Difficulty labels remain provisional until human playtesting confirms them.

## Boxes and liquid

Every box has one color and a rectangular size between 1 × 1 and 3 × 3. Capacity equals width times height. Paint fills from the bottom across the whole interior width: one unit fills a 2 × 2 box to one quarter of its height and a 3 × 3 box to one ninth. Partial fills persist between buckets and game sessions. Full boxes disappear as a whole; boxes never merge or mix colors.

Larger boxes occupy 20%, 40%, and 60% of easy, medium, and hard board area. Easy introduces 1 × 2 and 2 × 1. Medium adds 1 × 3, 3 × 1, and 2 × 2. Hard also includes 2 × 3, 3 × 2, and 3 × 3. All boards initially cover 100 cells and require exactly 100 paint units; larger boxes reduce the number of containers rather than increasing total paint.

## Pouring and gravity

A box is accessible through any part of its top edge with a clear vertical path from above the board. One exposed column is sufficient even when another part of a wide box is covered. Tap an active bucket to fill the leftmost exposed matching box. The engine scans columns from left to right and uses the first remaining box in each column. A box spanning several columns remains one shared container.

Pour until that box is full or the bucket empties. After a removal, gravity settles the entire board before targeting resumes with the same bucket. Boxes fall straight down without rotating, sliding, splitting, or spilling paint. Any support under the base stops a fall, allowing wide boxes to bridge gaps. Each gravity step simultaneously moves every box with clear space under its entire footprint down one row, repeating until stable. No paint or extra player action is needed for falling.

Paint without an exposed matching target stays in its slot. Clearing another color may make it usable, but that bucket requires another tap. The grid has no tap actions.

## Queues and outcomes

Only the front tin of each of four queues is retrievable; two further tins remain visible for planning. Retrieval loads the first empty slot or recharges an existing same-color bucket, even with all slots occupied. Loading never starts a pour. Empty and blocked buckets cannot be activated.

An empty board wins immediately. Full slots with no available pour lose, even if a blocked color could be recharged. Other non-winning states with no legal retrieval or pour also lose. Paint supply exactly matches each color's total box capacity, so a valid cleared board exhausts all paint.

Progression is linear: victory offers Next Level, defeat offers Retry, and completing level three offers Start Again. Restarting an unfinished level requires confirmation. There is no level picker.

## Authored data and saved state

`levels.json` defines board dimensions and boxes with stable IDs, zero-based top-left row/column, width, height, and color, plus slot counts and paint queues. Validation rejects missing coverage, overlaps, out-of-bounds boxes, duplicate IDs, invalid sizes, and unequal paint supply. Level JSON describes initial geometry; runtime rows and fill amounts belong in saved state.

Levels are never generated or solved at runtime. The offline solver uses the app's engine transitions. Stored winning paths cover all levels; stored losing alternatives cover medium and hard. Search size and solution length do not establish human difficulty, and inconclusive searches prove neither solvability nor impossibility.

Save version 3 resets all earlier saves to level one. Invalid current-version state restarts its recorded level; unreadable, unknown-version, or unknown-level saves start level one. Saved states validate geometry, support, integer fill bounds, queue positions, bucket uniqueness, and paint conservation. Save failures remain visible and offer retry. Completed and lost states survive relaunch.

## Animation and splash

The engine owns targeting and gravity and returns ordered fill, removal, and simultaneous-fall events. The app commits and saves the complete resulting move before animating it, with input locked. Each added paint unit fills over 0.25 seconds; removal pauses for 0.1 seconds; each falling row takes 0.1 seconds. Bucket travel between entry columns takes 0.25 seconds. The stream stays hidden during removal, falling, and travel. Reduce Motion uses brief steps without bucket travel or tilting. Backgrounding cancels presentation; restoration shows the completed move without replaying it.

Every launch and return from the background shows a three-second splash with the selected Cozy Pour icon, wider peach breathing room, a playful golden Color Flow logo with blue outline and turquoise shadow, and the subtitle “for Luisa”. Game controls are absent from touch and accessibility during the splash; progress is preserved. A temporary system interruption does not retrigger a completed splash. See [icon proposals](icon-proposals/README.md) for artwork and prompts.

The board uses four-point side margins on the iPhone SE's 375 × 667-point screen. Controls and three visible queue entries fit without scrolling. Read-only box descriptions report color, current position, dimensions, and filled/total paint units. Bucket labels communicate readiness or blockage in English.
