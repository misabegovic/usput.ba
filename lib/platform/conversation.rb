# frozen_string_literal: true

module Platform
  # Conversation - Session management za Platform chat
  #
  # Ova klasa upravlja životnim ciklusom konverzacije:
  # - Kreira i učitava PlatformConversation
  # - Šalje poruke kroz Brain
  # - Izvršava DSL queries kada Brain vrati DSL
  # - Čuva historiju
  #
  # Primjer:
  #   conv = Platform::Conversation.new
  #   response = conv.send_message("Koliko imam lokacija u Sarajevu?")
  #
  class Conversation
    attr_reader :record, :brain

    def initialize(record = nil)
      @record = record || PlatformConversation.create!
      @brain = Brain.new(self)
    end

    # Pošalji poruku i dobij odgovor
    def send_message(content)
      # Sačuvaj korisničku poruku
      record.add_message(role: "user", content: content)

      # Pošalji Brain-u i dobij odgovor
      response = brain.process(content)

      # Sačuvaj odgovor
      record.add_message(
        role: "assistant",
        content: response[:content],
        metadata: { dsl_queries: response[:dsl_queries] }
      )

      response[:content]
    rescue => e
      handle_error(e)
    end

    # ID konverzacije za referencu
    def id
      record.id
    end

    # Historija poruka
    def messages
      record.messages
    end

    # Kontekst sesije
    def context
      record.context
    end

    # Ažuriraj kontekst
    def update_context(new_context)
      record.update!(context: record.context.merge(new_context))
    end

    private

    def handle_error(error)
      Rails.logger.error "[Platform::Conversation] Error: #{error.message}"
      Rails.logger.error error.backtrace.first(10).join("\n")

      record.mark_error!(error.message)

      "Došlo je do greške: #{error.message}. Pokušaj ponovo ili reformuliši pitanje."
    end
  end
end
