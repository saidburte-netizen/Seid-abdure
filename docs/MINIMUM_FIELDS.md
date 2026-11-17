# Minimum required fields

A field is required only when the database column is `NOT NULL` without a
default and the app cannot fill a sensible value. Required fields are marked
with `*`. Empty optional fields are omitted from the request; they are never
sent as an empty string.

## Automatic values

| Value | Default |
| --- | --- |
| Branch | The signed-in user's branch, or the main branch |
| Store | The Shop store (Main Store for purchases) |
| Cash account | Cash Drawer, or the first active account |
| Unit | pcs |
| Category | none |
| Dates | today in Ethiopian time |
| Amounts / prices / salaries | 0 (price 0 asks for confirmation) |
| Status | active |
| Auto numbers | left to the database |

A missing required field is reported as `Field label: Required`, for
example `Name: Required`. The message always names the exact field and is
translated in English, Amharic and Afaan Oromoo.

## Minimum examples

| Form | Send only |
| --- | --- |
| Cash account | Name |
| Cash in / cash out | Amount |
| Customer / supplier / employee / property / tenant | Name |
| Product | Name (price is optional and may be 0 with a warning) |
| Expense | Amount |

## Generated forms

| Form | Required fields | Auto-filled / optional fields |
| --- | --- | --- |
| Approvals | Entity type *, Entity * | Status → active, Amount → 0, Decision note → left to the database |
| Attendance | Employee * | Work date → today in Ethiopian time, Status → active, Notes → left to the database |
| Bills | Amount * | Bill no → left to the database, Branch → branch / store / cash account / linked record, Category → branch / store / cash account / linked record, Paid amount → 0, Bill date → today in Ethiopian time, Due date → today in Ethiopian time, Status → active |
| Branches | Name * | Code → left to the database, Is active → active |
| Cake Orders | — | Order no → left to the database, Branch → branch / store / cash account / linked record, Design notes → left to the database, Size note → left to the database, Quantity → 0, Total amount → default, Deposit amount → 0, Status → active |
| Cash Accounts | Name * | Branch → branch / store / cash account / linked record, Account type → cash drawer, Account number → left to the database, Opening balance → 0, Is active → active |
| Cash Transactions | Amount * | Branch → branch / store / cash account / linked record, Cash account → branch / store / cash account / linked record, Txn type → cash in, Category → branch / store / cash account / linked record, Txn date → today in Ethiopian time, Status → active |
| Cash Transfers | From account *, To account *, Amount * | Transfer date → today in Ethiopian time, Notes → left to the database |
| Categories | Kind *, Name * | Is active → active |
| Customers | Full name * | Code → left to the database, Customer type → retail, Credit limit → 0, Is active → active, Notes → left to the database |
| Departments | Name * | Is active → active |
| Employee Advances | Employee *, Amount * | Advance date → today in Ethiopian time, Monthly deduction → 0, Balance → 0, Status → active |
| Employee Documents | Employee *, Title *, File url * | Doc type → default, Expiry date → today in Ethiopian time |
| Employee Shifts | Employee *, Shift * | Work date → today in Ethiopian time, Notes → left to the database |
| Employees | Full name * | Employee number → left to the database, Branch → branch / store / cash account / linked record, Hire date → today in Ethiopian time, Employment type → full_time, Status → active, Base salary → 0, Transport allowance → 0, Housing allowance → 0, Other allowance → 0, Pension rate → 0 |
| Expense Categories | Name * | Kind → default, Is active → active |
| Goods Receipts | — | Receipt no → left to the database, Store → branch / store / cash account / linked record, Received date → today in Ethiopian time, Notes → left to the database |
| Hr Notes | Employee *, Title * | Note type → left to the database, Note date → today in Ethiopian time |
| Items | Name * | SKU → left to the database, Item type → default, Category → branch / store / cash account / linked record, Unit → branch / store / cash account / linked record, Cost price → default, Min stock → 0, Track expiry → default, Is active → active |
| Leases | Property *, Tenant *, Rent amount * | Lease no → left to the database, Start date → today in Ethiopian time, End date → today in Ethiopian time, Billing frequency → monthly, Deposit amount → 0, Deposit paid → false, Status → active |
| Leave Requests | Employee *, Leave type * | Start date → today in Ethiopian time, End date → today in Ethiopian time, Days → 0, Status → active |
| Leave Types | Name * | Days per year → 0, Is paid → default |
| Maintenance Requests | Property *, Title * | Priority → default, Status → active, Cost → 0, Reported date → default, Completed date → today in Ethiopian time |
| Payable Payments | Payable *, Amount * | Cash account → branch / store / cash account / linked record, Payment date → today in Ethiopian time |
| Payables | Supplier * | Amount → 0, Paid amount → 0, Balance → 0, Due date → today in Ethiopian time, Status → active |
| Payroll Runs | — | Period month → today in Ethiopian time, Branch → branch / store / cash account / linked record, Cash account → branch / store / cash account / linked record, Status → active, Total gross → default, Total deductions → default, Total net → default, Notes → left to the database |
| Production Batches | Product * | Batch no → left to the database, Branch → branch / store / cash account / linked record, Store → branch / store / cash account / linked record, Planned qty → default, Produced qty → default, Wasted qty → default, Production date → today in Ethiopian time, Status → active, Notes → left to the database |
| Products | Name * | SKU → left to the database, Category → branch / store / cash account / linked record, Unit → branch / store / cash account / linked record, Price → 0, Cost → 0, Tax rate → 0, Is cake → false, Is active → active |
| Properties | Name * | Code → left to the database, Property type → shop, Branch → branch / store / cash account / linked record, Monthly rent → 0, Status → active, Is active → active |
| Purchase Orders | Supplier * | PO number → left to the database, Store → branch / store / cash account / linked record, Order date → today in Ethiopian time, Expected date → today in Ethiopian time, Status → active, Subtotal → default, Tax amount → default, Total amount → default, Notes → left to the database |
| Receivable Payments | Receivable *, Amount * | Cash account → branch / store / cash account / linked record, Payment date → today in Ethiopian time |
| Receivables | Customer * | Amount → 0, Paid amount → 0, Balance → 0, Due date → today in Ethiopian time, Status → active |
| Recipes | Product *, Name * | Yield quantity → default, Is active → active |
| Rent Payments | Amount * | Invoice → left to the database, Cash account → branch / store / cash account / linked record, Payment date → today in Ethiopian time |
| Sale Returns | Sale * | Return no → left to the database, Return date → today in Ethiopian time, Refund amount → default, Cash account → branch / store / cash account / linked record |
| Sales | — | Receipt no → left to the database, Branch → branch / store / cash account / linked record, Store → branch / store / cash account / linked record, Sale date → today in Ethiopian time, Subtotal → default, Discount amount → default, Tax amount → default, Total amount → default, Paid amount → 0, Payment status → default, Status → active, Notes → left to the database |
| Shifts | Name *, Start time *, End time * | Is active → active |
| Stock Counts | — | Store → branch / store / cash account / linked record, Count date → today in Ethiopian time, Status → active, Notes → left to the database |
| Stock Transfers | From store *, To store *, Item * | Transfer no → left to the database, Quantity → 0, Notes → left to the database |
| Stores | Name * | Branch → branch / store / cash account / linked record, Store type → default, Is active → active |
| Suppliers | Name * | Payment terms days → default, Is active → active, Notes → left to the database |
| Tax Brackets | Min amount *, Rate * | Deduction → default |
| Tenants | Full name * | ID number → left to the database, Notes → left to the database, Is active → active |
| Units | Name * | Code → left to the database |
| Write Offs | Receivable * | Amount → 0, Status → active |

## Custom screens

| Form | Required fields | Auto-filled / optional fields |
| --- | --- | --- |
| Products — add/edit | Name * | Price 0 with confirmation, cost 0, category none, unit pcs, photo optional, tax 0, description optional, Amharic/Oromo optional, active, track stock ON, opening stock optional |
| Stock — add item | Name * | Unit pcs, type raw material, minimum stock 0 |
| Stock — receive / use / count / transfer | Item * and quantity * | Store defaults to Shop; note optional; count compares with current quantity |
| Rentals — receive payment | Amount * (default full balance) | Date today, method cash, cash account Cash Drawer, reference optional; overpayment is blocked |
| HR — add employee | Name * | Job title, phone, salary 0, hire date today, branch main, no national ID / bank / birth date / emergency contact required |
| HR — attendance / leave / advance | Employee * plus the action's date/amount * | Dates today, status present, amount 0 allowed where the database allows it |

## Generated payload contract

`tool/generate_minimum_contract.py` writes the executable payload table
to `supabase/tests/integration/minimum_fields_contract.sql` and its parent
fixtures to `supabase/tests/integration/minimum_fields_seed.sql`. The
contract prints `SCREEN SAVE | role | screen | action | fields sent |
PASS/SQLSTATE | friendly message` for every create-capable form.

Verified with `tool/run_contract_local.sh`: 45 forms saved as admin with
45 PASS and 0 SQLSTATE; as a normal manager, 38 PASS and 7 expected
SQLSTATE 42501 responses on admin/HR-only forms. No other SQLSTATE was
accepted.
