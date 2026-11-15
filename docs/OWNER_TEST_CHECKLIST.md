# Owner phone test - 15 minutes

Use your real phone and your real Supabase project. Use test data, not real
money. Run the SQL in [SQL_TO_RUN.md](SQL_TO_RUN.md) first.

If Android says **App not installed**, uninstall the old app first. Your data is
safe in Supabase.

## 1. Install and open

Install `brade-cake-house.apk`, then open it.

**You should see:** the green Brade and Cake House sign-in screen. No red
technical text.

## 2. Sign in as admin

Sign in with your admin email and password.

**You should see:** the Dashboard with cards for sales, cash, stock and alerts.
Your branch name is visible.

## 3. Check the branch

Open **Settings → Branches**.

**You should see:** your active branch. If there is no branch, tap **Create the
first branch**, enter a name and save.

## 4. Add a product and stock

Open **Production → Products → Add**. Enter a name, price and unit, then save.
Open **Inventory → Stock** and add opening stock or a purchase for that product.

**You should see:** the product in the list and the stock quantity increase.
No error message.

## 5. Make a cash sale

Open **POS**. Add the product to the cart. Choose **Cash**, enter the amount and
complete the sale.

**You should see:** a receipt or success message. Stock goes down by the sold
quantity and the cash balance goes up by the sale total.

## 6. Make a credit sale

Open **POS** again. Add a product, choose a customer, choose **Credit** and
complete the sale. If you have no customer, add one in **Credit and debit →
Customers** first.

**You should see:** the sale succeeds and a receivable appears in **Credit and
debit** with the amount owed.

## 7. Void the cash sale

Open **Sales**. Find the cash sale, tap **Void**, enter a reason and confirm.

**You should see:** the sale is marked **Void**. Stock returns to the quantity
before the sale, exactly once. Cash returns to the balance before the sale. The
credit sale is not changed.

Now tap **Void** on the same sale again.

**You should see:** a friendly message that the sale was already voided. No
technical text, and no second stock or cash change.

## 8. Add an employee and clock in

Open **People and HR → Employees → Add**. Enter a name and save. Open
**Attendance**, choose the employee and tap **Clock in**, then **Clock out**.

**You should see:** the attendance record with both times. No crash.

## 9. Create a lease and rent invoice

Open **Rentals**. If needed, add a property, unit and tenant. Create a lease with
a monthly rent and payment day. Open **Invoices** and generate the rent invoice
for this month.

**You should see:** the invoice with the correct rent amount. Record a rent
payment and confirm the invoice becomes **Paid**.

## 10. Change language

Open the language menu on the sign-in screen or in **Settings**. Switch
**English → አማርኛ → Afaan Oromoo → English**. Visit the Dashboard, POS, Sales and
Settings in each language.

**You should see:** labels and database values change language. The app does not
crash. Back arrows and menus still work.

## 11. Check the dashboard numbers

Return to the **Dashboard** and open **Reports → Sales**.

**You should see:** the cash sale and credit sale are counted. The voided sale is
not counted as completed sales. Cash and stock match the changes you made.

## 12. Test the back button

Open a non-root screen such as **Sales**, **Inventory** or **Settings**. Press the
phone's back button.

**You should see:** the app returns to the previous screen. It does not close or
crash.

## 13. Test airplane mode

Turn on airplane mode. Open or refresh the app. Try to load a list.

**You should see:** a friendly offline banner or message. No raw error code or
stack trace. Turn airplane mode off and retry; the app loads again.

## 14. Sign out and back in

Sign out. Sign in again.

**You should see:** your data is still there. The branch, sales, stock and
receivables were saved in Supabase.

## If something fails

Write down the screen, the language, and what you tapped. Take a screenshot.
Do not send your password or any secret key.
