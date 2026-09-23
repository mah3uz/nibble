module Nibble
  # Composes realistic posts from vendor/nibble/db/dev_content.yml: for clicking through a development site and for
  # benchmarks that need the shape of real content (images, several topics, authors, mixed states).
  class DemoContent
    BANK = Nibble.core_root.join("db/dev_content.yml")

    def initialize(images:, actor: nil, random: Random.new(42))
      @bank = YAML.load_file(BANK)
      @images = images
      @actor = actor
      @random = random
    end

    def seed(count)
      authors = @bank["authors"].map { |name| term("authors", name) }
      topics = @bank["topics"].to_h { |name, _| [ name, term("topics", name) ] }
      titles(count).each_with_index.count do |(title, topic_name), index|
        next false if Records::Entry.kept.exists?(collection: "posts", title:)

        image = @images.sample(random: @random) if @images.any? && @random.rand < 0.75
        entry = create_post(title, @bank["topics"][topic_name], author: authors[@random.rand(authors.size)],
          topics: pick_topics(topics, topic_name), image:)
        schedule(entry, index)
        true
      end
    end

    private

    def term(taxonomy, title)
      Records::Term.kept.find_by(taxonomy:, title:) ||
        Lifecycle.call(Records::Term.new(taxonomy:), :create, { "title" => title }, actor: @actor).record
    end

    def titles(count)
      names = @bank["topics"].keys
      seen = Set.new
      list = []
      round = 0
      while list.size < count && round < 200
        names.each_with_index do |name, position|
          subjects = @bank["topics"][name]["subjects"]
          title = format(@bank["templates"][(round * 3 + position) % @bank["templates"].size], subjects[round % subjects.size])
          title = title[0].upcase + title[1..]
          list << [ title, name ] if seen.add?(title) && list.size < count
        end
        round += 1
      end
      list
    end

    def pick_topics(topics, primary)
      extra = topics.keys.reject { |name| name == primary }.sample(random: @random)
      ids = [ topics[primary] ]
      ids << topics[extra] if @random.rand < 0.3
      ids.map { |term| term.id.to_s }
    end

    def create_post(title, topic, author:, topics:, image:)
      paragraphs = topic["paragraphs"].shuffle(random: @random)
      data = {
        "title" => title,
        "excerpt" => paragraphs.first.split(/(?<=\.)\s/).first,
        "body" => body(topic, paragraphs, image),
        "authors" => [ author.id.to_s ],
        "topics" => topics
      }
      data["featured_image"] = [ { "asset" => image.id.to_s } ] if image
      result = Lifecycle.call(Records::Entry.new(collection: "posts"), :create, data, actor: @actor)
      raise Error, "couldn't create #{title}: #{result.errors}" unless result.ok?

      result.record
    end

    def body(topic, paragraphs, image)
      headings = topic["headings"].shuffle(random: @random)
      nodes = [ paragraph(paragraphs[0]), paragraph(paragraphs[1]), heading(headings[0]), paragraph(paragraphs[2]) ]
      nodes << { "type" => "bulletList", "content" => topic["list"].sample(3 + @random.rand(3), random: @random).map { |item| { "type" => "listItem", "content" => [ paragraph(item) ] } } }
      nodes += [ heading(headings[1]), paragraph(paragraphs[3]) ]
      nodes << { "type" => "blockquote", "content" => [ paragraph(topic["quotes"].sample(random: @random)) ] } if @random.rand < 0.6
      if image && @random.rand < 0.35
        nodes << { "type" => "image", "attrs" => { "asset" => image.id.to_s, "alt" => @bank["captions"].sample(random: @random) } }
      end
      nodes += [ paragraph(paragraphs[4]), heading(headings[2]), paragraph(paragraphs[5]) ]
      nodes << paragraph(paragraphs[6]) if @random.rand < 0.5
      nodes
    end

    def paragraph(text) = { "type" => "paragraph", "content" => [ { "type" => "text", "text" => text } ] }
    def heading(text) = { "type" => "heading", "attrs" => { "level" => 2 }, "content" => [ { "type" => "text", "text" => text } ] }

    def schedule(entry, index)
      return if (index % 13) == 5

      if (index % 17) == 3
        Lifecycle.call(entry, :publish, { "published_at" => (index % 30 + 2).days.from_now.change(hour: 9).utc.iso8601 }, actor: @actor)
        return
      end

      at = (index * 5.5).days.ago - @random.rand(0..20).hours
      Lifecycle.call(entry, :publish, { "published_at" => at.utc.iso8601 }, actor: @actor)
      Lifecycle.call(entry, :unpublish, {}, actor: @actor) if (index % 29) == 11
    end
  end
end
