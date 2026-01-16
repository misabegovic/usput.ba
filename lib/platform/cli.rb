# frozen_string_literal: true

require "thor"

module Platform
  # Thor CLI za Platform
  #
  # Omogućava direktno izvršavanje DSL komandi za Claude Code integraciju.
  # NAPOMENA: Nije dostupno u produkciji po defaultu (PLATFORM_CLI_ENABLED=true za omogućavanje)
  #
  # Primjeri:
  #   bin/platform exec 'schema | stats'
  #   bin/platform exec 'locations { city: "Mostar" } | count'
  #   bin/platform status
  #
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # Check if CLI is allowed in current environment
    def self.production_guard!
      return unless Rails.env.production?
      return if ENV["PLATFORM_CLI_ENABLED"] == "true"

      puts "❌ Platform CLI nije dostupan u produkciji."
      puts "   Postavi PLATFORM_CLI_ENABLED=true za omogućavanje."
      exit 1
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
    end

    desc "version", "Prikaži verziju Platform-a"
    def version
      puts "Platform v#{Platform.version}"
    end

    desc "query QUERY", "Izvrši DSL query direktno"
    option :json, type: :boolean, default: true, aliases: "-j", desc: "Output kao JSON"
    def query(dsl_query)
      self.class.production_guard!

      result = Platform::DSL.execute(dsl_query)
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
      self.class.production_guard!

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
      if options[:json] != false
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
  end
end
