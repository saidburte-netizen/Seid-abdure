enum FieldType { text, multiline, number, integer, date, time, boolean, select, lookup }

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.type = FieldType.text,
    this.required = false,
    this.options = const {},
    this.lookupTable,
    this.lookupLabel = 'name',
    this.lookupEquals = const {},
    this.lookupBranchScoped = true,
    this.defaultValue,
    this.hint,
    this.min,
    this.max,
    this.list = false,
    this.width,
  });

  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final Map<String, String> options;
  final String? lookupTable;
  final String lookupLabel;
  final Map<String, Object?> lookupEquals;
  final bool lookupBranchScoped;
  final Object? defaultValue;
  final String? hint;
  final num? min;
  final num? max;
  final bool list;
  final double? width;
}

class TableSpec {
  const TableSpec({
    required this.table,
    required this.title,
    required this.singular,
    required this.fields,
    this.listColumns = const [],
    this.orderBy,
    this.ascending = true,
    this.branchScoped = true,
    this.primaryKey = 'id',
    this.canCreate = true,
    this.canEdit = true,
    this.canDelete = true,
    this.searchColumns = const [],
    this.description,
    this.defaults = const {},
    this.limit = 500,
  });

  final String table;
  final String title;
  final String singular;
  final List<FieldSpec> fields;
  final List<String> listColumns;
  final String? orderBy;
  final bool ascending;
  final bool branchScoped;
  final String primaryKey;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final List<String> searchColumns;
  final String? description;
  final Map<String, dynamic> defaults;
  final int limit;

  FieldSpec? field(String key) {
    for (final field in fields) {
      if (field.key == key) return field;
    }
    return null;
  }

  List<String> get effectiveListColumns {
    if (listColumns.isNotEmpty) return listColumns;
    return fields.where((field) => field.list).map((field) => field.key).toList();
  }
}

const activeOptions = {'true': 'Active', 'false': 'Inactive'};
const yesNoOptions = {'true': 'Yes', 'false': 'No'};

const categoriesSpec = TableSpec(
  table: 'categories',
  title: 'Categories',
  singular: 'Category',
  orderBy: 'name',
  searchColumns: ['name', 'kind'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('kind', 'Kind', type: FieldType.select, required: true, list: true, options: {
      'product': 'Finished product',
      'inventory': 'Inventory material',
    }),
  ],
);

const productsSpec = TableSpec(
  table: 'products',
  title: 'Products',
  singular: 'Product',
  orderBy: 'name',
  searchColumns: ['name', 'sku', 'unit'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('sku', 'SKU', list: true),
    FieldSpec('category_id', 'Category', type: FieldType.lookup, lookupTable: 'categories', lookupEquals: {'kind': 'product'}, list: true),
    FieldSpec('unit', 'Unit', type: FieldType.select, required: true, defaultValue: 'piece', list: true, options: {
      'piece': 'Piece', 'pack': 'Pack', 'kg': 'Kilogram', 'g': 'Gram',
      'litre': 'Litre', 'ml': 'Millilitre', 'dozen': 'Dozen', 'box': 'Box',
    }),
    FieldSpec('selling_price', 'Selling price (ETB)', type: FieldType.number, required: true, defaultValue: 0, list: true, min: 0),
    FieldSpec('cost_price', 'Cost price (ETB)', type: FieldType.number, defaultValue: 0, min: 0),
    FieldSpec('tax_rate', 'Tax rate', type: FieldType.number, defaultValue: 0, min: 0, max: 1, hint: '0.15 = 15%'),
    FieldSpec('inventory_item_id', 'Stock item', type: FieldType.lookup, lookupTable: 'inventory_items'),
    FieldSpec('is_active', 'Active', type: FieldType.boolean, defaultValue: true, list: true, options: activeOptions),
  ],
);

const inventoryItemsSpec = TableSpec(
  table: 'inventory_items',
  title: 'Inventory items',
  singular: 'Inventory item',
  orderBy: 'name',
  searchColumns: ['name', 'sku'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('sku', 'SKU', list: true),
    FieldSpec('category_id', 'Category', type: FieldType.lookup, lookupTable: 'categories', lookupEquals: {'kind': 'inventory'}, list: true),
    FieldSpec('unit', 'Unit', type: FieldType.select, required: true, defaultValue: 'kg', list: true, options: {
      'kg': 'Kilogram', 'g': 'Gram', 'litre': 'Litre', 'ml': 'Millilitre',
      'piece': 'Piece', 'pack': 'Pack', 'sack': 'Sack', 'box': 'Box',
    }),
    FieldSpec('minimum_quantity', 'Minimum quantity', type: FieldType.number, defaultValue: 0, list: true, min: 0),
  ],
);

const storesSpec = TableSpec(
  table: 'stores',
  title: 'Stores',
  singular: 'Store',
  orderBy: 'name',
  searchColumns: ['name'],
  fields: [FieldSpec('name', 'Name', required: true, list: true)],
);

const customersSpec = TableSpec(
  table: 'customers',
  title: 'Customers',
  singular: 'Customer',
  orderBy: 'name',
  searchColumns: ['name', 'phone', 'email'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('phone', 'Phone', list: true),
    FieldSpec('email', 'Email'),
    FieldSpec('address', 'Address', type: FieldType.multiline),
    FieldSpec('credit_limit', 'Credit limit (ETB)', type: FieldType.number, defaultValue: 0, list: true, min: 0),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
    FieldSpec('is_active', 'Active', type: FieldType.boolean, defaultValue: true, list: true, options: activeOptions),
  ],
);

const suppliersSpec = TableSpec(
  table: 'suppliers',
  title: 'Suppliers',
  singular: 'Supplier',
  orderBy: 'name',
  searchColumns: ['name', 'phone', 'email', 'tin'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('contact_name', 'Contact person', list: true),
    FieldSpec('phone', 'Phone', list: true),
    FieldSpec('email', 'Email'),
    FieldSpec('address', 'Address', type: FieldType.multiline),
    FieldSpec('tin', 'TIN'),
    FieldSpec('payment_terms_days', 'Payment terms (days)', type: FieldType.integer, defaultValue: 30, min: 0),
    FieldSpec('is_active', 'Active', type: FieldType.boolean, defaultValue: true, list: true, options: activeOptions),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
);

const recipesSpec = TableSpec(
  table: 'recipes',
  title: 'Recipes',
  singular: 'Recipe',
  orderBy: 'name',
  searchColumns: ['name'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('product_id', 'Product', type: FieldType.lookup, lookupTable: 'products', list: true, required: true),
    FieldSpec('yield_quantity', 'Yield quantity', type: FieldType.number, defaultValue: 1, list: true, min: 0.001),
    FieldSpec('yield_unit', 'Yield unit', type: FieldType.text, defaultValue: 'piece', list: true),
    FieldSpec('instructions', 'Instructions', type: FieldType.multiline),
    FieldSpec('is_active', 'Active', type: FieldType.boolean, defaultValue: true, list: true, options: activeOptions),
  ],
);

const recipeItemsSpec = TableSpec(
  table: 'recipe_items',
  title: 'Recipe ingredients',
  singular: 'Ingredient',
  orderBy: 'quantity',
  branchScoped: false,
  searchColumns: ['unit'],
  fields: [
    FieldSpec('recipe_id', 'Recipe', type: FieldType.lookup, lookupTable: 'recipes', list: true, required: true),
    FieldSpec('inventory_item_id', 'Inventory item', type: FieldType.lookup, lookupTable: 'inventory_items', list: true, required: true),
    FieldSpec('quantity', 'Quantity', type: FieldType.number, required: true, list: true, min: 0.001),
    FieldSpec('unit', 'Unit', type: FieldType.text, defaultValue: 'kg', list: true),
    FieldSpec('waste_percent', 'Waste %', type: FieldType.number, defaultValue: 0, min: 0, max: 100),
  ],
);

const employeesSpec = TableSpec(
  table: 'employees',
  title: 'Employees',
  singular: 'Employee',
  orderBy: 'full_name',
  searchColumns: ['full_name', 'employee_number', 'phone', 'position', 'department'],
  fields: [
    FieldSpec('employee_number', 'Employee number', list: true),
    FieldSpec('full_name', 'Full name', required: true, list: true),
    FieldSpec('phone', 'Phone', list: true),
    FieldSpec('email', 'Email'),
    FieldSpec('position', 'Position', list: true),
    FieldSpec('department', 'Department'),
    FieldSpec('employment_type', 'Employment type', type: FieldType.select, defaultValue: 'full_time', list: true, options: {
      'full_time': 'Full time', 'part_time': 'Part time', 'contract': 'Contract', 'daily': 'Daily',
    }),
    FieldSpec('hire_date', 'Hire date', type: FieldType.date, list: true),
    FieldSpec('end_date', 'End date', type: FieldType.date),
    FieldSpec('basic_salary', 'Basic salary (ETB)', type: FieldType.number, defaultValue: 0, list: true, min: 0),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'active', list: true, options: {
      'active': 'Active', 'on_leave': 'On leave', 'suspended': 'Suspended', 'terminated': 'Terminated',
    }),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
);

const shiftsSpec = TableSpec(
  table: 'shifts',
  title: 'Shifts',
  singular: 'Shift',
  orderBy: 'name',
  searchColumns: ['name'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('start_time', 'Start time', type: FieldType.time, list: true),
    FieldSpec('end_time', 'End time', type: FieldType.time, list: true),
    FieldSpec('is_active', 'Active', type: FieldType.boolean, defaultValue: true, list: true, options: activeOptions),
  ],
);

const leaveTypesSpec = TableSpec(
  table: 'leave_types',
  title: 'Leave types',
  singular: 'Leave type',
  orderBy: 'name',
  searchColumns: ['name'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('is_paid', 'Paid', type: FieldType.boolean, defaultValue: true, list: true, options: yesNoOptions),
    FieldSpec('annual_days', 'Annual days', type: FieldType.number, defaultValue: 0, list: true, min: 0),
    FieldSpec('requires_approval', 'Requires approval', type: FieldType.boolean, defaultValue: true, options: yesNoOptions),
    FieldSpec('is_active', 'Active', type: FieldType.boolean, defaultValue: true, list: true, options: activeOptions),
  ],
);

const attendanceSpec = TableSpec(
  table: 'attendance',
  title: 'Attendance',
  singular: 'Attendance record',
  orderBy: 'work_date',
  ascending: false,
  searchColumns: ['notes'],
  fields: [
    FieldSpec('employee_id', 'Employee', type: FieldType.lookup, lookupTable: 'employees', lookupLabel: 'full_name', required: true, list: true),
    FieldSpec('work_date', 'Date', type: FieldType.date, required: true, list: true),
    FieldSpec('shift_id', 'Shift', type: FieldType.lookup, lookupTable: 'shifts', list: true),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'present', list: true, options: {
      'present': 'Present', 'absent': 'Absent', 'late': 'Late', 'half_day': 'Half day', 'leave': 'Leave', 'holiday': 'Holiday',
    }),
    FieldSpec('overtime_hours', 'Overtime hours', type: FieldType.number, defaultValue: 0, list: true, min: 0),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
);

const leaveRequestsSpec = TableSpec(
  table: 'leave_requests',
  title: 'Leave requests',
  singular: 'Leave request',
  orderBy: 'created_at',
  ascending: false,
  searchColumns: ['reason', 'status'],
  fields: [
    FieldSpec('employee_id', 'Employee', type: FieldType.lookup, lookupTable: 'employees', lookupLabel: 'full_name', required: true, list: true),
    FieldSpec('leave_type_id', 'Leave type', type: FieldType.lookup, lookupTable: 'leave_types', required: true, list: true),
    FieldSpec('start_date', 'Start date', type: FieldType.date, required: true, list: true),
    FieldSpec('end_date', 'End date', type: FieldType.date, required: true, list: true),
    FieldSpec('days', 'Days', type: FieldType.number, required: true, list: true, min: 0.5),
    FieldSpec('reason', 'Reason', type: FieldType.multiline),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'pending', list: true, options: {
      'pending': 'Pending', 'approved': 'Approved', 'rejected': 'Rejected', 'cancelled': 'Cancelled',
    }),
  ],
  canEdit: false,
);

const salaryComponentsSpec = TableSpec(
  table: 'salary_components',
  title: 'Salary components',
  singular: 'Salary component',
  orderBy: 'name',
  searchColumns: ['name', 'component_type'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('component_type', 'Type', type: FieldType.select, required: true, list: true, options: {
      'earning': 'Earning', 'deduction': 'Deduction', 'employer_contribution': 'Employer contribution',
    }),
    FieldSpec('calc_type', 'Calculation', type: FieldType.select, required: true, defaultValue: 'fixed', list: true, options: {
      'fixed': 'Fixed amount', 'percent': 'Percent of basic salary',
    }),
    FieldSpec('amount', 'Amount (ETB)', type: FieldType.number, defaultValue: 0, list: true, min: 0),
    FieldSpec('rate', 'Rate', type: FieldType.number, defaultValue: 0, min: 0, max: 1, hint: '0.07 = 7%'),
    FieldSpec('is_statutory', 'Statutory', type: FieldType.boolean, defaultValue: false, options: yesNoOptions),
    FieldSpec('is_active', 'Active', type: FieldType.boolean, defaultValue: true, list: true, options: activeOptions),
  ],
);

const employeeComponentsSpec = TableSpec(
  table: 'employee_salary_components',
  title: 'Employee components',
  singular: 'Employee component',
  orderBy: 'amount_override',
  branchScoped: false,
  searchColumns: [],
  fields: [
    FieldSpec('employee_id', 'Employee', type: FieldType.lookup, lookupTable: 'employees', lookupLabel: 'full_name', required: true, list: true),
    FieldSpec('component_id', 'Component', type: FieldType.lookup, lookupTable: 'salary_components', required: true, list: true),
    FieldSpec('amount_override', 'Amount override (ETB)', type: FieldType.number, defaultValue: 0, list: true, min: 0),
    FieldSpec('rate_override', 'Rate override', type: FieldType.number, defaultValue: 0, min: 0, max: 1),
  ],
);

const advancesSpec = TableSpec(
  table: 'payroll_advances',
  title: 'Salary advances',
  singular: 'Advance',
  orderBy: 'issued_at',
  ascending: false,
  searchColumns: ['notes', 'status'],
  fields: [
    FieldSpec('employee_id', 'Employee', type: FieldType.lookup, lookupTable: 'employees', lookupLabel: 'full_name', required: true, list: true),
    FieldSpec('amount', 'Amount (ETB)', type: FieldType.number, required: true, list: true, min: 0),
    FieldSpec('balance', 'Balance (ETB)', type: FieldType.number, required: true, list: true, min: 0),
    FieldSpec('repayment_amount', 'Repayment per payroll', type: FieldType.number, defaultValue: 0, list: true, min: 0),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'open', list: true, options: {
      'open': 'Open', 'settled': 'Settled', 'cancelled': 'Cancelled',
    }),
    FieldSpec('issued_at', 'Issued on', type: FieldType.date, list: true),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
);

const propertiesSpec = TableSpec(
  table: 'properties',
  title: 'Properties',
  singular: 'Property',
  orderBy: 'name',
  searchColumns: ['name', 'address', 'property_type'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('address', 'Address', list: true),
    FieldSpec('property_type', 'Property type', type: FieldType.select, defaultValue: 'commercial', list: true, options: {
      'commercial': 'Commercial', 'residential': 'Residential', 'mixed': 'Mixed use', 'warehouse': 'Warehouse', 'land': 'Land',
    }),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
    FieldSpec('is_active', 'Active', type: FieldType.boolean, defaultValue: true, list: true, options: activeOptions),
  ],
);

const unitsSpec = TableSpec(
  table: 'units',
  title: 'Units',
  singular: 'Unit',
  orderBy: 'name',
  searchColumns: ['name', 'status'],
  fields: [
    FieldSpec('property_id', 'Property', type: FieldType.lookup, lookupTable: 'properties', required: true, list: true),
    FieldSpec('name', 'Unit name', required: true, list: true),
    FieldSpec('bedrooms', 'Bedrooms', type: FieldType.integer, defaultValue: 0, list: true, min: 0),
    FieldSpec('size_sqm', 'Size (m²)', type: FieldType.number, defaultValue: 0, list: true, min: 0),
    FieldSpec('rent_amount', 'Monthly rent (ETB)', type: FieldType.number, defaultValue: 0, list: true, min: 0),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'vacant', list: true, options: {
      'vacant': 'Vacant', 'occupied': 'Occupied', 'maintenance': 'Maintenance', 'inactive': 'Inactive',
    }),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
);

const leasesSpec = TableSpec(
  table: 'leases',
  title: 'Leases',
  singular: 'Lease',
  orderBy: 'start_date',
  ascending: false,
  searchColumns: ['tenant_name', 'tenant_phone', 'status'],
  fields: [
    FieldSpec('unit_id', 'Unit', type: FieldType.lookup, lookupTable: 'units', required: true, list: true),
    FieldSpec('tenant_name', 'Tenant name', required: true, list: true),
    FieldSpec('tenant_phone', 'Tenant phone', list: true),
    FieldSpec('tenant_email', 'Tenant email'),
    FieldSpec('start_date', 'Start date', type: FieldType.date, required: true, list: true),
    FieldSpec('end_date', 'End date', type: FieldType.date, required: true, list: true),
    FieldSpec('rent_amount', 'Rent (ETB)', type: FieldType.number, required: true, list: true, min: 0),
    FieldSpec('deposit_amount', 'Deposit (ETB)', type: FieldType.number, defaultValue: 0, min: 0),
    FieldSpec('payment_day', 'Payment day', type: FieldType.integer, defaultValue: 1, min: 1, max: 31),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'active', list: true, options: {
      'active': 'Active', 'expired': 'Expired', 'terminated': 'Terminated', 'draft': 'Draft',
    }),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
);

const maintenanceSpec = TableSpec(
  table: 'maintenance_requests',
  title: 'Maintenance',
  singular: 'Maintenance request',
  orderBy: 'created_at',
  ascending: false,
  searchColumns: ['title', 'description', 'status', 'assigned_to'],
  fields: [
    FieldSpec('property_id', 'Property', type: FieldType.lookup, lookupTable: 'properties', required: true, list: true),
    FieldSpec('unit_id', 'Unit', type: FieldType.lookup, lookupTable: 'units', list: true),
    FieldSpec('title', 'Title', required: true, list: true),
    FieldSpec('description', 'Description', type: FieldType.multiline),
    FieldSpec('priority', 'Priority', type: FieldType.select, defaultValue: 'normal', list: true, options: {
      'low': 'Low', 'normal': 'Normal', 'high': 'High', 'urgent': 'Urgent',
    }),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'open', list: true, options: {
      'open': 'Open', 'in_progress': 'In progress', 'resolved': 'Resolved', 'cancelled': 'Cancelled',
    }),
    FieldSpec('assigned_to', 'Assigned to', list: true),
    FieldSpec('cost', 'Cost (ETB)', type: FieldType.number, defaultValue: 0, list: true, min: 0),
  ],
);

const expensesSpec = TableSpec(
  table: 'expenses',
  title: 'Expenses',
  singular: 'Expense',
  orderBy: 'expense_date',
  ascending: false,
  searchColumns: ['category', 'description', 'status'],
  fields: [
    FieldSpec('expense_date', 'Date', type: FieldType.date, required: true, list: true),
    FieldSpec('category', 'Category', required: true, list: true),
    FieldSpec('description', 'Description', required: true, list: true),
    FieldSpec('amount', 'Amount (ETB)', type: FieldType.number, required: true, list: true, min: 0.01),
    FieldSpec('cash_account_id', 'Cash account', type: FieldType.lookup, lookupTable: 'cash_accounts', list: true),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'pending', list: true, options: {
      'pending': 'Pending', 'approved': 'Approved', 'rejected': 'Rejected', 'paid': 'Paid',
    }),
  ],
  canDelete: false,
);

const billsSpec = TableSpec(
  table: 'bills',
  title: 'Supplier bills',
  singular: 'Bill',
  orderBy: 'due_date',
  searchColumns: ['bill_number', 'description', 'status'],
  fields: [
    FieldSpec('bill_number', 'Bill number', required: true, list: true),
    FieldSpec('supplier_id', 'Supplier', type: FieldType.lookup, lookupTable: 'suppliers', required: true, list: true),
    FieldSpec('description', 'Description', list: true),
    FieldSpec('issue_date', 'Issue date', type: FieldType.date, required: true, list: true),
    FieldSpec('due_date', 'Due date', type: FieldType.date, required: true, list: true),
    FieldSpec('amount', 'Amount (ETB)', type: FieldType.number, required: true, list: true, min: 0.01),
  ],
);

const cashAccountsSpec = TableSpec(
  table: 'cash_accounts',
  title: 'Cash accounts',
  singular: 'Cash account',
  orderBy: 'name',
  searchColumns: ['name', 'account_type'],
  fields: [
    FieldSpec('name', 'Name', required: true, list: true),
    FieldSpec('account_type', 'Type', type: FieldType.select, required: true, list: true, options: {
      'cash': 'Cash', 'bank': 'Bank', 'mobile_money': 'Mobile money',
    }),
    FieldSpec('currency', 'Currency', type: FieldType.text, defaultValue: 'ETB', list: true),
  ],
);

const cashTransfersSpec = TableSpec(
  table: 'cash_transfers',
  title: 'Cash transfers',
  singular: 'Transfer',
  orderBy: 'created_at',
  ascending: false,
  searchColumns: ['notes', 'status'],
  fields: [
    FieldSpec('from_account_id', 'From account', type: FieldType.lookup, lookupTable: 'cash_accounts', required: true, list: true),
    FieldSpec('to_account_id', 'To account', type: FieldType.lookup, lookupTable: 'cash_accounts', required: true, list: true),
    FieldSpec('amount', 'Amount (ETB)', type: FieldType.number, required: true, list: true, min: 0.01),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
  canDelete: false,
);

const returnFields = <FieldSpec>[
  FieldSpec('return_number', 'Return number', list: true),
  FieldSpec('refund_method', 'Refund method', list: true),
  FieldSpec('total', 'Total (ETB)', type: FieldType.number, list: true),
  FieldSpec('status', 'Status', list: true),
  FieldSpec('reason', 'Reason', list: true),
];

const purchaseOrdersSpec = TableSpec(
  table: 'purchase_orders',
  title: 'Purchase orders',
  singular: 'Purchase order',
  orderBy: 'created_at',
  ascending: false,
  searchColumns: ['po_number', 'status', 'notes'],
  fields: [
    FieldSpec('po_number', 'PO number', required: true, list: true),
    FieldSpec('supplier_id', 'Supplier', type: FieldType.lookup, lookupTable: 'suppliers', required: true, list: true),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'draft', list: true, options: {
      'draft': 'Draft', 'ordered': 'Ordered', 'partially_received': 'Partially received',
      'received': 'Received', 'cancelled': 'Cancelled',
    }),
    FieldSpec('ordered_at', 'Ordered on', type: FieldType.date, list: true),
    FieldSpec('expected_at', 'Expected on', type: FieldType.date, list: true),
    FieldSpec('subtotal', 'Subtotal', type: FieldType.number, list: true),
    FieldSpec('tax_total', 'Tax', type: FieldType.number),
    FieldSpec('total', 'Total', type: FieldType.number, list: true),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
);

const purchaseOrderItemsSpec = TableSpec(
  table: 'purchase_order_items',
  title: 'Purchase order lines',
  singular: 'Purchase order line',
  branchScoped: false,
  orderBy: 'line_total',
  ascending: false,
  searchColumns: [],
  fields: [
    FieldSpec('purchase_order_id', 'Purchase order', type: FieldType.lookup, lookupTable: 'purchase_orders', lookupLabel: 'po_number', required: true, list: true),
    FieldSpec('inventory_item_id', 'Inventory item', type: FieldType.lookup, lookupTable: 'inventory_items', required: true, list: true),
    FieldSpec('quantity', 'Quantity', type: FieldType.number, required: true, list: true, min: 0.001),
    FieldSpec('unit_cost', 'Unit cost (ETB)', type: FieldType.number, required: true, list: true, min: 0),
    FieldSpec('received_quantity', 'Received', type: FieldType.number, defaultValue: 0, list: true, min: 0),
    FieldSpec('line_total', 'Line total', type: FieldType.number, list: true),
  ],
);

const stockAdjustmentsSpec = TableSpec(
  table: 'stock_adjustments',
  title: 'Stock adjustments',
  singular: 'Stock adjustment',
  orderBy: 'created_at',
  ascending: false,
  searchColumns: ['reason', 'status'],
  fields: [
    FieldSpec('store_id', 'Store', type: FieldType.lookup, lookupTable: 'stores', required: true, list: true),
    FieldSpec('reason', 'Reason', required: true, list: true),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'pending', list: true, options: {
      'pending': 'Pending', 'approved': 'Approved', 'rejected': 'Rejected',
    }),
  ],
  canEdit: false,
  canDelete: false,
);

const stockAdjustmentItemsSpec = TableSpec(
  table: 'stock_adjustment_items',
  title: 'Adjustment lines',
  singular: 'Adjustment line',
  branchScoped: false,
  orderBy: 'quantity_delta',
  searchColumns: ['notes'],
  fields: [
    FieldSpec('stock_adjustment_id', 'Adjustment', type: FieldType.lookup, lookupTable: 'stock_adjustments', lookupLabel: 'reason', required: true, list: true),
    FieldSpec('inventory_item_id', 'Inventory item', type: FieldType.lookup, lookupTable: 'inventory_items', required: true, list: true),
    FieldSpec('quantity_delta', 'Quantity change', type: FieldType.number, required: true, list: true, hint: 'Use a negative number to reduce stock'),
    FieldSpec('unit_cost', 'Unit cost (ETB)', type: FieldType.number, min: 0),
    FieldSpec('notes', 'Notes'),
  ],
);

const stockTransfersSpec = TableSpec(
  table: 'stock_transfers',
  title: 'Stock transfers',
  singular: 'Stock transfer',
  orderBy: 'created_at',
  ascending: false,
  searchColumns: ['status', 'notes'],
  fields: [
    FieldSpec('from_store_id', 'From store', type: FieldType.lookup, lookupTable: 'stores', required: true, list: true),
    FieldSpec('to_store_id', 'To store', type: FieldType.lookup, lookupTable: 'stores', required: true, list: true),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'pending', list: true, options: {
      'pending': 'Pending', 'completed': 'Completed', 'cancelled': 'Cancelled',
    }),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
  canEdit: false,
  canDelete: false,
);

const stockTransferItemsSpec = TableSpec(
  table: 'stock_transfer_items',
  title: 'Transfer lines',
  singular: 'Transfer line',
  branchScoped: false,
  orderBy: 'quantity',
  searchColumns: [],
  fields: [
    FieldSpec('stock_transfer_id', 'Transfer', type: FieldType.lookup, lookupTable: 'stock_transfers', lookupLabel: 'notes', required: true, list: true),
    FieldSpec('inventory_item_id', 'Inventory item', type: FieldType.lookup, lookupTable: 'inventory_items', required: true, list: true),
    FieldSpec('quantity', 'Quantity', type: FieldType.number, required: true, list: true, min: 0.001),
    FieldSpec('unit_cost', 'Unit cost (ETB)', type: FieldType.number, min: 0),
  ],
);

const stockCountsSpec = TableSpec(
  table: 'stock_counts',
  title: 'Stock counts',
  singular: 'Stock count',
  orderBy: 'counted_at',
  ascending: false,
  searchColumns: ['status', 'notes'],
  fields: [
    FieldSpec('store_id', 'Store', type: FieldType.lookup, lookupTable: 'stores', required: true, list: true),
    FieldSpec('status', 'Status', type: FieldType.select, defaultValue: 'draft', list: true, options: {
      'draft': 'Draft', 'submitted': 'Submitted', 'approved': 'Approved', 'cancelled': 'Cancelled',
    }),
    FieldSpec('counted_at', 'Count date', type: FieldType.date, required: true, list: true),
    FieldSpec('notes', 'Notes', type: FieldType.multiline),
  ],
  canEdit: false,
  canDelete: false,
);

const stockCountItemsSpec = TableSpec(
  table: 'stock_count_items',
  title: 'Count lines',
  singular: 'Count line',
  branchScoped: false,
  orderBy: 'counted_quantity',
  searchColumns: [],
  fields: [
    FieldSpec('stock_count_id', 'Stock count', type: FieldType.lookup, lookupTable: 'stock_counts', lookupLabel: 'notes', required: true, list: true),
    FieldSpec('inventory_item_id', 'Inventory item', type: FieldType.lookup, lookupTable: 'inventory_items', required: true, list: true),
    FieldSpec('system_quantity', 'System quantity', type: FieldType.number, defaultValue: 0, list: true),
    FieldSpec('counted_quantity', 'Counted quantity', type: FieldType.number, required: true, list: true, min: 0),
    FieldSpec('unit_cost', 'Unit cost (ETB)', type: FieldType.number, min: 0),
  ],
);

