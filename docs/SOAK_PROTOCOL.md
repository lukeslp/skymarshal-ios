# Large-account soak protocol (release gate)

Use this checklist before a public TestFlight build or App Store submission when reliability work shipped. Evidence belongs in your release folder (notes + attachments).

## Environment

- **Device:** physical iPhone (not simulator-only) on a network you trust.
- **Account:** preferably **≥ 10k** combined posts/replies/reposts/likes, or the largest test account available.
- **Recording:** capture a **screen recording** for the full session (Claude consensus Q6). Store the file with the build number in the filename.

## Scenarios (check each)

1. **Cold start + hydrate**  
   Force-quit the app, relaunch signed out (if applicable), confirm cached rows render and banners match expectations.

2. **Full archive load**  
   Sign in, run **Refresh archive** (or first load). Let pagination run until completion or a deliberate **Stop** mid-way.  
   - Repeat once with **interruption**: background the app during load, return, confirm progress resumes or stale data is honest.

3. **Checkpoint resume**  
   After a mid-load kill, relaunch and confirm counts increase without obvious duplicate URIs in the Content list (dedupe path).

4. **429 / bulk delete**  
   Select a **large batch** delete (use dry environments first). Confirm rate-limit backoff feels steady (no tight spinners) and partial completion surfaces errors without corrupting `deletionURI` targets.

5. **Typed confirm (≥ 100)**  
   Exercise `TypedConfirmSheet` once per release when that threshold is reachable on the test account.

6. **Backup import**  
   Export JSON, modify nothing, re-import with **merge** and **replace** on a throwaway account only. Confirm handle/DID mismatch paths **block** import.

7. **Scope / Insights**  
   Toggle Feature lab Scope tab on and off; open Scope from **Insights** when the tab is off; confirm “partial / on-device” copy still reads true.

8. **Followers scan (optional)**  
   If follower code changed, run a scan to completion or cancel mid-scan and relaunch.

## Sign-off

- [ ] Recording attached and labeled with build + date  
- [ ] No crashes in Analytics / Xcode Organizer for the soak build  
- [ ] Any anomalies filed with repro steps before submission  
