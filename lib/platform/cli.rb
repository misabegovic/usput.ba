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
    option :json, type: :boolean, default: true, aliases: "-j", desc: "Output kao JSON"
    def query(dsl_query)
      result = Platform::DSL.execute(dsl_query)
      # Default to JSON output (options[:json] is true by default, nil means default)
      use_json = options[:json] != false
      if use_json
        puts result.to_json
      else
        puts format_human_readable(normalize_result(result))
      end
    rescue Platform::DSL::ParseError => e
      puts "❌ Greška u parsiranju: #{e.message}"
    rescue Platform::DSL::ExecutionError => e
      puts "❌ Greška u izvršavanju: #{e.message}"
    end

    desc "exec QUERY", "Izvrši DSL query direktno (za Claude Code integraciju)"
    option :json, type: :boolean, default: true, aliases: "-j", desc: "Output kao JSON (default: true)"
    option :pretty, type: :boolean, default: false, aliases: "-p", desc: "Pretty-print JSON"
    option :batch, type: :string, aliases: "-b", desc: "Izvrši komande iz fajla (jedna po liniji)"
    def exec(dsl_query = nil)
      if options[:batch]
        execute_batch(options[:batch])
      elsif dsl_query
        execute_single(dsl_query)
      else
        puts format_error("Potreban DSL query ili --batch fajl")
        exit 1
      end
    rescue Platform::DSL::ParseError => e
      puts format_output({ success: false, error: "parse_error", message: e.message })
      exit 1
    rescue Platform::DSL::ExecutionError => e
      puts format_output({ success: false, error: "execution_error", message: e.message })
      exit 1
    rescue StandardError => e
      puts format_output({ success: false, error: "unexpected_error", message: e.message })
      exit 1
    end

    private

    # ===================
    # Exec command helpers
    # ===================

    def execute_single(dsl_query)
      result = Platform::DSL.execute(dsl_query)
      output = normalize_result(result)
      puts format_output(output)
    end

    def execute_batch(file_path)
      unless File.exist?(file_path)
        puts format_output({ success: false, error: "file_not_found", message: "Fajl nije pronađen: #{file_path}" })
        exit 1
      end

      queries = File.readlines(file_path).map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
      results = []

      queries.each_with_index do |query, index|
        begin
          result = Platform::DSL.execute(query)
          results << { index: index, query: query, success: true, result: normalize_result(result) }
        rescue Platform::DSL::ParseError => e
          results << { index: index, query: query, success: false, error: "parse_error", message: e.message }
        rescue Platform::DSL::ExecutionError => e
          results << { index: index, query: query, success: false, error: "execution_error", message: e.message }
        end
      end

      summary = {
        total: queries.size,
        success: results.count { |r| r[:success] },
        failed: results.count { |r| !r[:success] },
        results: results
      }

      puts format_output(summary)
    end

    def normalize_result(result)
      # Wrap raw values in success structure
      case result
      when Hash
        result[:success] = true unless result.key?(:success)
        result
      when Array
        { success: true, count: result.size, data: result }
      when Integer, Float
        { success: true, value: result }
      when String
        { success: true, message: result }
      when nil
        { success: true, data: nil }
      else
        { success: true, data: result.to_s }
      end
    end

    def format_output(data)
      if options[:json] != false # Default je true za exec
        if options[:pretty]
          JSON.pretty_generate(data)
        else
          data.to_json
        end
      else
        format_human_readable(data)
      end
    end

    def format_error(message)
      if options[:json] != false
        { success: false, error: message }.to_json
      else
        "❌ #{message}"
      end
    end

    def format_human_readable(data)
      return "✅ #{data[:message]}" if data[:message] && data[:success]
      return "❌ #{data[:error]}: #{data[:message]}" if data[:error]

      lines = []
      data.each do |key, value|
        next if key == :success
        case value
        when Array
          lines << "#{key}:"
          value.each { |v| lines << "  - #{format_value(v)}" }
        when Hash
          lines << "#{key}:"
          value.each { |k, v| lines << "  #{k}: #{format_value(v)}" }
        else
          lines << "#{key}: #{format_value(value)}"
        end
      end
      lines.join("\n")
    end

    def format_value(value)
      case value
      when Hash
        value.map { |k, v| "#{k}=#{v}" }.join(", ")
      when Array
        value.join(", ")
      else
        value.to_s
      end
    end

    # ===================
    # Chat command helpers
    # ===================

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
