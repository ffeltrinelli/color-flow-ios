# Native gameplay

Color Flow is an offline queue-management puzzle. The catalog contains three fixed 10 × 10 levels: easy with three active bucket slots, then medium and hard with two. Difficulty comes from paint ordering and limited storage; labels remain provisional until human playtesting confirms them.

## Clearing the board

Only the topmost remaining block in a column is accessible. Tap an active bucket to pour into the leftmost column topped by its color. One paint unit fills and removes one block. After each removal, the engine checks the columns again from left to right, continuing until the bucket is empty or no exposed block matches. Colors below a different-colored block are inaccessible. Removed blocks leave gaps; remaining blocks never shift.

For example, a red bucket clears consecutive exposed red blocks in the first eligible column. If blue is revealed, it moves to the next column topped by red. Unused red paint stays in its slot. Clearing blue later may make red usable again, but another red-bucket tap is required.

The grid has no tap actions. Queue fronts load paint into the first empty slot or recharge an existing same-color bucket, including when all slots are occupied. Loading never starts a pour. Only the front tin of each of the four queues is retrievable; the next two tins remain visible for planning. Empty and blocked buckets cannot be activated.

An empty grid wins immediately. Full slots with no available pour lose, even if a blocked color could be recharged. Other non-winning states with no legal retrieval or pour also lose. Authored levels supply exactly the paint required for every color, so a valid cleared board also exhausts all paint.

## Levels and progression

Easy introduces automatic targeting with red and blue exposed first, then requires managing green and yellow dependencies. Medium mixes four colors throughout the grid with only two slots. Hard adds purple, layered dependencies, and longer sequences of constrained retrievals. All three contain 100 blocks; additional difficulty does not come from increasing board length between levels.

Levels are fixed JSON, never generated or solved at runtime. The offline solver uses the same engine transitions as the app. Stored winning paths cover all levels, and stored losing alternatives cover medium and hard. Neither a solution length nor a solver's visited-state count establishes human difficulty.

Progression is linear. Victory offers Next Level; defeat offers Retry. Completing level three offers Start Again. Restarting an unfinished level requires confirmation. There is no level picker or completed-level replay.

## State and presentation

The engine owns automatic targeting, paint accounting, and outcomes. A pour result contains the ordered removed cells and complete resulting state. The app saves that state atomically before presenting the sequence, then animates filling, disappearance, and movement between columns with input locked. Each block visibly fills for 0.25 seconds, followed by a 0.1-second removal pause; moving to another column takes 0.25 seconds. The stream disappears immediately when a column run finishes and stays hidden during travel; only the bucket animates between columns. A nine-block pour spanning six columns takes about 4.8 seconds. Readability takes priority over a fixed total-duration cap. Reduce Motion skips bucket travel and tilting and uses brief steps. Backgrounding cancels presentation, and relaunch restores the complete move without replaying it.

Save version 2 intentionally resets every old-game save to new level one. Current-version invalid board data restarts its recorded level; unreadable, unknown-version, or unknown-level data starts level one. Save failures remain visible and offer retry. Completed and lost states survive relaunch.

The board uses four-point side margins on the iPhone SE's 375 × 667-point screen. Controls and three visible queue entries fit without scrolling. Blocks retain colored borders until removed and briefly fill during pouring. Bucket quantities remain numeric. Read-only column accessibility summaries list remaining colors from top to bottom; bucket labels communicate readiness or blockage in English.
