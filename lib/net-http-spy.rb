require 'net/https'
require 'logger'
require 'cgi'

# HTTP SPY
module Net
  class HTTP
    alias :old_initialize :initialize
    alias :old_request :request

    class << self
      attr_accessor :http_logger
      attr_accessor :http_logger_options
    end

    def initialize(*args, &block)
      self.class.http_logger_options ||= {}
      defaults =  {:body => false, :trace => false, :limit => -1, :blacklist_terms => [], :debug => false}
      self.class.http_logger_options = (self.class.http_logger_options == :default) ? defaults : self.class.http_logger_options
      @logger_options = defaults.merge(self.class.http_logger_options)
      @params_limit = @logger_options[:params_limit] || @logger_options[:limit]
      @body_limit   = @logger_options[:body_limit]   || @logger_options[:limit]

      old_initialize(*args, &block)

      @debug_output = self.class.http_logger if @logger_options[:debug]
    end


    def request(*args, &block)
      full_path = @address + args[0].path
      ignore = !@logger_options[:blacklist_terms].detect {|term| /#{term}/ =~ full_path }.nil?

      if started? || ignore || @logger_options[:debug]
        result = old_request(*args, &block)
      else
        log("CONNECT", [@address, @port].inspect)
        req = args[0].method
        log(req, args[0].path)
        log(req, full_path)

        time_started = Time.now
        result = old_request(*args, &block)
        time_taken = Time.now - time_started

        log("PARAMS", CGI.parse(args[0].body).inspect[0..@params_limit]) if args[0].body
        log("TRACE",  caller.reverse) if @logger_options[:trace]
        log("BODY",   (@logger_options[:body] ? result.body : result.class.name)[0..@body_limit])
        log("TIME",   (time_taken.to_f*1000).round.to_s + 'ms')
      end
      result
    end

    def log(head, message)
      self.class.http_logger.info("#{Time.now.to_s} #{head}: #{message}") 
    end

  end

end

Net::HTTP.http_logger = Logger.new(STDOUT)
