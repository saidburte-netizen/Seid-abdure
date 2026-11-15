/// Roles allowed by the live `void_sale` RPC.
const Set<String> voidSaleRoles = {'admin', 'manager', 'accountant', 'cashier'};

/// Whether the current role may see and use the Void sale action.
bool canVoidSale(String? roleCode) => voidSaleRoles.contains(roleCode);

/// Friendly categories for every error the `void_sale` RPC can raise.
enum VoidSaleFailure {
  notFound,
  alreadyVoided,
  onlyCompleted,
  hasReturns,
  permissionDenied,
  unknown,
}

/// Classifies a raw RPC/PostgREST error without ever exposing its text.
VoidSaleFailure classifyVoidSaleFailure(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('sale not found')) {
    return VoidSaleFailure.notFound;
  }
  if (message.contains('already been voided')) {
    return VoidSaleFailure.alreadyVoided;
  }
  if (message.contains('only completed sales')) {
    return VoidSaleFailure.onlyCompleted;
  }
  if (message.contains('already has returns')) {
    return VoidSaleFailure.hasReturns;
  }
  if (message.contains('permission') ||
      message.contains('not authorized') ||
      message.contains('not allowed') ||
      message.contains('row-level security')) {
    return VoidSaleFailure.permissionDenied;
  }
  return VoidSaleFailure.unknown;
}
