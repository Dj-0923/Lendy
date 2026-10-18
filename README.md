# Lendy Mobile

Flutter client for the Lendy borrowing system.

User requests, authentication, and approved user profiles use the shared
Firebase project described in [`../FIREBASE_SETUP.md`](../FIREBASE_SETUP.md).
An admin must approve a request and provide a temporary password before the
user can sign in.

The equipment catalog, borrow requests, and notifications are still held in
memory in the mobile app. Those features do not yet sync with the admin
dashboard.
