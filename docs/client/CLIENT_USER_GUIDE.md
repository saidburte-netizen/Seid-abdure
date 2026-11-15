# Brade and Cake House — Client User Guide

Version 1.0.8 · Android sideload build and web admin portal

## 1. Installing and signing in

1. Install the APK supplied by your administrator (Android 7.0 / API 24 or
   later). If Play Protect asks, allow the install from this source.
2. Open the app and choose **English**, **አማርኛ** or **Afaan Oromoo**.
3. Enter the email address and password created for you, then tap **Sign in**.
4. If you work in more than one branch, open the menu and pick the branch you
   are working in. Every list and every save then applies to that branch.
5. A new customer can tap **Create account** only when the owner has enabled
   customer sign-up. Otherwise the option is hidden and an administrator must
   create the account.

For security the app signs you out after 30 minutes without interaction, and
immediately if you return to the app after being away longer than that.

## 2. Day-to-day workflow

### Sell something (POS)

1. Open **New sale**.
2. Search for a product and tap it to add it to the cart.
3. Adjust quantity, price or discount if your role allows it.
4. Choose a payment method. Split payment is allowed; credit payment uses the
   customer's remaining credit limit.
5. Tap **Complete sale** once. The button shows progress and ignores a second
   tap, so a sale cannot be posted twice.
6. Print or share the receipt if needed.

### Give a refund or void a sale

- Open **Sales & returns**, find the sale, and choose **Return** to return
  individual lines. The database restores stock and posts the refund cash.
- To cancel a whole sale, choose **Void** and type a reason. Voiding also
  restores stock. Only roles with void permission see this action.

### Record stock

- **Inventory → Stock counts** creates a count in `draft`.
- Enter counted quantities and mark the count **completed**. Only a completed
  count changes stock.
- Transfers between stores and production consumption post their own stock
  movements; do not add a manual adjustment for the same goods.

### Cash, expenses and daily close

- **Cash & expenses** records receipts, payments and transfers between cash
  accounts.
- Expenses can require approval. Approvers use **Approvals**.
- At the end of the shift, use **Close day** with the counted cash. The system
  compares counted cash with expected cash and records the difference.

### Payroll and rent

- **Payroll**: create a run, tap **Generate payslips** once, review, then
  **Approve**. Generation and approval buttons ignore a second tap while the
  first request is running.
- **Rentals**: create properties, tenants and leases, then **Generate rent
  invoices** for a date. Existing invoices for the same lease and period are
  not duplicated. Record rent payments from the same screen.

### Reports and exports

- **Reports** shows sales, stock, cash, payroll, rent and credit summaries.
- Every list has **CSV** and **PDF** export. Exports fetch every row, not just
  the first page.

### Settings

- **Profile**: name, phone and photo. Photos must be JPG, PNG or WebP, at most
  5 MB.
- **Security**: change your password.
- **Users & roles** (administrators): create users, set role and branch access.
- **Business / Branches / Accounts / Master data**: owner or administrator
  configuration.
- **Audit log**: who changed what and when.
- **Help** and **Privacy**: short in-app explanations.

## 3. Languages

Use the language menu on the sign-in screen, or **Settings → Language**. The
interface changes immediately and the choice is remembered on the device.

## 4. Working with a weak connection

- When the device is offline, a banner appears and read-only screens show a
  friendly message. Pull down on a list to try again after reconnecting.
- **Saving needs a connection.** A sale, payment or edit that cannot reach the
  server is not queued: the app tells you it was not saved and you must try
  again. Do not assume an offline entry was recorded.
- Requests time out after 20 seconds. A read is retried once; a save is never
  retried automatically, which prevents duplicate sales or payments.

## 5. Common messages

| Message | What to do |
| --- | --- |
| "No internet connection" | Reconnect, then pull down to refresh. |
| "Your session has expired" | Sign in again. |
| "You do not have permission" | Ask an administrator to review your role or branch access. |
| "The change was not saved" | Check the connection and submit again. Nothing was recorded. |
| A field is rejected | Correct the highlighted field; the message says what is needed. |

## 6. Support

Contact your branch administrator or the business owner. Include the screen
name, what you were doing, the exact message shown and the time it happened.
The in-app **Settings → Help** screen repeats this checklist.

## 7. About this build

Version 1.0.8. If the owner has not configured Android signing secrets, the APK
is a debug-signed sideload/testing build and is not a Google Play release.
