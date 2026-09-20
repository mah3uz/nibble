module Nibble
  module Cp
    module Utilities
      LIST = [
        { key: "cache", title: "Cache", icon: "cache", description: "Clear cached pages, all at once or only the ones a tag names." },
        { key: "search", title: "Search", icon: "search-magnifying-glass", description: "See what each search index covers, and rebuild them." },
        { key: "jobs", title: "Jobs", icon: "jobs", description: "Queues, work in progress, failed jobs and the recurring schedule." },
        { key: "health", title: "Health", icon: "health", description: "Database, job queue, file storage and server rendering, checked now." },
        { key: "content", title: "Content", icon: "package", description: "Export the site's content as a package, or import one." },
        { key: "schema", title: "Schema", icon: "blueprints", description: "Problems nibble:check finds in blueprints, fieldsets, forms and the theme." },
        { key: "backups", title: "Backups", icon: "backups", description: "When the database was last backed up, and where the copies live." },
        { key: "audit", title: "Audit log", icon: "history", description: "Recent changes, sign-ins and permission changes, with who made them." }
      ].freeze

      def self.url(utility) = "/admin/utilities/#{utility[:key]}"
    end
  end
end
