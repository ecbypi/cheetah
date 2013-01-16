require 'curb'
require 'cgi'

module Cheetah
  class Messenger

    attr_reader :options, :cookie, :default_params

    def initialize(options)
      @credentials = {
        name: options.delete(:username),
        cleartext: options.delete(:password)
      }.freeze

      @default_params = { aid: options.delete(:aid) }
      @default_params['test'] = '1' if options[:disable_tracking]
      @default_params.freeze

      @options = options.dup
    end

    # determines if and how to send based on options
    # returns true if the message was sent
    # false if it was suppressed
    def send_message(path, params)
      params.merge!(default_params)

      login if cookie.nil?

      begin
        post_request(path, params)
      rescue CheetahAuthorizationException
        login
        retry
      end
    end

    private

    # sets the instance @cookie variable
    def login
      curl = post_request('/api/login1', @credentials)

      @cookie = extract_auth_cookie(curl.header_str)
    rescue CheetahAuthorizationException
      # this is a permanent exception, it should not be retried
      raise CheetahPermanentException, "authorization exception while logging in"
    end

    # Handles posting to Cheetahmail
    def post_request(path, params)
      curl                   = Curl::Easy.new("https://#{options[:host]}#{path}")
      curl.ssl_verify_peer   = options[:verify_peer]
      curl.connect_timeout   = 5
      curl.headers['Cookie'] = @cookie

      body = params.map { |key, value| "#{key}=#{CGI.escape(value)}" }

      curl.http_post(body)

      response_code = curl.response_code.to_s
      response_body = curl.body_str

      case response_code
      when /5../
        raise CheetahTemporaryException, "failure:'#{path}?#{body}', HTTP error: #{response_code}"
      when /[^2]../
        raise CheetahPermanentException, "failure:'#{path}?#{body}', HTTP error: #{response_code}"
      end

      case response_body
      when /^err:auth/
        raise CheetahAuthorizationException, "failure:'#{path}?#{body}', Cheetah error: #{response_body.strip}"
      when /^err:internal error/
        raise CheetahTemporaryException, "failure:'#{path}?#{body}', Cheetah error: #{response_body.strip}"
      when /^err/
        raise CheetahPermanentException, "failure:'#{path}?#{body}', Cheetah error: #{response_body.strip}"
      end

      curl
    end

    def extract_auth_cookie(header_str)
      headers = header_str.split(/\r\n/)
      # Remove line containing status
      headers.delete_at(0)

      headers = Hash[headers.map { |header| header.split(/: /) }]

      # FIXME: This is an odd coupling with Webmock that will auto-capitalize
      # the headers set when stubbing requests. The Cheetahmail API returns a
      # 'set-cookie' header, not 'Set-Cookie'.
      headers['set-cookie'] || headers['Set-Cookie']
    end
  end
end
