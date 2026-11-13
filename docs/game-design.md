# Native foundation

`color-flow-design.html` is the original visual and rules reference. Its references to other game-design files do not imply those files are present in this repository.

The initial native catalog contains five fixed numbered levels: three easy, one medium, one hard. This deliberately replaces the reference's all-easy opening for the foundation milestone; a 30-level catalog is deferred. Difficulty labels are provisional until human playtesting confirms them.

Columns fill from their lowest unpainted cell through the consecutive matching-color run, limited by available paint. Selecting a bucket highlights exactly the cells that a pour can fill. Any highlighted cell pours into that column. Only queue fronts are retrievable. Same-color retrieval recharges the existing bucket even with full slots; new colors use the first empty slot.

A win requires every cell painted, all buckets exhausted, and all queues empty. Full active slots with no available pour lose immediately. Any other non-winning state with no legal retrieval or pour also loses. There are no random moves, obstacles, or flood filling.

Progression is linear, with no level picker or completed-level replay. Victory offers Next Level; defeat offers Retry. Finishing level five offers Start Again, resetting to level one. Completed/result screens survive relaunch. The current unfinished level can be restarted after confirmation.

The deterministic engine has no UI, storage, or animation dependencies. The offline solver applies the same engine transitions and stores winning paths for regression testing; it is never used to generate or solve puzzles during gameplay. Level JSON keeps the reference's row orientation, tokens, slot count, and exact four-queue order.

Each legal move is committed and atomically saved before presentation begins. A pour is a single logical action, so interruption restores its complete result, without losing or duplicating paint. Bucket selection is saved too. Backgrounding cancels transient animation. Invalid saved board data restarts the recorded current level; unreadable or unknown-level data returns to level one. Save failures are visible and offer retry.

The native layout reserves pouring headroom and compresses spacing to fit the SE's 375 × 667-point display. Target colors remain visible as thick borders before painting; painted centers use saturated fills. Bucket quantities remain numeric. Accessibility labels name colors and quantities in English, and Reduce Motion avoids animated tilting and pulsing.
