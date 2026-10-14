# frozen_string_literal: true

module Usput
  # bin/usput: the usput commands from a terminal, in English, with content
  # in Bosnian unless --locale says otherwise.
  #
  #   bin/usput help
  #   bin/usput places list city=Mostar limit=5
  #   bin/usput places show 0b6f...      (bare values fill the required parameters in order)
  #   bin/usput reviews queue --as curator@usput.local
  #   bin/usput reviews approve 7c1e... --as curator@usput.local
  #   bin/usput mcp --as curator@usput.local   (the MCP server over stdio)
  #   bin/usput tokens issue admin@usput.local laptop
  #
  # --json prints JSON for agents; otherwise a table for people. Exit status
  # is 0 on success, 1 when the command refuses, 2 on a usage error.
  class CLI
    USAGE = 2
    REFUSED = 1

    def self.start(argv) = exit(new(argv).run)

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
    end

    def run
      @json = !@argv.delete("--json").nil?
      @as = take_option("--as")
      @locale = take_option("--locale") || "bs"
      case @argv.first
      when nil, "help", "--help", "-h" then help(@argv[1..].join("."))
      when "mcp" then serve_mcp
      when "tokens" then tokens(*@argv[1..])
      else run_command
      end
    rescue Usage => e
      @err.puts(e.message)
      USAGE
    rescue Command::Denied, Command::Invalid, ActiveRecord::RecordNotFound => e
      @err.puts(e.message)
      REFUSED
    end

    private

    class Usage < StandardError; end

    def run_command
      command, rest = resolve
      result = I18n.with_locale(@locale) { command.call(actor:, **arguments(command, rest)) }
      print_result(result)
      0
    end

    # places list, or search: two words first, then one.
    def resolve
      [ 2, 1 ].each do |words|
        command = Commands.find(@argv.first(words).join("."))
        return [ command, @argv.drop(words) ] if command
      end
      raise Usage, "No command #{@argv.first(2).join(' ')}. Try bin/usput help."
    end

    def arguments(command, rest)
      rest.each_with_object({}) do |word, args|
        key, value = word.split("=", 2)
        if value.nil?
          unfilled = command.params.select(&:required).map(&:name).find { |name| !args.key?(name) }
          raise Usage, "#{word}: name it, as key=value" if unfilled.nil?

          args[unfilled] = word
        else
          args[key.delete_prefix("--").to_sym] = value
        end
      end
    end

    def actor
      return nil if @as.nil?

      User.find_by(email: @as.downcase) || raise(Usage, "No account #{@as}")
    end

    def serve_mcp
      server = MCPServer.build(actor:, decides: true)
      ::MCP::Server::Transports::StdioTransport.new(server).open
      0
    end

    def tokens(verb = nil, *rest)
      case verb
      when "issue"
        email, name = rest
        raise Usage, "bin/usput tokens issue EMAIL NAME" if email.nil? || name.nil?

        user = User.find_by(email: email.downcase) || raise(Usage, "No account #{email}")
        record, token = APIToken.issue!(user:, name:)
        @out.puts("Token #{record.id} for #{user.email} (#{user.user_type}), shown once:")
        @out.puts(token)
      when "list"
        print_result(APIToken.includes(:user).order(:id).map do |t|
          { id: t.id, user: t.user.email, name: t.name, last_used: t.last_used_at&.iso8601, revoked: t.revoked? }
        end)
      when "revoke"
        APIToken.find(rest.first).revoke!
        @out.puts("Token #{rest.first} revoked")
      else
        raise Usage, "bin/usput tokens issue EMAIL NAME | tokens list | tokens revoke ID"
      end
      0
    end

    def help(name)
      command = Commands.find(name) if name.present?
      return help_for(command) if command

      @out.puts("Usage: bin/usput COMMAND [VALUE] [key=value ...] [--as EMAIL] [--json] [--locale bs]\n\n")
      Commands.all.each do |each|
        @out.puts(format("  %-20s %s%s", each.command_name.tr(".", " "), each.summary,
                         each.reads? ? "" : " [decides]"))
      end
      @out.puts("\n  mcp                  The MCP server over stdio, acting as --as")
      @out.puts("  tokens               issue, list and revoke tokens for the MCP server over HTTP")
      0
    end

    def help_for(command)
      @out.puts("#{command.command_name.tr('.', ' ')}: #{command.summary}")
      command.params.each do |param|
        flags = [ param.required ? "required" : nil, param.default.nil? ? nil : "default #{param.default}",
                  param.enum&.join("|") ].compact.join(", ")
        @out.puts(format("  %-12s %-8s %s%s", param.name, param.type, param.description, flags.empty? ? "" : " (#{flags})"))
      end
      0
    end

    def print_result(result)
      return @out.puts(JSON.pretty_generate(result)) if @json

      case result
      when Array then print_table(result)
      when Hash then result.each { |key, value| @out.puts("#{key}: #{value.is_a?(String) ? value : value.to_json}") }
      else @out.puts(result.to_s)
      end
    end

    def print_table(rows)
      return @out.puts("(none)") if rows.empty?

      columns = rows.flat_map(&:keys).uniq
      cells = rows.map { |row| columns.map { |column| cell(row[column]) } }
      widths = columns.each_with_index.map { |column, i| ([ column.to_s ] + cells.map { |c| c[i] }).map(&:length).max }
      @out.puts(columns.each_with_index.map { |column, i| column.to_s.ljust(widths[i]) }.join("  ").rstrip)
      cells.each { |row| @out.puts(row.each_with_index.map { |c, i| c.ljust(widths[i]) }.join("  ").rstrip) }
    end

    def cell(value)
      text = value.is_a?(String) || value.nil? ? value.to_s : value.to_json
      text = text.tr("\n", " ")
      text.length > 48 ? "#{text[0, 47]}…" : text
    end

    def take_option(flag)
      index = @argv.index(flag) or return nil
      @argv.delete_at(index)
      @argv.delete_at(index) || raise(Usage, "#{flag} needs a value")
    end
  end
end
