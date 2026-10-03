/// Centralized English application strings.
/// Prepared for future internationalization (i18n) and locale switching.
class AppStrings {
  AppStrings._();

  // General & App Bar
  static const String appName = 'Spatio';
  static const String online = 'Online';
  static const String offline = 'Offline';
  static const String onlineTooltip = 'Online: Automatic two-way sync active';
  static const String offlineTooltip = 'Offline: Changes saved to local SQLite database';
  static const String pendingSyncTooltip = 'items waiting to sync';

  // Main Tabs
  static const String tabFloorPlan = 'Floor Plan';
  static const String tabTasks = 'Tasks';
  static const String tabRooms = 'Rooms';
  static const String tabHousehold = 'Household';
  static const String tabAccount = 'Account';

  // Floor Plan Modes & Actions
  static const String modeFurnish = 'Furnish';
  static const String modeDrawWalls = 'Draw Walls';
  static const String level = 'Floor:';
  static const String groundFloor = 'Ground Floor';
  static const String floorN = 'Floor';
  static const String addFloor = 'Add Floor';
  static const String deleteFloor = 'Delete Floor';
  static const String newFloorCreated = 'Floor created successfully!';
  static const String floorDeleted = 'Floor deleted successfully.';
  static const String cannotDeleteGroundFloor = 'The ground floor cannot be deleted.';
  static const String cannotDeleteFloorWithStairs = 'Cannot delete floor: A staircase connects to this floor.';
  static const String resetView = 'Reset View';
  static const String toggleGrid = 'Toggle Grid';

  /// Floor display label helper:
  /// 1 -> Ground Floor
  /// 2 -> 1st Floor
  /// 3 -> 2nd Floor
  /// 4 -> 3rd Floor
  static String floorLabel(int fl) {
    if (fl <= 1) return groundFloor;
    final n = fl - 1;
    final suffix = _ordinalSuffix(n);
    return '$n$suffix Floor';
  }

  static String _ordinalSuffix(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  // Grid Snap
  static const String snap = 'Snap:';
  static const String gridSnapTitle = 'Grid Snap Settings';
  static const String snapOff = 'Off (1 px)';
  static const String snap10 = '10 px';
  static const String snap20 = '20 px';
  static const String snap50 = '50 px';

  // Wall Drawing
  static const String points = 'Points:';
  static const String tapToStartDrawing = 'Tap on the canvas to place wall corners';
  static const String tapFirstPointToClose = 'Click on the first corner to close the room!';
  static const String undoLastPoint = 'Undo last point';
  static const String saveRoom = 'Save Room';
  static const String discard = 'Discard';
  static const String roomName = 'Room Name';
  static const String roomNameHint = 'e.g. Living Room, Office';
  static const String roomSaved = 'Room saved and synchronized!';

  // Furniture & Placement
  static const String catalog = 'Catalog:';
  static const String size = 'Size:';
  static const String width = 'W:';
  static const String length = 'L:';
  static const String rotate = 'Rotate';
  static const String fixed = 'Pinned';
  static const String followingMouse = 'Following Cursor';
  static const String cancel = 'Cancel';
  static const String place = 'Place';
  static const String undoLastFurniture = 'Undo last furniture';
  static const String furnitureUndone = 'Last placed item undone.';
  static const String furniturePlaced = 'placed successfully!';
  static const String placeInsideRoomWarning = 'Please place the furniture inside a room!';
  static const String overlapWarning = 'Cannot place furniture: Overlaps with existing furniture!';
  static const String furnitureDetails = 'Furniture Details';
  static const String deleteFurniture = 'Delete Furniture';
  static const String stairsPlaced = 'Staircase placed! New upper floor is accessible.';
  static const String stairsArrival = 'Stairs Descent\n(From Lower Floor)';
  static const String stairsUp = 'Stairs (Up)';

  // Furniture Catalog Items
  static const String washingMachine = 'Washing Machine';
  static const String sink = 'Sink';
  static const String table = 'Table';
  static const String bed = 'Bed';
  static const String sofa = 'Sofa';
  static const String stairs = 'Stairs';

  // Rooms Tab
  static const String noRoomsTitle = 'No rooms created yet';
  static const String noRoomsSubtitle = 'Draw your first room on the interactive floor plan!';
  static const String drawRoom = 'Draw Room';
  static const String cleanliness = 'Cleanliness:';
  static const String deleteRoom = 'Delete Room';
  static const String deleteRoomConfirmTitle = 'Delete Room?';
  static const String deleteRoomConfirmMsg = 'Are you sure you want to delete "%s"? All associated furniture and tasks will be permanently removed.';
  static const String roomDeleted = 'Room and associated items removed.';
  static const String roomFurniture = 'Furniture in Room';
  static const String noFurnitureInRoom = 'No furniture placed in this room yet.';
  static const String roomTasks = 'Tasks in Room';
  static const String noTasksInRoom = 'No tasks in this room.';
  static const String assignRoomToMember = 'Assign Room:';

  // Tasks Tab
  static const String newTask = 'New Task';
  static const String noTasksTitle = 'No active tasks';
  static const String noTasksSubtitle = 'Assign cleaning tasks to rooms or furniture items!';
  static const String taskTitle = 'Task Title';
  static const String taskTitleHint = 'e.g. Wipe shelves, Mop floor';
  static const String targetType = 'Target:';
  static const String targetRoom = 'Room';
  static const String targetFurniture = 'Furniture / Appliance';
  static const String assignedRoom = 'Assigned Room';
  static const String assignedFurniture = 'Assigned Furniture';
  static const String priority = 'Priority:';
  static const String priority1 = '1 - Low';
  static const String priority2 = '2 - Normal';
  static const String priority3 = '3 - Medium';
  static const String priority4 = '4 - High';
  static const String priority5 = '5 - Urgent';
  static const String deadline = 'Due In:';
  static const String isRecurring = 'Repeat Task:';
  static const String oneTime = 'One-time';
  static const String recurring = 'Recurring';
  static const String repeatInterval = 'Repeat Interval:';
  static const String rewardPoints = 'Reward Points:';
  static const String createTask = 'Create Task';
  static const String deleteTask = 'Delete Task';
  static const String pointsSuffix = 'pts';
  static const String completed = 'Completed';
  static const String overdue = 'Overdue';
  static const String pendingApproval = 'Pending Approval';
  static const String approve = 'Approve';
  static const String reject = 'Reject';
  static const String assignTask = 'Assign Task';
  static const String assignedTo = 'Assigned to';
  static const String unassigned = 'Unassigned';
  static const String filterByPerson = 'Filter by Person:';
  static const String filterAll = 'All';
  static const String lastCompletedBy = 'Completed by';
  static const String recentCompletions = 'Recent Completions:';

  // Household & Auth
  static const String householdTitle = 'Household Members';
  static const String householdSubtitle = 'Manage family members and their roles across devices';
  static const String roleParent = 'Parent / Adult';
  static const String roleChild = 'Child';
  static const String inviteMember = 'Invite Member';
  static const String inviteMemberHint = 'Share a household invite link or code for multi-device access.';
  static const String totalPoints = 'Total Points';
  static const String permissions = 'Permissions';
  static const String permissionsParent = 'Full access: Draw floor plans, manage furniture, create tasks, and approve completions.';
  static const String permissionsChild = 'Limited access: Complete assigned tasks, view points, request verification.';
  static const String inviteCode = 'Household Invite Code';
  static const String copyCode = 'Copy Code';
  static const String copiedToClipboard = 'Invite code copied to clipboard!';
  static const String loginTitle = 'Welcome to Spatio';
  static const String loginSubtitle = 'Smart floor planning and household management';
  static const String email = 'Email';
  static const String name = 'Your Name';
  static const String password = 'Password';
  static const String signIn = 'Sign In';
  static const String signUp = 'Create Account';
  static const String dontHaveAccount = "Don't have an account? Sign Up";
  static const String alreadyHaveAccount = 'Already have an account? Sign In';
  static const String selectRole = 'Select Role';
  static const String joinHouseholdTitle = 'Join a Household';
  static const String createHouseholdTitle = 'Create a New Household';
  static const String enterInviteCode = 'Enter 8-digit invite code';
  static const String householdName = 'Household Name';
  static const String householdNameHint = 'e.g. Smith Family';
  static const String logout = 'Log Out';
  static const String permissionDenied = 'Only parents/adults have permission to modify floor plans or manage household settings.';

  // Account Management
  static const String accountTitle = 'My Account';
  static const String changePassword = 'Change Password';
  static const String newPassword = 'New Password';
  static const String confirmNewPassword = 'Confirm New Password';
  static const String updatePassword = 'Update Password';
  static const String deleteAccount = 'Delete Account';
  static const String deleteAccountConfirmTitle = 'Delete Account Permanently?';
  static const String deleteAccountConfirmMsg = 'Are you sure you want to permanently delete your account? All your personal account data will be wiped from Spatio.';
  static const String signOutConfirmTitle = 'Sign Out?';
  static const String signOutConfirmMsg = 'Are you sure you want to sign out? You will need to sign in again to access your household.';
  static const String passwordChangedSuccess = 'Password updated successfully!';
  static const String accountDeletedSuccess = 'Your account has been deleted.';
  static const String dangerZone = 'Danger Zone';
  static const String accountDetails = 'Account Details';
  static const String securitySettings = 'Security & Password';
}
