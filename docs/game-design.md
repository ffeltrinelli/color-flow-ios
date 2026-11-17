# Native gameplay

Color Flow is an offline queue-management puzzle. The prototype replaces the previous campaign with ten fixed levels: square 10 × 10 boards on odd IDs and circular ten-lane, five-band boards on even IDs. Levels 1–4 are easy, 5–8 medium, and 9–10 hard. Easy and medium have three active bucket slots; hard has two. Difficulty labels remain provisional until human playtesting confirms them.

## Boxes and liquid

Every container has one color and logical dimensions between 1 × 1 and 3 × 3. Capacity equals width times height. On square boards, paint fills from the bottom across the whole interior width: one unit fills a 2 × 2 box to one quarter of its height and a 3 × 3 box to one ninth. Partial fills persist between buckets and game sessions. Full boxes disappear as a whole; boxes never merge or mix colors.

Larger containers occupy square/circular logical cell counts of 20/10, 24/12, 35/18, 40/20, and 50/25 across the five pairs. Square levels include each difficulty's complete shape family; circles sample a subset, including wide arcs. Square boards require 100 paint units and circles 50; supply exactly matches each color's capacity.

Circular containers are annular sectors: logical width spans lanes and height spans bands. The center hub has one quarter of the board radius. Paint is a concentric band expanding outward from the inner curved edge, with occupied area proportional to the fill ratio, everywhere on the circle. It does not slosh or follow screen gravity. Shrinking containers retain their logical capacity and paint units.

## Pouring and gravity

On square boards, a box is accessible through any part of its top edge with a clear vertical path from above the board. One exposed column is sufficient even when another part of a wide box is covered. Tap an active bucket to fill the leftmost exposed matching box. The engine scans columns from left to right and uses the first remaining box in each column. A box spanning several columns remains one shared container.

Pour until that box is full or the bucket empties. After a removal, gravity settles the entire board before targeting resumes with the same bucket. Boxes fall straight down without rotating, sliding, splitting, or spilling paint. Any support under the base stops a fall, allowing wide boxes to bridge gaps. Each gravity step simultaneously moves every box with clear space under its entire footprint down one row, repeating until stable. No paint or extra player action is needed for falling.

Paint without an exposed matching target stays in its slot. Clearing another color may make it usable, but that bucket requires another tap. The grid has no tap actions.

On circular boards, columns map clockwise to angular lanes and rows map from the outside inward. Target selection restarts from the first lane beside the divider for every target, using the same exposed-entry and support rules. Blocks never cross the first/last lane boundary. Align the exposed entry lane, which need not be a wide arc's midpoint. The board turns counterclockwise only; the bucket lip and pour pointer remain horizontally centered. The stream is hidden until alignment finishes and throughout removal and falling.

Inward falls reduce both radii by one band per engine step, preserving angular span, radial thickness, capacity, and fill percentage. Wide arcs can bridge gaps until their inward supports disappear. A thin white divider spans the full annulus and remains visible after blocks disappear. Its short external end has a small circular head; a separate compact counterclockwise arrow follows the rim beside it with a small gap. There are no lane numbers or target highlights.

## Queues and outcomes

Only the front tin of each of four queues is retrievable; two further tins remain visible for planning. Retrieval loads the first empty slot or recharges an existing same-color bucket, even with all slots occupied. Loading never starts a pour. Empty and blocked buckets cannot be activated.

An empty board wins immediately. Full slots with no available pour lose, even if a blocked color could be recharged. Other non-winning states with no legal retrieval or pour also lose. Paint supply exactly matches each color's total box capacity, so a valid cleared board exhausts all paint.

Progression is linear: victory offers Next Level, defeat offers Retry, and completing level 10 offers Start Again. Retrying an unfinished level from the top-right settings menu requires confirmation. A tilted golden badge shows the current level beside “Level of 10,” with difficulty underneath. Its combined accessibility label reads “Level 6 of 10.” The 44 × 44-point settings button uses a 24-point gear and opens Hint, Stats, and Retry level. Hint uses a yellow bulb; Stats uses a histogram icon. Results use centered cartoon overlays with prominent action buttons. There is no level picker or Exit game control. Blocked buckets display a lock above their artwork, leaving paint quantities visible.

## Authored data and saved state

`levels.json` defines board kind and dimensions and boxes with stable IDs, zero-based top-left row/column, width, height, and color, plus slot counts and paint queues. Validation rejects missing coverage, overlaps, out-of-bounds boxes, duplicate IDs, invalid sizes, and unequal paint supply. Level JSON describes initial geometry; runtime rows and fill amounts belong in saved state.

Levels are generated offline with a randomized algorithm and bundled as fixed JSON. Generation and on-demand hints share the solver and the app's engine transitions; neither requires an LLM or network. Stored winning paths cover all levels; stored losing alternatives cover every medium and hard level. See [level generation](level-generation.md). Search size and solution length do not establish human difficulty, and inconclusive searches prove neither solvability nor impossibility.

Save version 5 restores exact settled state and the last aligned circular lane. Version-4 saves retain decoded lifetime statistics but restart at level one with a fresh attempt, without recording the discarded attempt as a failure. Unknown/unreadable saves start fresh; invalid version-5 snapshots restart their recorded level while preserving decoded statistics. Retry and level advancement reset orientation to the first lane. Moves and final presentation orientation are saved before animation; interruption displays the completed move without replay.

Save failures remain visible and offer retry. Completed and lost states survive relaunch.

## Statistics

Settings → Stats opens a cream cartoon table with Easy, Medium, and Hard rows, win percentage, and average win time. Percentages are rounded to whole numbers and equal wins divided by wins, failures, and confirmed manual restarts. Each attempt contributes one result; retrying a failure does not count twice. Cancelling a restart changes nothing; restarting before the first move still counts. Starting the campaign again retains lifetime totals. A centered Clear stats button with an eraser icon opens a confirmation dialog. Confirming clears all recorded totals and averages; cancelling changes nothing. The current board and active attempt, including its elapsed time, are retained.

Average time includes successful attempts only. It counts foreground gameplay and automatic pours, including the final animation, and pauses during menus, hints, dialogs, result overlays, splash, and app inactivity. Durations through 60 seconds use seconds; longer averages use minutes with one decimal. Missing samples appear as “—”.

Current-version saves without timing metadata cannot contribute unknown historical duration. Existing result screens create no historical result. Fresh attempts are timed normally. Outcome counts are saved with the settled move before presentation; winning time is finalized after animation or interruption. Restoration finalizes a pending win from its saved elapsed checkpoint without recounting the result or including time away.

## Hints

Hint opens a centered, scrollable Paint river route: five numbered peach stepping stones along the glossy turquoise river from the approved Paint river reference, beside instructions and miniature queue or bucket rows. See [artwork notes](hint-artwork.md). Each target is marked with a ring and tap icon; color names, position numbers, and quantities remain explicit. Each retrieval or pour counts as one move. Near victory, the route contains only the remaining moves.

Hints reuse a bundled winning path only after replay verifies it and finds the exact current state on that path. Otherwise they search from the current settled board in cancellable background work. They show a prefix of a complete verified winning path without executing it or changing saves. Closing the overlay or backgrounding cancels the request; stale results are discarded. Gameplay is unavailable behind modal overlays. A proven dead end suggests retrying, while a timeout explicitly leaves solvability unknown. Pending startup and search states show a loading wheel; only a completed inconclusive result can display a timeout. Runtime search shows a loading wheel and runs for up to ten seconds, without a fixed visited-state cutoff. Closing the overlay cancels it immediately. Stable pour-first, index-ordered traversal gives repeatable paths when the search completes; a time cutoff remains inconclusive.

## Animation and splash

The engine owns targeting and gravity and returns ordered fill, removal, and simultaneous-fall events. The app commits and saves the complete resulting move before animating it, with input locked. Each added paint unit fills over 0.25 seconds; removal pauses for 0.1 seconds; each falling row takes 0.1 seconds. Square bucket travel between entry columns takes 0.25 seconds. Circular alignment takes approximately 0.25–0.75 seconds according to turn distance; already aligned targets do not turn. The stream stays hidden during removal, falling, and travel. Reduce Motion uses brief steps without bucket travel, wheel rotation animation, or tilting. Backgrounding cancels presentation; restoration shows the completed move without replaying it.

Every launch and return from the background shows a three-second splash with the selected Cozy Pour icon, wider peach breathing room, a playful golden Color Flow logo with blue outline and turquoise shadow, and the subtitle “for Luisa”. Game controls are absent from touch and accessibility during the splash; progress is preserved. A temporary system interruption does not retrigger a completed splash. See [icon proposals](icon-proposals/README.md) for artwork and prompts.

The board uses four-point side margins on the iPhone SE's 375 × 667-point screen. Controls and three visible queue entries fit without scrolling. Read-only box descriptions report color, current row/column or band/lane, dimensions, and filled/total paint units. Circular geometry reserves margin for the white marker. Bucket labels communicate readiness or blockage in English.
