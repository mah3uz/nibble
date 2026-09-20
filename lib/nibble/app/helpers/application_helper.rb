module ApplicationHelper
  # "system" for a signed-out request (e.g. the sign-in page) — there's no user preference to read yet.
  def admin_theme = Current.user ? UserPreferences.get(Current.user, "theme") : "system"
end
