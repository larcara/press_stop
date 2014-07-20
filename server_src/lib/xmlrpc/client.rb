require 'xmlrpc/client'
#1.9.3
module XMLRPC
  class Client
    def do_rpc(request, async=false)
      if RUBY_VERSION=="1.9.3" 
        return do_rpc_ruby_19(request, async)
      else
        return do_rpc_ruby_22(request, async)
      end
    end
    def do_rpc_ruby_22(request, async=false)
      header = {
       "User-Agent"     =>  USER_AGENT,
       "Content-Type"   => "text/xml; charset=utf-8",
       "Content-Length" => request.bytesize.to_s,
       "Connection"     => (async ? "close" : "keep-alive")
      }

      header["Cookie"] = @cookie        if @cookie
      header.update(@http_header_extra) if @http_header_extra

      if @auth != nil
        # add authorization header
        header["Authorization"] = @auth
      end

      resp = nil
      @http_last_response = nil

      if async
        # use a new HTTP object for each call
        http = net_http(@host, @port, @proxy_host, @proxy_port)
        http.use_ssl = @use_ssl if @use_ssl
        http.read_timeout = @timeout
        http.open_timeout = @timeout

        # post request
        http.start {
          resp = http.request_post(@path, request, header)
        }
      else
        # reuse the HTTP object for each call => connection alive is possible
        # we must start connection explicitly first time so that http.request
        # does not assume that we don't want keepalive
        @http.start if not @http.started?

        # post request
        resp = @http.request_post(@path, request, header)
      end

      @http_last_response = resp

      data = resp.body

      if resp.code == "401"
        # Authorization Required
        raise "Authorization failed.\nHTTP-Error: #{resp.code} #{resp.message}"
      elsif resp.code[0,1] != "2"
        raise "HTTP-Error: #{resp.code} #{resp.message}"
      end

      # assume text/xml on instances where Content-Type header is not set
      ct_expected = resp["Content-Type"] || 'text/xml'
      ct = parse_content_type(ct_expected).first
      if ct != "text/xml" && ct != "application/xml" # Force the client to work with application/xml responses
        if ct == "text/html"
          raise "Wrong content-type (received '#{ct}' but expected 'text/xml'): \n#{data}"
        else
          raise "Wrong content-type (received '#{ct}' but expected 'text/xml')"
        end
      end

      expected = resp["Content-Length"] || "<unknown>"
      if data.nil? or data.bytesize == 0
        raise "Wrong size. Was #{data.bytesize}, should be #{expected}"
      end

      parse_set_cookies(resp.get_fields("Set-Cookie"))

      return data
    end


# File lib/xmlrpc/client.rb, line 500
    def do_rpc_ruby_19(request, async=false)
      header = {
       "User-Agent"     =>  USER_AGENT,
       "Content-Type"   => "text/xml; charset=utf-8",
       "Content-Length" => request.bytesize.to_s,
       "Connection"     => (async ? "close" : "keep-alive")
      }

      header["Cookie"] = @cookie        if @cookie
      header.update(@http_header_extra) if @http_header_extra

      if @auth != nil
        # add authorization header
        header["Authorization"] = @auth
      end

      resp = nil
      @http_last_response = nil

      if async
        # use a new HTTP object for each call
        Net::HTTP.version_1_2
        http = Net::HTTP.new(@host, @port, @proxy_host, @proxy_port)
        http.use_ssl = @use_ssl if @use_ssl
        http.read_timeout = @timeout
        http.open_timeout = @timeout

        # post request
        http.start {
          resp = http.post2(@path, request, header)
        }
      else
        # reuse the HTTP object for each call => connection alive is possible
        # we must start connection explicitely first time so that http.request
        # does not assume that we don't want keepalive
        @http.start if not @http.started?

        # post request
        resp = @http.post2(@path, request, header)
      end

      @http_last_response = resp

      data = resp.body

      if resp.code == "401"
        # Authorization Required
        raise "Authorization failed.\nHTTP-Error: #{resp.code} #{resp.message}"
      elsif resp.code[0,1] != "2"
        raise "HTTP-Error: #{resp.code} #{resp.message}"
      end

      ct = parse_content_type(resp["Content-Type"]).first
	  
      if ct != "text/xml" && ct != "application/xml"
        if ct == "text/html"  # Force the client to work with application/xml responses
          raise "Wrong content-type (received '#{ct}' but expected 'text/xml'): \n#{data}"
        else
          raise "Wrong content-type (received '#{ct}' but expected 'text/xml')"
        end
      end

      expected = resp["Content-Length"] || "<unknown>"
      if data.nil? or data.bytesize == 0
        raise "Wrong size. Was #{data.bytesize}, should be #{expected}"
      elsif expected != "<unknown>" and expected.to_i != data.bytesize and resp["Transfer-Encoding"].nil?
        raise "Wrong size. Was #{data.bytesize}, should be #{expected}"
      end

      set_cookies = resp.get_fields("Set-Cookie")
      if set_cookies and !set_cookies.empty?
        require 'webrick/cookie'
        @cookie = set_cookies.collect do |set_cookie|
          cookie = WEBrick::Cookie.parse_set_cookie(set_cookie)
          WEBrick::Cookie.new(cookie.name, cookie.value).to_s
        end.join("; ")
      end

      return data
    end
  end
end