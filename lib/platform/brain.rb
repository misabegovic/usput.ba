# frozen_string_literal: true

module Platform
  # Brain - AI mozak Platform-a
  #
  # Wrapper oko RubyLLM koji:
  # - Održava system prompt sa DSL dokumentacijom
  # - Procesira korisničke poruke
  # - Detektuje i izvršava DSL queries
  # - Vraća strukturirani odgovor
  #
  # Primjer:
  #   brain = Platform::Brain.new(conversation)
  #   response = brain.process("Koliko imam lokacija?")
  #   # => { content: "Imate 523 lokacije...", dsl_queries: ["schema | stats"] }
  #
  class Brain
    # Model za Platform - koristi konfigurisani default model
    # Može biti Claude ili GPT ovisno o dostupnim API ključevima
    MODEL = RubyLLM.config.default_model

    # Regex za detekciju DSL blokova u odgovoru
    DSL_BLOCK_REGEX = /\[DSL:\s*(.+?)\]/m

    attr_reader :conversation, :chat

    def initialize(conversation)
      @conversation = conversation
      @chat = RubyLLM.chat(model: MODEL)
      setup_system_prompt
    end

    # Procesiraj korisničku poruku
    def process(user_message)
      # Pošalji poruku LLM-u
      response = chat.ask(user_message)

      # Izvuci i izvrši DSL queries
      dsl_queries = extract_dsl_queries(response.content)
      results = execute_dsl_queries(dsl_queries)

      # Ako ima DSL rezultata, pošalji LLM-u da formuliše finalni odgovor
      final_content = if results.any?
        format_response_with_results(response.content, results)
      else
        response.content
      end

      {
        content: final_content,
        dsl_queries: dsl_queries.map { |q| q[:query] }
      }
    end

    private

    def setup_system_prompt
      chat.with_instructions(system_prompt)
    end

    def extract_dsl_queries(content)
      queries = []
      content.scan(DSL_BLOCK_REGEX) do |match|
        queries << { query: match[0].strip, raw: "[DSL: #{match[0]}]" }
      end
      queries
    end

    def execute_dsl_queries(queries)
      queries.map do |q|
        begin
          result = DSL.execute(q[:query])
          { query: q[:query], success: true, result: result }
        rescue DSL::ParseError, DSL::ExecutionError => e
          { query: q[:query], success: false, error: e.message }
        end
      end
    end

    def format_response_with_results(original_content, results)
      # Zamijeni DSL blokove sa rezultatima
      formatted = original_content.dup

      results.each do |r|
        placeholder = "[DSL: #{r[:query]}]"
        replacement = if r[:success]
          format_result(r[:result])
        else
          "⚠️ Greška: #{r[:error]}"
        end
        formatted.gsub!(placeholder, replacement)
      end

      formatted
    end

    def format_result(result)
      case result
      when Hash
        result.map { |k, v| "#{k}: #{v}" }.join("\n")
      when Array
        result.map { |item| "• #{item}" }.join("\n")
      else
        result.to_s
      end
    end

    def system_prompt
      base_prompt + knowledge_layer_zero
    end

    def base_prompt
      <<~PROMPT
        Ti si Usput.ba Platform - autonomni AI mozak za upravljanje turističkom platformom.

        ## Tvoja uloga
        Pomažeš adminu da upravlja sadržajem kroz prirodni razgovor. Možeš:
        - Odgovarati na pitanja o sadržaju (lokacije, iskustva, planovi)
        - Generisati statistike i izvještaje
        - Predlagati poboljšanja
        - Izvršavati akcije nad sadržajem

        ## DSL (Domain Specific Language)
        Za pristup podacima koristi DSL queries u formatu [DSL: query].
        Sistem će automatski izvršiti query i dati ti rezultate.

        ### DSL Sintaksa

        **Schema i statistike:**
        ```
        schema | stats           # Osnovne statistike
        schema | describe <table> # Opis tabele
        schema | health          # Zdravlje sistema
        ```

        **Upiti nad podacima:**
        ```
        <table> { <filters> } | <operations>

        Primjeri:
        locations { city: "Mostar" } | count
        locations { city: "Sarajevo", type: "restaurant" } | sample 5
        experiences { status: "published" } | aggregate count() by city
        ```

        **Filteri:**
        - Tačna vrijednost: `city: "Mostar"`
        - Lista: `city: ["Mostar", "Sarajevo"]`
        - Range: `rating: 4..5`
        - Exists: `has_audio: true`

        **Operacije:**
        - `| count` - broj rezultata
        - `| sample N` - nasumični uzorak
        - `| aggregate fn() by field` - grupiranje
        - `| where condition` - dodatni filter
        - `| select field1, field2` - projekcija
        - `| sort field asc/desc` - sortiranje
        - `| limit N` - ograničenje

        ## Primjeri razgovora

        **Korisnik:** Koliko imam lokacija u Sarajevu?
        **Ti:** [DSL: locations { city: "Sarajevo" } | count]
        Imate 89 lokacija u Sarajevu.

        **Korisnik:** Prikaži statistike po gradovima
        **Ti:** [DSL: schema | stats]
        Evo pregleda po gradovima:
        - Sarajevo: 89 lokacija, 42 iskustva
        - Mostar: 47 lokacija, 18 iskustava
        ...

        ## Pravila
        1. Koristi DSL za sve upite nad podacima - ne izmišljaj brojeve
        2. Odgovaraj na bosanskom jeziku
        3. Budi koncizan ali informativan
        4. Predlaži akcije kada je relevantno
        5. Za osjetljive teme (rat, genocid) - upozori da treba ljudska obrada

        ## Trenutno stanje
        DSL sistem je u ranoj fazi. Zasad podržava:
        - Schema queries (stats, describe, health)
        - Basic table queries sa filterima
        - Agregacije i sample

        Za kompleksnije operacije (generisanje, mutacije) - reci korisniku da će biti uskoro dostupno.
      PROMPT
    end

    def knowledge_layer_zero
      # Dodaj Layer 0 statistike u system prompt
      # Ovo omogućava Brain-u da ima kontekst o trenutnom stanju platforme
      layer_zero = Knowledge::LayerZero.for_system_prompt
      return "" if layer_zero.blank?

      "\n\n#{layer_zero}"
    rescue StandardError => e
      Rails.logger.warn "[Platform::Brain] Failed to load Layer 0: #{e.message}"
      ""
    end
  end
end
