# frozen_string_literal: true

module Usput
  # One thing usput can be asked to do from outside a page: a terminal
  # (bin/usput) or an agent (the MCP server). Both are thin doors onto these
  # objects, so a rule is written once (wiki/initiatives/cli-and-mcp.md).
  #
  # A command names itself, declares its parameters, says whether it only
  # reads or also decides, and asks the actor's policy before acting. It
  # returns plain hashes and arrays, ready for JSON or a table.
  class Command
    Param = Data.define(:name, :type, :description, :required, :default, :enum)

    # The actor's policy says no.
    class Denied < StandardError; end
    # The arguments do not make a request this command can answer.
    class Invalid < StandardError; end

    TYPES = { string: "string", integer: "integer", boolean: "boolean" }.freeze

    class << self
      attr_reader :command_name, :summary, :effect

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@params, [])
      end

      # effect is :reads or :decides; deciding commands are never offered over HTTP.
      def named(name, summary, effect: :reads)
        @command_name = name
        @summary = summary
        @effect = effect
      end

      def param(name, type, description, required: false, default: nil, enum: nil)
        @params << Param.new(name:, type:, description:, required:, default:, enum:)
      end

      def params = @params

      def reads? = effect == :reads

      def call(actor:, **args)
        new(actor, args).call
      end

      # The MCP tool name: places.list becomes places_list.
      def tool_name = command_name.tr(".", "_")

      def input_schema
        properties = params.to_h do |param|
          [ param.name.to_s, { type: TYPES.fetch(param.type), description: param.description, enum: param.enum }.compact ]
        end
        { properties:, required: params.select(&:required).map { |param| param.name.to_s } }
      end
    end

    attr_reader :actor

    def initialize(actor, args)
      @actor = actor
      @args = coerce(args.transform_keys(&:to_sym))
    end

    private

    def arg(name) = @args[name]

    def allow!(permitted)
      raise Denied, "#{self.class.command_name} is not allowed for #{actor&.username || 'an anonymous caller'}" unless permitted
    end

    def curator? = actor&.can_curate? || false

    def limit = arg(:limit).clamp(1, 100)

    def coerce(args)
      unknown = args.keys - self.class.params.map(&:name)
      raise Invalid, "unknown parameter #{unknown.join(', ')}" if unknown.any?

      self.class.params.to_h do |param|
        value = args.fetch(param.name, param.default)
        raise Invalid, "#{param.name} is required" if param.required && value.to_s.strip.empty?

        value = cast(param, value) unless value.nil?
        raise Invalid, "#{param.name} must be one of #{param.enum.join(', ')}" if param.enum && value && !param.enum.include?(value)

        [ param.name, value ]
      end
    end

    def cast(param, value)
      case param.type
      when :integer then Integer(value)
      when :boolean then ActiveModel::Type::Boolean.new.cast(value)
      else value.to_s.strip.presence
      end
    rescue ArgumentError, TypeError
      raise Invalid, "#{param.name} must be #{TYPES.fetch(param.type)}"
    end

    # Finds by the public uuid every usput url uses, or says what was missing.
    def find!(scope, id, label)
      scope.find_by_public_id(id.to_s) || raise(ActiveRecord::RecordNotFound, "no #{label} #{id}")
    end
  end
end
