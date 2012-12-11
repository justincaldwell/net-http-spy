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
      defaults =  {:body => false, :trace => false, :limit => -1, :blacklist_terms => []}
      self.class.http_logger_options = (self.class.http_logger_options == :default) ? defaults : self.class.http_logger_options
      @logger_options = defaults.merge(self.class.http_logger_options)
      @params_limit = @logger_options[:params_limit] || @logger_options[:limit]
      @body_limit   = @logger_options[:body_limit]   || @logger_options[:limit]
      @ignore = !@logger_options[:blacklist_terms].detect {|term| /#{term}/ =~ args[0] }.nil?

      self.class.http_logger.info "CONNECT: #{args.inspect}" unless @ignore

      old_initialize(*args, &block)
      @debug_output   = self.class.http_logger unless @ignore
    end


    def request(*args, &block)
      @ignore =  true if !@logger_options[:blacklist_terms].detect {|term| /#{term}/ =~ args[0].path }.nil?
      unless started? || @ignore
        req = args[0].method
        self.class.http_logger.info "#{req} #{args[0].path}"
      end

      time_started = Time.now
      result = old_request(*args, &block)
      time_taken = Time.now - time_started
      unless started? || @ignore

        self.class.http_logger.info "PARAMS #{CGI.parse(args[0].body).inspect[0..@params_limit]} " if args[0].body && req != 'CONNECT'
        self.class.http_logger.info "TRACE: #{caller.reverse}" if @logger_options[:trace]
        self.class.http_logger.info "BODY: #{(@logger_options[:body] ? result.body : result.class.name)[0..@body_limit]}"
        self.class.http_logger.info "TIME: #{(time_taken.to_f*1000).round}ms"
      end
      result
    end


  end

end

Net::HTTP.http_logger = Logger.new(STDOUT)
