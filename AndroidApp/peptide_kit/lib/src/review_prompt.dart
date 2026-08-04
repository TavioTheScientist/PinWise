/// Decides when to surface an App Store review request based on how long someone has used
/// the app. Staxyz asks at tenure milestones — day 8, 30, 60 — and never more than once per
/// milestone. Apple itself still throttles the real prompt (max 3/year, and the system
/// decides whether to actually display it), so these are *requests*, not guaranteed dialogs.
abstract final class ReviewPrompt {
  /// Days-of-use milestones at which to request a review.
  static const List<int> milestones = [8, 30, 60];

  /// The milestone to fire now, or null if none is due. Returns the HIGHEST reached-but-not-
  /// yet-fired milestone, so a user who opens the app after a long gap gets a single request,
  /// not a backlog of them. [lastFired] is the most recent milestone already requested
  /// (0 = none).
  static int? due({
    required int daysSinceInstall,
    required int lastFired,
    List<int> milestones = ReviewPrompt.milestones,
  }) {
    int? highest;
    for (final milestone in milestones) {
      if (milestone <= daysSinceInstall && milestone > lastFired) {
        if (highest == null || milestone > highest) highest = milestone;
      }
    }
    return highest;
  }
}
