# frozen_string_literal: true

# PlatformConversation - Perzistentne konverzacije sa Platform-om
#
# Čuva historiju poruka i kontekst sesije za Platform AI.
#
# Atributi:
#   - messages: JSONB array poruka [{role: "user"|"assistant", content: "..."}]
#   - context: JSONB hash sa dodatnim kontekstom sesije
#   - status: "active", "archived", "error"
#
class PlatformConversation < PlatformRecord
  # Validacije
  validates :status, inclusion: { in: %w[active archived error] }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :recent, -> { order(updated_at: :desc) }

  # Dodaj poruku u konverzaciju
  def add_message(role:, content:, metadata: {})
    message = {
      role: role.to_s,
      content: content,
      timestamp: Time.current.iso8601,
      **metadata
    }

    messages << message
    save!
    message
  end

  # Dohvati poruke u formatu za RubyLLM
  def messages_for_llm
    messages.map do |msg|
      { role: msg["role"], content: msg["content"] }
    end
  end

  # Broj poruka u konverzaciji
  def message_count
    messages.size
  end

  # Posljednja poruka
  def last_message
    messages.last
  end

  # Arhiviraj konverzaciju
  def archive!
    update!(status: "archived")
  end

  # Označi kao grešku
  def mark_error!(error_message)
    context["last_error"] = error_message
    context["error_at"] = Time.current.iso8601
    update!(status: "error", context: context)
  end
end
