# E-Service Book Email Platform: Part 2 (real sending, tracking, replies, unsubscribe)

Part 1 is the app (`public/index.html`). Part 2 adds Netlify Functions so emails really go out through your own mail server.

## What each function does
| File | Purpose |
|---|---|
| `send.mjs` | Sends one email over SMTP. Adds signed click links, an open-tracking pixel, the unsubscribe link and List-Unsubscribe headers. Turns logo/image data into attachments. Skips unsubscribed addresses. |
| `track-open.mjs` | `/t/o/:id.gif` records an open. |
| `track-click.mjs` | `/t/c` records a click, then redirects (signed links only). |
| `unsubscribe.mjs` | `/u/:token` confirm page (English and Bangla). Saves the opt-out for good. |
| `replies.mjs` | Every 5 minutes reads the sender mailbox over IMAP and records replies and bounce notices. It does not change the mailbox. |
| `events.mjs` | The app polls this every 30 seconds to raise alerts. |

## Set up
1. Put this folder in a Git repo and create a Netlify site from it (or `netlify deploy --prod`). No build command is needed.
2. In Netlify > Site settings > Environment variables, add:
   - `ADMIN_TOKEN`: a long random password. You type the same value in the app under Settings > Live events.
   - `TRACK_SECRET`: another long random string (signs tracking and unsubscribe links).
   - `SMTP_HOST`, `SMTP_PORT` (465 or 587), `SMTP_USER`, `SMTP_PASS`: your mail server (for info@eservicebook.com.bd).
   - `IMAP_HOST`, `IMAP_PORT` (993), `IMAP_USER`, `IMAP_PASS`: the mailbox that receives replies (usually the same account).
   - Optional: `ALLOWED_SENDERS` (comma-separated sender addresses), `BRAND_NAME`, `SITE_URL` (if you use a custom domain).
3. Open the deployed site, go to Settings, paste the admin token, tick Live mode.
4. Test first: send to your own two addresses, open one, click a link, reply, and tap the unsubscribe link.

## Before real campaigns
- Set SPF, DKIM and DMARC for eservicebook.com.bd at your mail host. Without them, bulk mail lands in spam.
- Send small batches first and keep the 300/day cap while the domain builds a reputation.
- Opens are approximate: Apple Mail and some apps load images automatically, and some block them. Replies and unsubscribes are the reliable signals.
- Sender and receiver can be typed freely in the app, but your SMTP server only accepts senders it owns.
- The page itself is not password-protected. Contacts and history live in the browser that uses it. Keep the site URL private; add Netlify password protection or Identity before sharing it with others.
- Netlify functions stop after about 10 seconds, so the app sends one email per request, about one per second, while the page is open.
