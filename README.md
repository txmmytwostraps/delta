# Delta

The Android companion to [GDScript Practice](https://txmmytwostraps.github.io/gdscript-practice/): the same account, the same progress and the same daily run, as a real Godot app so it can work offline and show live scenes.

Delta is a Godot 4.7 project. All of the interface is drawn by Godot; there is no web view.

## What is here so far

- Sign in with GitHub (through the phone's browser) or with email and password, using the site's Supabase project. The session is kept on the phone, encrypted with a key tied to the device.
- The whole problem bank and the route inside the app, pulled from the site's repo at a pinned commit (`SITE_COMMIT`) by `tools/fetch-site.sh`, so the app works without a connection.
- Progress kept on the phone and synced with the account: solves, fail counts, drafts, the review queue and notes. Writes go into an outbox and are sent when there is a connection; a pull merges with the site's rules (solves are a union with the earliest date, the larger fail count, the newer draft, the review queue from the account, the newer note).
- The day's run assigned by the site's algorithm, so the phone and the site show the same set.
- The judge on the phone: the site's own judge scripts, pulled with the bank, compile the code and run the tests on a worker thread with a five-second limit. Results, printed output and error lines are shown the way the site shows them, and every verdict counts the way it does on the site (misses, solves, attempts, the review's result). Profile has a check that runs the site's test cases and compares the results.
- Four ways into every problem, switched with a segmented control: put the lines in order (the solution shuffled, with indentation shown as guides), fix the bug (the solution with one planted change, fixed by tapping a line and picking a replacement), what does this print (four answers, the wrong ones from buggy versions of the solution), and Type, a landscape editor with GDScript colouring, line numbers, a key row for the characters a phone keyboard hides, staged hints, the reference solution behind its two-miss lock, and drafts that save themselves. All four go through the judge and count the same way. The same seeded shuffle and the same planted bug as the site, for the same problem.
- Today shows the day's run with the review slot counting problems and concept cards like the site; Route is the vertical path through every lesson with the milestones between topics and the course lock; Concepts lists the 67 cards by lesson with a search box, a flashcard mode per lesson, and the day's card review (four a day, recorded on the same schedule as the site); Profile has the streak, level, full runs, the settings (new problems a day in the account, the reminder time on the phone), the weekly summary to copy, and the sync state.
- Settings live in the account's settings table like the site's: the course lock, the daily set size and the per-topic hint level overrides, so the site and the phone agree. Hint levels adapt the way the site's do (full, reduced, minimal from the rolling pass rate of the last 20 attempts), with an override per topic on the Route. The weekly summary is the site's This week text, word for word.
- Milestones, from the site's files: a script built in steps, with the stage on top drawn natively (the robot on its strip, or the health bar), buttons that call the user's own functions and replay the history through the judge, checks per step, the Godot checklist at the end, and the same step ids stored like solves so the site shows them. A step is done as lines to order, a bug to fix, or typed in the editor with the stage beside the code.
- Each role has one look: prompts as plain text, code in a block with an accent bar, numbered and coloured (orderable lines with a grip and arrows), answers as radio rows graded on Run, instructions as secondary text under the mode switch, and modes a problem does not have dimmed rather than offered. Type mode follows the phone's rotation: upright, the prompt collapses to a line above the code and opens a drawer; sideways, the side column sits beside the code.
- The streak counts active days with rest days: a full run earns one a week, held one at a time, spent on a missed day. The rule is written once in `scripts/sync.gd` and computed from the account rows, so the site and the phone agree. Profile and Today show the week as seven squares and the longest streak.
- The canvas is measured in half-points and, on a phone, sized from the screen's density, so a 14-point line of text is 14 points on every phone and a wider phone simply gets more room.
- The site's look: same colours, square corners, faint grid, dark only.

## Layout

- `scenes/` the screens. `main.tscn` picks sign-in or the tabs; `app.tscn` is the tab shell; `scenes/screens/` has one scene per tab; `problem.tscn` is a problem page, `scenes/modes/` its tap modes, `editor.tscn` the typed editor, `flashcards.tscn` the cards, `results_panel.gd` the shared results, `milestone.tscn` a milestone, `stage.gd` and `stage_panel.gd` its stage.
- `scripts/` shared code. `supabase.gd` sends requests; `auth.gd` holds the account; `store.gd` is the file everything is kept in; `bank.gd` reads the problems and route; `progress.gd`, `reviews.gd` and `notes.gd` carry the site's rules; `sync.gd` is the outbox and the merge; `grader.gd` runs the judge; `submission.gd` turns a verdict into progress; `fmt.gd` writes values the way the site does; `modes.gd` makes the puzzles (shuffled lines, planted bugs, wrong answers); `settings.gd` is the account settings row; `scaffold.gd` the adaptive hint levels; `week.gd` the weekly summary; `milestone_step.gd` marks steps done; `config.gd` has the project addresses; `streak.gd` does the day maths.
- `bank/` (not committed) the problem bank, route, cards, milestones and judge scripts, written by `tools/fetch-site.sh` from the site repo at the commit in `SITE_COMMIT`. Change problems in the site repo, then update `SITE_COMMIT` here.
- `theme/delta.tres` the Godot theme, generated by `tools/build_theme.gd` from the design tokens.
- `assets/` icons and fonts (Space Grotesk and IBM Plex Mono, SIL Open Font License).
- `export_presets.cfg` the Android export preset. `.github/workflows/android.yml` builds a debug APK on every push to main and publishes it as the `debug` pre-release.

## Building

Requirements: Godot 4.7.2. For an APK, also the Android SDK (build-tools 35) and a JDK 17; the workflow shows the exact steps.

```
tools/fetch-site.sh                              # first, and after changing SITE_COMMIT (needs curl, tar, node)
godot --headless --import --quit                 # first time, and after adding files
godot --headless -s tools/build_theme.gd         # after editing the theme tokens
godot                                            # run it on the desktop, phone-shaped
godot --headless --export-debug Android build/delta-debug.apk
```

For a quick look without a phone, the app can save a picture of a screen and quit:

```
godot -- --screenshot=shot.png --tab=profile
```

## Sign-in on the phone

GitHub sign-in opens the browser. When GitHub is done, Supabase sends the browser to `http://127.0.0.1:41337/callback`, which the app answers itself: it listens on that port while the sign-in is in progress. That address has to be on the Supabase project's list of allowed redirect URLs.

Accounts are created on the site; the app only signs in.
