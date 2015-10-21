class Evil::Client
  # Коллекция нескольких удаленных API
  #
  # Сейчас это "пустая" обертка вокруг единственного API.
  #
  #     apis = APIs.new(API.new base_url: "127.0.0.1/v1")
  #
  # Или сокращенно:
  #
  #     apis = APIs.with base_url: "127.0.0.1/v1"
  #
  # Привязка адреса к `base_url` выполняется в единственном хранилище.
  #
  #     APIs.url "/users/1/sms" # => "127.0.0.1/v1/users/1/sms"
  #
  # В дальнейшем коллекция позволит хранить несколько API, среди которых будет
  # выполняться поиск подходящего адреса и привязка к base_url.
  # В случае ошибки коллекция будет выбрасывает исключение.
  #
  #    APIs.url "/unknown" # => #<Evil::Client::URLError ...>
  #
  # @api private
  #
  # @author nepalez <nepalez@evilmartians.com>
  #
  class APIs
    include Enumerable, Errors

    # @!scope class
    # @!method with(options)
    # Формирует коллекцию из единственного API с заданными параметрами
    #
    # @param [Hash] options
    # @option options [String] :base_url
    #
    # @return [Evil::Client::APIs]
    #
    def self.with(base_url:)
      new API.new(base_url: base_url)
    end

    # Инициализирует коллекцию набором <спецификаций к> API
    #
    # @param [Array<Evil::Client::API>] apis
    #
    def initialize(*apis)
      @apis = apis
    end

    # Выполняет итерации по <спецификациям к> API
    #
    # @return [Enumerator<Evil::Client::API>]
    #
    def each
      block_given? ? @apis.each { |api| yield(api) } : to_enum
    end

    # Преобразует сформированный адрес в полный url <одного из объявленных> API
    #
    # @param [String] address
    #
    # @return [String]
    #
    # @raise [Evil::Client::Errors::ULRError]
    #   если сформированный адрес не распознан <ни одним из объявленныx> API
    #
    def url(address)
      result = map { |api| api.url(address) }.first
      result || fail(URLError.new address)
    end
  end # class APIs
end # class Evil::Client