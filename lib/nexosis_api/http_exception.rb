module NexosisApi
  # encapsulate errors from the Nexosis API
  class HttpException < StandardError
      attr_reader :message,:action,:response,:request
      def initialize(message = "", action = nil, http_obj)
        @message = message
        if(http_obj.is_a?(Hash))
          @message.prepend(http_obj["message"].concat(": ")) unless http_obj["message"].nil?
          @action = action
        elsif(http_obj.instance_of?(HTTParty::Response))
          @message = message.concat("|| Explanation: ").concat(http_obj.parsed_response["errorDetails"].to_s) unless http_obj.parsed_response["errorDetails"].nil?
          @type = http_obj.parsed_response["errorType"]
          @response = http_obj.response
          @request = http_obj.request
          @code = http_obj.code
        end
      end

      attr_reader :code
      attr_reader :response
      attr_reader :request
      attr_reader :message
      attr_reader :type      
  end
end