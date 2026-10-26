/// Local access choices, never employee accounts or device identities.
enum ManagementRole { owner, warehouse }

/// Services default to owner-only. Inventory must explicitly opt into the
/// warehouse capability, so a new protected use case cannot inherit authority.
enum ManagementCapability { owner, inventory }
