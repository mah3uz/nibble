module Nibble
  module Files
    ROOT = "content".freeze
    # Namespaced, because a site is free to want /content for pages of its own.
    PUBLISHED = "nibble-assets".freeze
    PRESET = "content".freeze
    VECTOR = ".svg".freeze
    TOKEN = /\{[a-z_]+\}/
    IMAGE = /(!\[[^\]]*\]\()(?!\w+:|\/)([^)\s]+)(\))/
    # Only means anything once both ends are pages, so it is resolved against the index rather than rewritten.
    LINK = /(\]\()(?!\w+:|\/)([^)\s#]+\.md)(#[^)\s]*)?(\))/

    class << self
      def collections(schema = Nibble.schema) = schema.all(:collections).select { |item| item["files"].present? }

      def declared?(schema = Nibble.schema) = collections(schema).any?

      def root_for(item) = Nibble.config.content_path.join(*item["files"].to_s.split("/"))

      # The folder shape is the address, so a route need not say where a nested page sits — the file already did.
      def uri_for(item, slugs)
        route = item["route"].to_s
        return Uris.normalize(route.gsub(TOKEN, "")) if slugs == [ Reader::ROOT_SLUG ]

        route = route.sub("/{slug}", "{parent_slugs}/{slug}") unless route.include?("{parent_slugs}")
        parents = slugs[0..-2]
        path = route.sub("{parent_slugs}", parents.any? ? "/#{parents.join('/')}" : "").sub("{slug}", slugs.last)
        Uris.normalize(path.gsub(TOKEN, ""))
      end

      def index
        return @index || reload! unless Rails.application.config.enable_reloading

        watch! unless Current.content_checked
        @index || refresh!
      end

      def reload!
        @published_urls = nil
        @index = Index.build
        publish_assets!
        @index
      end

      def reset! = @index = nil

      # Development only: search follows the folder too. A checkout with no database yet still reads its content.
      def refresh!
        reload!.tap { Search.sync_files }
      rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => error
        Rails.logger&.warn("nibble: pages written as files were not indexed for search: #{error.message}")
        @index
      end

      # Checked once a request, as the schema is: a change under site/content/ alone never makes Rails reload code, so a
      # to_prepare hook would miss it.
      def watch!
        Current.content_checked = true
        path = Nibble.config.content_path.to_s
        @watcher = nil unless @watched_path == path
        @watched_path = path
        @watcher ||= ActiveSupport::FileUpdateChecker.new([], path => nil) { refresh! }
        @watcher.execute_if_updated
      end

      def body(path)
        text = path.read.sub(/\A---\n.*?\n---\n/m, "").strip
        images(rewrite(text, path), path)
      end

      # Build output rather than a second copy of the content: named by digest so it can be cached forever,
      # under public/ where the server sends it without Ruby, and thrown away rather than kept current.
      def publish_assets!
        root = Nibble.config.published_path
        wanted = {}
        index.files.each do |relative, asset|
          wanted[digested(relative, asset.digest)] = asset.path
          widths_for(asset).each { |width| wanted[digested(relative, asset.digest, width)] = [ asset.path, width ] }
        end
        wanted.each do |relative, source|
          target = root.join(relative)
          next if target.file?

          target.dirname.mkpath
          source.is_a?(Array) ? resize(source.first, target, source.last) : FileUtils.cp(source, target)
        end
        discard(root, wanted)
      rescue SystemCallError => error
        # A read-only filesystem is somebody's deployment, not a reason to refuse to start.
        Rails.logger&.warn("nibble: could not publish content assets: #{error.message}")
      end

      def asset_url(relative, width = nil)
        asset = index.file(relative) or return nil
        "/#{PUBLISHED}/#{digested(relative, asset.digest, width)}"
      end

      def published_urls
        @published_urls ||= index.files.to_h { |relative, asset| [ asset_url(relative), relative ] }
      end

      def widths_for(asset)
        return [] if asset.path.extname.downcase == VECTOR

        Array(Assets.preset(PRESET)&.dig("srcset")).select { |width| width < asset.width.to_i }
      end

      def srcset_for_url(url) = published_urls[url]&.then { |relative| srcset_for(relative) }

      def srcset_for(relative)
        asset = index.file(relative) or return nil
        widths = widths_for(asset)
        return nil if widths.empty?

        (widths.map { |w| "#{asset_url(relative, w)} #{w}w" } + [ "#{asset_url(relative)} #{asset.width}w" ]).join(", ")
      end

      private

      def rewrite(body, path)
        body.gsub(LINK) do
          target = resolve(path, Regexp.last_match(2))
          target ? "#{Regexp.last_match(1)}#{target}#{Regexp.last_match(3)}#{Regexp.last_match(4)}" : Regexp.last_match(0)
        end
      end

      def images(body, path)
        body.gsub(IMAGE) do
          file = path.dirname.join(Regexp.last_match(2)).cleanpath
          relative = file.relative_path_from(Nibble.config.content_path).to_s
          url = asset_url(relative) or next Regexp.last_match(0)

          "#{Regexp.last_match(1)}#{url}#{Regexp.last_match(3)}"
        end
      end

      def digested(relative, digest, width = nil)
        file = Pathname(relative)
        name = "#{file.basename(file.extname)}-#{digest}#{width ? "-#{width}" : ""}#{file.extname}"
        file.dirname.join(name).to_s.delete_prefix("./")
      end

      def resize(source, target, width)
        ImageProcessing::Vips.source(source).resize_to_limit(width, nil).call(destination: target.to_s)
      rescue StandardError => error
        Rails.logger&.warn("nibble: could not resize #{source}: #{error.message}")
      end

      def discard(root, wanted)
        return unless root.directory?

        Dir.glob("**/*", base: root).each do |relative|
          path = root.join(relative)
          path.delete if path.file? && !wanted.key?(relative)
        end
      end

      def resolve(path, relative)
        page = index.at_path(path.dirname.join(relative).cleanpath)
        page&.uri
      end
    end
  end
end
