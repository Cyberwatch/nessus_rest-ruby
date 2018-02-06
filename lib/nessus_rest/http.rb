# frozen_string_literal: true

module NessusREST
  # HttpClient to do the interface with Net::HTTP
  class Http
    attr_accessor :options

    def initialize(params = {})
      @options = {
        url: 'https://127.0.0.1:8834/',
        ssl_verify: false,
        ssl_use: true,
        http_retry: 3,
        http_sleep: 1
      }.merge(params)

      uri = URI.parse(options[:url])
      @connection = Net::HTTP.new(uri.host, uri.port)
      @connection.use_ssl = options[:ssl_use]
      @connection.verify_mode = options[:ssl_verify] ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      @connection.read_timeout = options[:read_timeout] || @connection.read_timeout
    end

    def request(req)
      @connection.request(req)
    end

    def http_get_low(opts = {})
      uri    = opts[:uri]
      fields = opts[:fields] || {}
      raw_content = opts[:raw_content] || false
      tries = options[:http_retry]

      req = Net::HTTP::Get.new(uri)
      fields.each_pair do |name, value|
        req.add_field(name, value)
      end

      begin
        tries -= 1
        res = @connection.request(req)
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
        return {} unless tries.positive?

        sleep options[:http_sleep]
        retry
      rescue URI::InvalidURIError
        return {}
      end

      if !raw_content
        parse_json(res.body)
      else
        res.body
      end
    end

    def http_post_low(opts = {})
      uri    = opts[:uri]
      data   = opts[:data]
      fields = opts[:fields] || {}
      body   = opts[:body]
      ctype  = opts[:ctype]
      tries  = options[:http_retry]

      req = Net::HTTP::Post.new(uri)
      req.set_form_data(data) unless data.nil? || data.empty?
      req.body = body unless body.nil? || body.empty?
      req['Content-Type'] = ctype unless ctype.nil? || ctype.empty?
      fields.each_pair do |name, value|
        req.add_field(name, value)
      end

      begin
        tries -= 1
        res = @connection.request(req)
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
        return {} unless tries.positive?

        sleep options[:http_sleep]
        retry
      rescue URI::InvalidURIError
        return {}
      end

      parse_json(res.body)
    end

    def http_put_low(opts = {})
      uri    = opts[:uri]
      data   = opts[:data]
      fields = opts[:fields] || {}
      res    = nil
      tries  = options[:http_retry]

      req = Net::HTTP::Put.new(uri)
      req.set_form_data(data) unless data.nil? || data.empty?
      fields.each_pair do |name, value|
        req.add_field(name, value)
      end

      begin
        tries -= 1
        res = @connection.request(req)
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
        if tries.positive?
          sleep options[:http_sleep]
          retry
        end
      rescue URI::InvalidURIError
        nil
      end

      res
    end

    def http_delete_low(opts = {})
      uri    = opts[:uri]
      fields = opts[:fields] || {}
      res    = nil
      tries  = options[:http_retry]

      req = Net::HTTP::Delete.new(uri)

      fields.each_pair do |name, value|
        req.add_field(name, value)
      end

      begin
        tries -= 1
        res = @connection.request(req)
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
        if tries.positive?
          sleep options[:http_sleep]
          retry
        end
      rescue URI::InvalidURIError
        nil
      end

      res
    end

    # Perform JSON parsing of body
    #
    # returns: JSON parsed object (if JSON parseable)
    #
    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end
  end
end
