// Find and replace has no regex mode here, so the RE2 engine its regex path needs is never bundled.
export const RE2JS = {
  CASE_INSENSITIVE: 1,
  compile(): never {
    throw new Error('Regex search is not available')
  },
}
