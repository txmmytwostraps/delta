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
- Four tabs, each with its icon: Today, Route, Concepts, Profile. Lists are rows (52 points, a hairline between, marker · title · value), only the current row carries the accent bar; section headers stick to the top while the list scrolls; each screen has one primary button fixed above the tab bar.
- Today: the date, the streak with the week row, the run as three rows (one "Day done" row with show/hide once it is done), the level bar, and Keep going: the current topic, a drill, the cards. The button starts or continues the run: Start run goes through the reviews, the new problems and the extra in sequence with "Run · n of N" and a bar across the top of each problem, then a Run done screen with the time, the XP earned and the streak. Back leaves the run and Today offers Continue run.
- Route, matching the site's: "You are here" as one line with a segment bar, a dim line with the totals and the course position (change it in Profile), then the lessons in the site's five stages. Each stage has a header with a bar and a count; only the stage holding the current lesson is open until tapped, and the choice is remembered. Inside, one node per lesson on a left line (a filled square done, a ring for the current one, a hollow square ahead, a dim dot locked): the current lesson is the only card (its line, a segment bar, the hints line, Any problem · Drill · Request more, Continue); other lessons are rows that open their actions when tapped; milestones are amber tiles across the path, dashed until done. Any problem lists a topic's problems as rows. Drill serves variants with fresh numbers (the site's variants.js rule, rolled on the phone and answered by the reference solution through the judge); a drill counts as an attempt, never a solve or a miss.
- Concepts: the search box, one row per lesson with its card count that opens the cards as chips with a Flip through button, the lessons past the course position as one locked row, and the day's card review as the button.
- Profile: the character beside the name (the milestone robot, its health once milestone 2 gives it some, the gallery link), four tiles (streak, longest, level, XP), the week row, the settings as rows with steppers and a toggle (new problems a day, course through lesson, the reminder, the hint levels page), the weekly summary and the judge check, and one line with the version, About and Sign out.
- A problem: Back and "Run · n of N" on one line with the bar under it, the topic and mode as a kicker, the title, the prompt, the instruction line, the code block, the expected outcome on one line with "Other ways" for the rest (the other modes, Type, Reset, the note). One default mode per problem: Print for print-style problems, Order otherwise; a milestone step opens typed. The bottom bar is Run, a "?" that opens the hint drawer, and ✎ for the editor. The verdict panel buzzes: one short pulse on a pass, two on a miss; the next problem slides in.
- First run: three screens after the first sign-in on a phone (a day, the Route, your character), shown once, with a link to About.
- What the site has, the phone has too. The Gallery (from Profile's Open gallery): your character so far with what it can do, and one card per milestone; a finished one runs on its stage with the script it was finished with. Milestones 1 to 5 render and grade on the phone, with the stage kinds the site draws (move, health, walk, bag, fight). The Nudge, the site's built-in helper: inside the hint drawer and the editor's hints, it sends the problem, the code and the failing checks to the site's Supabase function with the signed-in token, shows the pointer it returns, counts as a hint opened, and the function keeps the daily cap. Notes under Profile: every note, unresolved first, each opening its problem, the resolved flag synced as on the site. Stats under Profile: the numbers, the badges, the weak spots (linking into the topic's problems), the sixteen-week activity grid and the per-topic table. About: the short version of the site's About, from its README at the pinned commit.
- Settings live in the account's settings table like the site's: the course lock, the daily set size and the per-topic hint level overrides, so the site and the phone agree. Hint levels adapt the way the site's do (full, reduced, minimal from the rolling pass rate of the last 20 attempts), with an override per topic on the Route. The weekly summary is the site's This week text, word for word.
- Milestones, from the site's files: a script built in steps, with the stage on top drawn natively (the robot on its strip, or the health bar), buttons that call the user's own functions and replay the history through the judge, checks per step, the Godot checklist at the end, and the same step ids stored like solves so the site shows them. A step is done as lines to order, a bug to fix, or typed in the editor with the stage beside the code.
- XP and levels with the site's rule, computed from the account rows so both show the same number: 10 XP for the first solve of a problem, 5 for a review passed on its due day (once per problem per day, concept cards included), 50 for a milestone step, nothing for practice-again or late reviews; level = 1 + floor(XP / 500). Review attempts are logged as the site logs them (`review` on the due day, `review-late` otherwise), card reviews as attempts too. "Level N · XP" with a thin bar sits on Profile and at the top of Today; the pass line on the verdict panel says what the pass earned ("+10 XP · first solve"). The last problem of a topic leads to the topic-cleared screen: the topic, ✓ N/N, the XP it earned, what it unlocked, when its reviews start, and one button to the next thing; shown once, and again from the Route.
- One verdict for every mode. After Run in Order, Bug, Print, Type and a milestone step, the same panel slides up over the bottom bar and stays until dismissed: a pass says "✓ Correct" with the tests passed and offers Next › (the next unsolved problem in the topic, the next review in a review run, or the next milestone step) and Review (the solved state, every check ticked, Next › kept in the bar); a miss says "✗ Not yet" with the first failing check or the compile error and its line, and offers Try again (everything left as it was) and Hint (the next hint that may open, above the checks). Flashcards keep Got it / Not yet as their verdict.
- Each role has one look: prompts as plain text, code in a block with an accent bar, numbered and coloured (orderable lines with a grip and arrows), answers as radio rows graded on Run, instructions as secondary text under the mode switch, and modes a problem does not have dimmed rather than offered. Type mode follows the phone's rotation: upright, the prompt collapses to a line above the code and opens a drawer; sideways, the side column sits beside the code.
- The streak counts active days with rest days: a full run earns one a week, held one at a time, spent on a missed day. The rule is written once in `scripts/sync.gd` and computed from the account rows, so the site and the phone agree. Profile and Today show the week as seven squares and the longest streak.
- The canvas is measured in half-points and, on a phone, sized from the screen's density, so a 14-point line of text is 14 points on every phone and a wider phone simply gets more room.
- A daily reminder, off until turned on in Profile: one notification at the chosen time, only when reviews are due or the run is not done, through a small Android plugin (`android/plugin`) that the workflow compiles. Profile also shows the version, and an Update button when a newer release is on GitHub.
- The site's look: the same tokens (panel, line, border, muted, dim, text, blue), square corners, dark only. Prose (goals, hints, explainers, cards, instructions) is Space Grotesk at 14 points; code, labels, numbers, rows and the editor stay IBM Plex Mono. "Text size · S / M / L" in Profile scales the prose only and lives in the same place the site keeps it (`_text_size` inside the settings row's hint_overrides). A faint grid sits on the background; every surface that carries text (panels, rows, code blocks, the top bar and the tab bar) is opaque, so the grid lives in the margins; the milestone stage keeps its own grid. The top bar and the tab bar are bands with a 2-unit edge. At most three uppercase tracked labels per screen.

## Layout

- `scenes/` the screens. `main.tscn` picks sign-in or the tabs; `app.tscn` is the tab shell; `scenes/screens/` has one scene per tab (`screen_header.tscn` the icon and title on top); `problem.tscn` is a problem page, `scenes/modes/` its tap modes, `editor.tscn` the typed editor, `flashcards.tscn` the cards, `results_panel.gd` the shared results, `verdict_panel.gd` the verdict over the bottom bar, `milestone.tscn` a milestone, `stage.gd` and `stage_panel.gd` its stage, `topic_cleared.tscn` the topic-cleared screen, `page.tscn` the shape of the small pages (`topic_problems`, `hint_levels`, `run_done`, `first_run`, `gallery`, `notes_list`, `stats`, `about`).
- `scripts/` shared code. `supabase.gd` sends requests; `auth.gd` holds the account; `store.gd` is the file everything is kept in; `bank.gd` reads the problems and route; `progress.gd`, `reviews.gd` and `notes.gd` carry the site's rules; `sync.gd` is the outbox and the merge; `grader.gd` runs the judge; `submission.gd` turns a verdict into progress; `fmt.gd` writes values the way the site does; `modes.gd` makes the puzzles (shuffled lines, planted bugs, wrong answers); `settings.gd` is the account settings row; `scaffold.gd` the adaptive hint levels; `week.gd` the weekly summary; `milestone_step.gd` marks steps done; `config.gd` has the project addresses; `streak.gd` does the day maths; `variants.gd` rolls drills; `requests.gd` is the Request more brief; `icon.gd` draws the stroke icons; `sticky_header.gd` keeps a section header at the top of a list; `nudge.gd` talks to the site's nudge function; `about_text.gd` reads the site's README; `path_node.gd` and `dashed_box.gd` draw the Route's nodes and milestone tiles.
- `bank/` (not committed) the problem bank, route, cards, milestones, the site's README (for About) and judge scripts, written by `tools/fetch-site.sh` from the site repo at the commit in `SITE_COMMIT`. Change problems in the site repo, then update `SITE_COMMIT` here.
- `theme/delta.tres` the Godot theme, generated by `tools/build_theme.gd` from the design tokens.
- `assets/` icons and fonts (Space Grotesk and IBM Plex Mono, SIL Open Font License).
- `android/plugin/` the reminder plugin's two Java classes (the alarm and the receiver that shows the notification); `addons/delta_notify/` the export plugin that puts them into the APK. The compiled jar and Godot's Android build template (`android/build`) are not committed; the workflow makes both.
- `export_presets.cfg` the Android export preset. `.github/workflows/android.yml` builds the APK on every push to main and publishes it as the `debug` pre-release; a `v*` tag makes a numbered release.

## Building

Requirements: Godot 4.7.2. For an APK, also the Android SDK (build-tools 35) and a JDK 17; the workflow shows the exact steps.

```
tools/fetch-site.sh                              # first, and after changing SITE_COMMIT (needs curl, tar, node)
godot --headless --import --quit                 # first time, and after adding files
godot --headless -s tools/build_theme.gd         # after editing the theme tokens
godot                                            # run it on the desktop, phone-shaped
godot --headless --export-debug Android build/delta-debug.apk
```

The APK is a gradle build (so the reminder plugin can be built in). Before exporting on a desktop, install the Android build template from the Godot editor (Project > Install Android Build Template), and compile the plugin the way the workflow does into `addons/delta_notify/bin/delta_notify.jar`. Without the jar the app still runs; only the reminders are missing.

For a quick look without a phone, the app can save a picture of a screen and quit:

```
godot -- --screenshot=shot.png --tab=profile
```

## Releases

Every push to main builds and signs an APK and publishes it as the rolling `debug` pre-release. A tag such as `v0.8.0` builds the same way and publishes a numbered release, so the newest one is always at:

```
https://github.com/txmmytwostraps/delta/releases/latest/download/delta.apk
```

The app checks that address and shows an Update button in Profile when the release is newer than the build.

Signing: with the `RELEASE_KEYSTORE_BASE64`, `RELEASE_KEYSTORE_USER` and `RELEASE_KEYSTORE_PASSWORD` secrets set, every build is signed with that key; otherwise with the debug key in `DEBUG_KEYSTORE_BASE64`. Android only installs a new build over an old one when both are signed with the same key, so the key should not change once people have the app. The version code is the number of commits, so each build counts as newer than the last.

Both builds use Godot's debug template on purpose, like the site's judge: it keeps the runtime checks that turn a division by zero into an error the user can read instead of a crash.

## Sign-in on the phone

GitHub sign-in opens the browser. When GitHub is done, Supabase sends the browser to `http://127.0.0.1:41337/callback`, which the app answers itself: it listens on that port while the sign-in is in progress. That address has to be on the Supabase project's list of allowed redirect URLs.

Accounts are created on the site; the app only signs in.
