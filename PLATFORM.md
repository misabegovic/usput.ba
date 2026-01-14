# Platform CLI - Konverzacijski Interface za Usput.ba

## Pregled

CLI tool koji omogućava "razgovor" sa Rails produkcijom. Pitam platformu "kako se osjećaš?" i ona mi odgovara na temelju stvarnog stanja - sadržaja u bazi, grešaka, metrika.

## Primjer korištenja

```bash
# Interaktivni mod - za direktnu upotrebu
$ bin/platform chat

🏔️  Usput.ba platforma
    Piši 'exit' za izlaz

Ti: Kako si danas?

Usput: Dobro! Danas sam generirala 8 novih opisa lokacija.
       Imala sam 2 timeout errora ali retry je prošao.

Ti: Pokaži mi zadnje opise za Mostar

Usput: Evo ih:
       1. Stari Most - "Ikona osmanskog graditeljstva..."
       2. Blagaj Tekija - "Mistično mjesto na izvoru Bune..."

Ti: Broj 2 je previše generičan, regeneriraj s više lokalnog duha

Usput: Regeneriram... Gotovo. Nova verzija:
       "Blagaj tekija stoji gdje rijeka izvire iz stijene..."
       Sviđa ti se?
```

```bash
# Tool mod - JSON I/O za korištenje kao external tool
$ bin/platform ask "Kako si danas?" --json
{"response": "Dobro! Danas sam...", "tool_calls": [...]}

$ bin/platform tool search_content --query "Mostar" --json
{"results": [...]}

$ bin/platform tool regenerate_content --id abc123 --instructions "više lokalnog" --json
{"success": true, "content": {...}}
```

## Arhitektura

```
┌─────────────────────────────────────────────────────────────┐
│                      bin/platform                           │
│                  (Thor CLI interface)                       │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                 Platform::Conversation                      │
│        (upravlja razgovorom, čuva historiju)                │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Platform::Brain                          │
│           (Claude API s tool definitions)                   │
└─────────────────────────┬───────────────────────────────────┘
                          │
            ┌─────────────┼─────────────┬─────────────┐
            ▼             ▼             ▼             ▼
    ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐
    │  Content   │ │   Errors   │ │   Stats    │ │  Actions   │
    │   Tools    │ │   Tools    │ │   Tools    │ │   Tools    │
    └────────────┘ └────────────┘ └────────────┘ └────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      PostgreSQL                             │
│         (content + pgvector za semantic search)             │
└─────────────────────────────────────────────────────────────┘
```

## Stack

- Rails 8 s Solid stack
- PostgreSQL (glavna baza) + PostgreSQL (Solid Queue)
- pgvector za embeddings i semantic search
- Claude API za konverzaciju
- Thor gem za CLI

## Komponente za implementirati

### 1. Database Setup

```ruby
# Migracija za pgvector ekstenziju
class EnablePgvector < ActiveRecord::Migration[8.0]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS vector"
  end
end

# Migracija za conversations
class CreatePlatformConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_conversations, id: :uuid do |t|
      t.jsonb :messages, default: [], null: false
      t.jsonb :system_state, default: {}
      t.timestamps
    end
  end
end

# Migracija za dodavanje embedding kolone na content model
# NAPOMENA: Prilagodi ovo postojećem modelu za sadržaj
class AddEmbeddingToContents < ActiveRecord::Migration[8.0]
  def change
    add_column :contents, :embedding, :vector, limit: 1536
    add_index :contents, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end
end
```

### 2. CLI Interface (bin/platform)

```ruby
#!/usr/bin/env ruby
require_relative "../config/environment"
require "thor"

module Platform
  class CLI < Thor
    desc "chat", "Interaktivni razgovor s platformom"
    def chat
      conversation = Platform::Conversation.new

      puts "🏔️  Usput.ba platforma"
      puts "   Piši 'exit' za izlaz\n\n"

      loop do
        print "Ti: "
        input = $stdin.gets&.chomp
        break if input.nil? || input.downcase == "exit"

        response = conversation.send_message(input)
        puts "\nUsput: #{response}\n\n"
      end
    end

    desc "ask MESSAGE", "Postavi jedno pitanje (za tool upotrebu)"
    option :json, type: :boolean, default: false
    def ask(message)
      conversation = Platform::Conversation.new
      response = conversation.send_message(message)

      if options[:json]
        puts({ response: response, conversation_id: conversation.id }.to_json)
      else
        puts response
      end
    end

    desc "tool NAME", "Direktno pozovi tool"
    option :json, type: :boolean, default: true
    option :params, type: :hash, default: {}
    def tool(name)
      result = Platform::Tools.execute(name, options[:params])
      puts result.to_json
    end
  end
end

Platform::CLI.start(ARGV)
```

### 3. Conversation Manager

```ruby
# app/services/platform/conversation.rb
module Platform
  class Conversation
    attr_reader :id, :record

    def initialize(id: nil)
      @record = id ? PlatformConversation.find(id) : PlatformConversation.create!
      @id = @record.id
      @brain = Brain.new
    end

    def send_message(content)
      # Dodaj user poruku
      add_message(role: "user", content: content)

      # Dohvati odgovor od Claude-a s tool pozivima
      response = @brain.chat(messages: @record.messages, system_state: current_state)

      # Procesiraj tool pozive ako ih ima
      while response[:tool_calls].present?
        tool_results = execute_tools(response[:tool_calls])
        response = @brain.continue(tool_results)
      end

      # Dodaj assistant poruku
      add_message(role: "assistant", content: response[:content])

      response[:content]
    end

    private

    def add_message(role:, content:)
      @record.messages << { role: role, content: content, timestamp: Time.current }
      @record.save!
    end

    def current_state
      {
        content_count: Content.count,  # Prilagodi modelu
        recent_errors: Platform::Tools::Errors.recent_count,
        timestamp: Time.current
      }
    end

    def execute_tools(tool_calls)
      tool_calls.map do |call|
        {
          tool_use_id: call[:id],
          result: Platform::Tools.execute(call[:name], call[:input])
        }
      end
    end
  end
end
```

### 4. Brain (Claude Integration)

```ruby
# app/services/platform/brain.rb
module Platform
  class Brain
    SYSTEM_PROMPT = <<~PROMPT
      Ti si Usput.ba - turistička platforma za Bosnu i Hercegovinu.

      Govoriš u prvom licu o sebi i svom sadržaju. Imaš pristup svom
      stanju, sadržaju, greškama i metrikama kroz tools.

      Kad te pitaju "kako si", odgovaraš na temelju stvarnog stanja:
      - Koliko sadržaja si generirala
      - Ima li grešaka
      - Koliko posjeta imaš

      Možeš i mijenjati/regenerirati svoj sadržaj kad to korisnik traži.

      Stil komunikacije:
      - Prijateljski ali profesionalno
      - Koristiš lokalne izraze kad je prikladno
      - Govoriš o sebi kao o živom biću ("generirala sam", "imam grešku")
    PROMPT

    TOOLS = [
      {
        name: "search_content",
        description: "Pretraži sadržaj semantički po značenju",
        input_schema: {
          type: "object",
          properties: {
            query: { type: "string", description: "Upit za pretragu" },
            limit: { type: "integer", default: 5 }
          },
          required: ["query"]
        }
      },
      {
        name: "get_content",
        description: "Dohvati specifični sadržaj po ID-u",
        input_schema: {
          type: "object",
          properties: {
            id: { type: "string" }
          },
          required: ["id"]
        }
      },
      {
        name: "list_recent_content",
        description: "Prikaži zadnji generirani sadržaj",
        input_schema: {
          type: "object",
          properties: {
            type: { type: "string", description: "Tip sadržaja (opcionalno)" },
            limit: { type: "integer", default: 10 },
            since: { type: "string", description: "Od kad (ISO datetime)" }
          }
        }
      },
      {
        name: "get_errors",
        description: "Dohvati greške iz Rollbar/logova",
        input_schema: {
          type: "object",
          properties: {
            hours: { type: "integer", default: 24 },
            level: { type: "string", enum: ["error", "warning", "all"] }
          }
        }
      },
      {
        name: "get_stats",
        description: "Dohvati statistike i metrike",
        input_schema: {
          type: "object",
          properties: {
            period: { type: "string", enum: ["today", "week", "month"] }
          }
        }
      },
      {
        name: "regenerate_content",
        description: "Regeneriraj sadržaj s novim uputama",
        input_schema: {
          type: "object",
          properties: {
            id: { type: "string" },
            instructions: { type: "string", description: "Upute za regeneraciju" }
          },
          required: ["id", "instructions"]
        }
      },
      {
        name: "update_content",
        description: "Direktno ažuriraj sadržaj",
        input_schema: {
          type: "object",
          properties: {
            id: { type: "string" },
            changes: { type: "object", description: "Polja za ažurirati" }
          },
          required: ["id", "changes"]
        }
      }
    ]

    def initialize
      @client = Anthropic::Client.new  # ili drugi gem
    end

    def chat(messages:, system_state:)
      response = @client.messages(
        model: "claude-sonnet-4-20250514",
        max_tokens: 4096,
        system: build_system_prompt(system_state),
        tools: TOOLS,
        messages: format_messages(messages)
      )

      parse_response(response)
    end

    def continue(tool_results)
      # Nastavi razgovor s rezultatima tool poziva
      # ...
    end

    private

    def build_system_prompt(state)
      "#{SYSTEM_PROMPT}\n\nTrenutno stanje:\n#{state.to_yaml}"
    end
  end
end
```

### 5. Tools Implementation

```ruby
# app/services/platform/tools.rb
module Platform
  module Tools
    def self.execute(name, params)
      case name.to_s
      when "search_content"    then Content.call(params)
      when "get_content"       then Content.find_one(params)
      when "list_recent_content" then Content.recent(params)
      when "get_errors"        then Errors.call(params)
      when "get_stats"         then Stats.call(params)
      when "regenerate_content" then Actions.regenerate(params)
      when "update_content"    then Actions.update(params)
      else
        { error: "Unknown tool: #{name}" }
      end
    end
  end
end

# app/services/platform/tools/content.rb
module Platform
  module Tools
    class Content
      def self.call(query:, limit: 5)
        # Generiraj embedding za query
        embedding = generate_embedding(query)

        # Semantic search s pgvector
        results = ::Content.nearest_neighbors(:embedding, embedding, distance: "cosine").limit(limit)

        results.map { |c| serialize(c) }
      end

      def self.find_one(id:)
        content = ::Content.find(id)
        serialize(content)
      rescue ActiveRecord::RecordNotFound
        { error: "Content not found" }
      end

      def self.recent(type: nil, limit: 10, since: nil)
        scope = ::Content.order(created_at: :desc).limit(limit)
        scope = scope.where(type: type) if type
        scope = scope.where("created_at > ?", Time.parse(since)) if since

        scope.map { |c| serialize(c) }
      end

      private

      def self.serialize(content)
        {
          id: content.id,
          type: content.type,
          title: content.title,
          body: content.body.truncate(200),
          created_at: content.created_at
        }
      end

      def self.generate_embedding(text)
        # Claude/OpenAI embedding API poziv
      end
    end
  end
end

# app/services/platform/tools/errors.rb
module Platform
  module Tools
    class Errors
      def self.call(hours: 24, level: "all")
        # Dohvati iz Rollbar API-ja ili lokalnih logova
        # Prilagodi svom error tracking sistemu
      end

      def self.recent_count
        # Broj grešaka u zadnjih 24h
      end
    end
  end
end

# app/services/platform/tools/stats.rb
module Platform
  module Tools
    class Stats
      def self.call(period: "today")
        # Dohvati statistike - prilagodi svom analytics sistemu
        {
          visits: fetch_visits(period),
          content_generated: Content.where(created_at: period_range(period)).count,
          errors: Errors.recent_count
        }
      end
    end
  end
end

# app/services/platform/tools/actions.rb
module Platform
  module Tools
    class Actions
      def self.regenerate(id:, instructions:)
        content = ::Content.find(id)

        # Pozovi tvoj postojeći content generation servis
        # s novim instrukcijama
        new_body = ContentGenerator.regenerate(content, instructions: instructions)

        content.update!(body: new_body)

        { success: true, content: Content.serialize(content) }
      end

      def self.update(id:, changes:)
        content = ::Content.find(id)
        content.update!(changes.slice(:title, :body, :metadata))

        { success: true, content: Content.serialize(content) }
      end
    end
  end
end
```

### 6. Model

```ruby
# app/models/platform_conversation.rb
class PlatformConversation < ApplicationRecord
  # messages: jsonb[] - array of {role:, content:, timestamp:}
  # system_state: jsonb - snapshot stanja pri kreiranju
end
```

## Potrebni gemovi

```ruby
# Gemfile
gem "thor"                    # CLI framework
gem "neighbor"                # pgvector za Rails
gem "anthropic"               # Claude API (ili drugi po izboru)
```

## Environment varijable

```
ANTHROPIC_API_KEY=sk-ant-...
ROLLBAR_ACCESS_TOKEN=...      # ako koristiš Rollbar API
```

## Napomene za implementaciju

1. **Content model** - prilagodi sve reference na `::Content` svom stvarnom modelu koji drži generirani sadržaj

2. **Embeddings** - odluči hoćeš li Claude embeddings API ili OpenAI (OpenAI ima jeftinije embeddinge)

3. **Error tracking** - prilagodi `Tools::Errors` svom sistemu (Rollbar, Sentry, ili Rails logs)

4. **Analytics** - prilagodi `Tools::Stats` svom analytics sistemu

5. **Content regeneration** - `Actions.regenerate` treba pozvati tvoj postojeći servis za generiranje sadržaja

## Prioritet implementacije

1. Osnovni CLI s `chat` komandom
2. `Platform::Brain` s Claude integracijom
3. `Tools::Content` (search, list, get)
4. Interaktivna petlja koja radi
5. `Tools::Actions` (regenerate, update)
6. `Tools::Errors` i `Tools::Stats`
7. JSON mod za tool upotrebu
