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
`../admin/firestore.rules`; deploy those rules before using chat.

Mobile borrow requests and notifications are still held in memory and do not
yet sync with the admin dashboard.
