# Lendy Mobile

Flutter client for the Lendy borrowing system.

User requests, authentication, and approved user profiles use the shared
Firebase project described in [`../FIREBASE_SETUP.md`](../FIREBASE_SETUP.md).
An admin must approve a request and provide a temporary password before the
user can sign in.

The animated splash appears on every launch. The Welcome screen is shown only
on the first launch after installation; later launches continue to Login or
the existing signed-in session. Clearing the app's storage resets the
first-launch state.

The equipment catalog is read from the shared Firestore `equipment`
collection, so items added, updated, or removed in the admin dashboard appear
in the mobile app in real time. Item photos, category names, asset tags,
maintenance status, and active checkout status are displayed in Browse.
After a user submits a request, that item's Browse button changes to
`Requested` and stays disabled while the request is pending. A rejected or
cancelled request can be submitted again.

The Messages tab is a private, real-time conversation between the signed-in
user and administrators. Administrators can open the Messages section in the
web dashboard to select a user and reply. Both clients use the same Firestore
`chats/{userId}/messages` data, protected by the Firestore rules in
`../admin/firestore.rules`; deploy those rules before using chat. Users can
attach JPEG, PNG, or WebP images; they are compressed to JPEG files of at most
400 KB and stored in their Firestore message documents, so no Firebase Storage
setup is required. Image messages count toward Firestore's free storage and
usage quotas.

The notification feed is synced from Firestore. Push alerts cover admin chat
replies, Fabii replies, item request and return decisions, account request
decisions, and return deadlines. Alerts display when the app is backgrounded or
closed, and are not shown as popups while the app is in use. On the Spark plan,
a Google Apps Script poller checks for updates every five minutes and checks
deadlines after the Manila date changes; delivery is best-effort and may be
delayed. See [`../FIREBASE_SETUP.md`](../FIREBASE_SETUP.md) for setup.
