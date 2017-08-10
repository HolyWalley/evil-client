class Evil::Client
  #
  # Container for settings assigned to some operation or scope.
  #
  class Settings
    Names.clean(self) # Remove unnecessary methods from the instance
    require_relative "settings/validator"
    extend ::Dry::Initializer

    class << self
      # The schema klass settings belongs to
      #
      # @return [Class]
      #
      attr_reader :schema

      # Only options can be defined for the settings container
      # @private
      def param(*args)
        option(*args)
      end

      # Creates or updates the settings' initializer
      #
      # @see [http://dry-rb.org/gems/dry-initializer]
      #
      # @param       [#to_sym] key       Symbolic name of the option
      # @param       [#call]   type      Type coercer for the option
      # @option opts [#call]   :type     Another way to assign type coercer
      # @option opts [#call]   :default  Proc containing default value
      # @option opts [Boolean] :optional Whether it can be missed
      # @option opts [#to_sym] :as       The name of settings variable
      # @option opts [false, :private, :protected] :reader Reader method type
      # @return      [self]
      #
      def option(key, type = nil, as: key.to_sym, **opts)
        NameError.check!(as)
        super
        self
      end

      # Creates or reloads memoized attribute
      #
      # @param [#to_sym] key The name of the attribute
      # @param [Proc] block  The body of new attribute
      # @return [self]
      #
      def let(key, &block)
        NameError.check!(key)
        define_method(key) do
          instance_variable_get(:"@#{key}") ||
            instance_variable_set(:"@#{key}", instance_exec(&block))
        end
        self
      end

      # Define validator for the attribute
      #
      # @param [#to_sym] key The name of the attribute
      # @param [Proc] block  The body of new attribute
      # @return [self]
      #
      def validate(key, &block)
        validators[key] = Validator.new(@schema, key, &block)
        self
      end

      # Collection of validators to check initialized settings
      #
      # @return [Hash<Symbol, Evil::Client::Validator>]
      #
      def validators
        @validators ||= {}
      end

      # Human-friendly representation of settings class
      #
      # @return [String]
      #
      def name
        super || @schema.to_s
      end
      alias_method :to_s,    :name
      alias_method :to_str,  :name
      alias_method :inspect, :name

      # Builds settings with options
      #
      # @param  [Logger, nil] logger
      # @param  [Hash<#to_sym, Object>, nil] opts
      # @return [Evil::Client::Settings]
      #
      def new(logger, opts = {})
        logger&.debug(self) { "initializing with options #{opts}..." }
        opts = Hash(opts).each_with_object({}) { |(k, v), o| o[k.to_sym] = v }
        super logger, opts
      rescue => error
        raise ValidationError, error.message
      end
    end

    # The processed hash of options contained by the instance of settings
    #
    # @return [Hash<Symbol, Object>]
    #
    def options
      Options.new @__options__
    end

    # @!attribute logger
    # @return [Logger, nil] The logger attached to current settings
    attr_accessor :logger

    # DSL helper to format datetimes following RFC7231/RFC2822
    #
    # @see https://tools.ietf.org/html/rfc7231#section-7.1.1.1
    #
    # @param  [Date, String, nil] value Value to be formatted
    # @return [String, nil]
    #
    def datetime(value)
      return unless value

      value = DateTime.parse(value) if value.is_a? String
      value = value.to_datetime     if value.respond_to? :to_datetime
      raise "Cannot convert #{value} to DateTime" unless value.is_a?(DateTime)

      value.rfc2822
    end

    # Human-readable representation of settings instance
    #
    # @return [String]
    #
    def inspect
      number = super.match(/\>\:([^ ]+) /)[1]
      params = options.map { |k, v| "@#{k}=#{v}" }.join(", ")
      number ? "#<#{self.class}:#{number} #{params}>" : super
    end
    alias_method :to_str, :inspect
    alias_method :to_s,   :inspect

    private

    def initialize(logger, **options)
      @logger = logger
      super(options)

      logger&.debug(self) { "initialized" }
      __validate__!
    end

    def __validate__!
      __validators__.reverse.each { |validator| validator.call(self) }
    end

    def __validators__
      klass = self.class
      [].tap do |list|
        loop do
          list.concat klass.validators.values
          klass = klass.superclass
          break if klass == Evil::Client::Settings
        end
      end
    end
  end
end
