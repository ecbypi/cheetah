require 'curb'
require 'cgi'

module Cheetah
  class Messenger

    def initialize(options)
      @options  = options
      @cookie   = nil
    end

    # determines if and how to send based on options
    # returns true if the message was sent
    # false if it was suppressed
    def send_message(message)
      if !@options[:whitelist_filter] or message.params['email'] =~ @options[:whitelist_filter]
        message.params['test'] = "1" unless @options[:enable_tracking]
        do_send(message) # implemented by the subclass
        true
      else
        false
      end
    end

    # handles sending the request and processing any exceptions
    def do_request(message)
      begin
        login unless @cookie
        initheader = {'Cookie' => @cookie || ''}
        message.params['aid'] = @options[:aid]
        do_post(message.path, message.params, initheader)
      rescue CheetahAuthorizationException
        # it may be that the cookie is stale. clear it and immediately retry. 
        # if it hits another authorization exception in the login function then it will come back as a permanent exception
        @cookie = nil
        retry
      end
    end

    private #####################################################################

    # actually sends the request and raises any exceptions
    def do_post(path, params, initheader = {})
      data = params.map { |a| "#{a[0]}=#{CGI.escape(a[1])}" }

      http                 = Curl::Easy.new("https://#{@options[:host]}#{path}")
      http.ssl_verify_peer = false
      http.connect_timeout = 5
      http.headers         = initheader

      http.http_post(data)

      response_code = http.response_code.to_s
      response_body = http.body_str

      case response_code
      when /5../
        raise CheetahTemporaryException, "failure:'#{path}?#{data}', HTTP error: #{response_code}"
      when /[^2]../
        raise CheetahPermanentException, "failure:'#{path}?#{data}', HTTP error: #{response_code}"
      end

      case response_body
      when /^err:auth/
        raise CheetahAuthorizationException, "failure:'#{path}?#{data}', Cheetah error: #{response_body.strip}"
      when /^err:internal error/
        raise CheetahTemporaryException, "failure:'#{path}?#{data}', Cheetah error: #{response_body.strip}"
      when /^err/
        raise CheetahPermanentException, "failure:'#{path}?#{data}', Cheetah error: #{response_body.strip}"
      end

      http
    end

    # sets the instance @cookie variable
    def login
      begin
        path = "/api/login1"
        params              = {}
        params['name']      = @options[:username]
        params['cleartext'] = @options[:password]
        http = do_post(path, params)

        @cookie = extract_auth_cookie(http.header_str)
      rescue CheetahAuthorizationException
        # this is a permanent exception, it should not be retried
        raise CheetahPermanentException, "authorization exception while logging in"
      end
    end

    def extract_auth_cookie(header_str)
      headers = header_str.split(/\r\n/)
      # Remove line containing status
      headers.delete_at(0)

      headers = Hash[headers.map { |header| header.split(/: /) }]

      headers['set-cookie'] || headers['Set-Cookie']
    end

  end
end
