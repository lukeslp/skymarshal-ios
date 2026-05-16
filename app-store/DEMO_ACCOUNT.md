# App Review demo account

**Purpose:** Reduce first-submission rejection rate (~40% of rejections cite missing demo credentials per council scout estimate).

## Account to create

| Field | Value |
|-------|--------|
| Handle | `skymarshal-review.bsky.social` (or closest available) |
| App password | Generate at bsky.app → Settings → App Passwords |
| Label | `Skymarshal App Review` (disposable) |

## App Store Connect — App Review Information

Paste:

```
Username: skymarshal-review.bsky.social
Password: [app password from 1Password / secure note — NOT main account password]

Sign in with the app password field on the login screen (not your main Bluesky password).
After sign-in, open the Content tab and tap Refresh to load posts if the list is empty.
Followers tab: tap Scan to populate follower analysis (optional for review).
```

## Security

- Rotate or revoke app password after approval if desired.
- Never commit the password to git.
- Update `SUBMISSION_NOTES.md` to reference this file instead of declining demo access.

## Checklist

- [ ] Account created and can sign in via Skymarshal iOS
- [ ] Account has enough posts for reviewer to see list UI (or document that Refresh is required)
- [ ] Credentials pasted in ASC App Review Information block
- [ ] Password stored in secure manager (not repo)
