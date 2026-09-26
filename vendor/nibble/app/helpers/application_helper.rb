module ApplicationHelper
  # "system" for a signed-out request (e.g. the sign-in page) — there's no user preference to read yet.
  def cp_theme = Nibble::Current.user ? UserPreferences.get(Nibble::Current.user, "theme") : "system"
end
