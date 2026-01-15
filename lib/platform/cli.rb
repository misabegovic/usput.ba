# frozen_string_literal: true

require "thor"

module Platform
  # Thor CLI za Platform
  #
  # Ulazna tačka za konverzacijski interface sa Platform-om.
  #
  # Primjeri:
  #   bin/platform chat          # Pokreni interaktivnu sesiju
  #   bin/platform status        # Provjeri status sistema
  #   bin/platform version       # Prikaži verziju
  #
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "chat", "Pokreni interaktivnu chat sesiju sa Platform-om"
    option :conversation_id, type: :string, aliases: "-c", desc: "Nastavi postojeću konverzaciju"
    def chat
      print_banner
      conversation = load_or_create_conversation(options[:conversation_id])
      run_chat_loop(conversation)
    rescue Interrupt
      puts "\n\n👋 Doviđenja!"
    end

    desc "status", "Prikaži status Platform sistema"
    def status
      puts "🏔️  Usput.ba Platform v#{Platform.version}"
      puts
      puts "Sistem:"
      puts "  Rails: #{Rails.version}"
      puts "  Ruby: #{RUBY_VERSION}"
      puts "  Environment: #{Rails.env}"
      puts
      puts "Baza:"
      begin
        ActiveRecord::Base.connection.execute("SELECT 1")
        puts "  Status: ✅ Povezan"
        puts "  Adapter: #{ActiveRecord::Base.connection.adapter_name}"
      rescue => e
        puts "  Status: ❌ Greška (#{e.message})"
      end
      puts
      puts "RubyLLM:"
      if defined?(RubyLLM)
        puts "  Status: ✅ Učitan"
        puts "  Model: #{RubyLLM.config.default_model rescue 'nije konfigurisan'}"
      else
        puts "  Status: ❌ Nije učitan"
      end
    end

    desc "version", "Prikaži verziju Platform-a"
    def version
      puts "Platform v#{Platform.version}"
    end

    desc "query QUERY", "Izvrši DSL query direktno"
    def query(dsl_query)
      result = Platform::DSL.execute(dsl_query)
      puts result.to_json
    rescue Platform::DSL::ParseError => e
      puts "❌ Greška u parsiranju: #{e.message}"
    rescue Platform::DSL::ExecutionError => e
      puts "❌ Greška u izvršavanju: #{e.message}"
    end

    private

    def print_banner
      puts
      puts "🏔️  Usput.ba Platform v#{Platform.version}"
      puts "─" * 40
      puts "Zdravo! Ja sam Usput.ba platforma."
      puts "Kako ti mogu pomoći?"
      puts
      puts "Savjeti:"
      puts "  - Upiši 'help' za pomoć"
      puts "  - Upiši 'exit' ili Ctrl+C za izlaz"
      puts
    end

    def load_or_create_conversation(conversation_id)
      if conversation_id
        conv = PlatformConversation.find_by(id: conversation_id)
        if conv
          puts "📂 Nastavljam konverzaciju #{conv.id[0..7]}..."
          Platform::Conversation.new(conv)
        else
          puts "⚠️  Konverzacija #{conversation_id} nije pronađena, kreiram novu."
          Platform::Conversation.new
        end
      else
        Platform::Conversation.new
      end
    end

    def run_chat_loop(conversation)
      loop do
        print "\n💬 Ti: "
        input = $stdin.gets&.strip

        break if input.nil? || input.empty? || %w[exit quit q].include?(input.downcase)

        if input.downcase == "help"
          print_help
          next
        end

        response = conversation.send_message(input)
        puts "\n🏔️  Usput: #{response}"
      end
    end

    def print_help
      puts
      puts "📚 Pomoć"
      puts "─" * 30
      puts
      puts "Možeš me pitati bilo šta o Usput.ba platformi:"
      puts
      puts "Primjeri:"
      puts "  • Koliko imam lokacija u Sarajevu?"
      puts "  • Prikaži statistike po gradovima"
      puts "  • Koje lokacije nemaju audio ture?"
      puts "  • Generiši sadržaj za Bihać"
      puts
      puts "DSL komande (napredni korisnici):"
      puts "  • schema | stats"
      puts "  • locations { city: \"Mostar\" } | sample 10"
      puts "  • summaries { region: \"sarajevo\" } | show"
      puts
      puts "Upiši 'exit' ili Ctrl+C za izlaz."
    end
  end
end
