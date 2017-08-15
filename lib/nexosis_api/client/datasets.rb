require 'csv'

module NexosisApi
  class Client
    # Dataset-based API operations
    #
    # @see http://docs.nexosis.com/
    module Datasets
      # save data in a named dataset
      #
      # @param dataset_name [String] name to save the dataset
      # @param json_data [Hash] parsed json data
      # @return [NexosisApi::DatasetSummary] information about your upload
      # @note input json is to be a hash, do not send a json string via to_json.
      def create_dataset_json(dataset_name, json_data)
        create_dataset dataset_name, json_data.to_json, 'application/json'
      end

      # save data in a named dataset from csv content
      #
      # @param dataset_name [String] name to save the dataset
      # @param csv [CSV] csv content ready for reading
      # @return [NexosisApi::DatasetSummary] information about your upload
      def create_dataset_csv(dataset_name, csv)
        content = process_csv_to_s csv
        create_dataset dataset_name, content, 'text/csv'
      end

      # Gets the list of data sets that have been saved to the system, optionally filtering by partial name match.
      #
      # @param partial_name [String] if provided, all datasets returned will contain this string
      # @return [Array of NexosisApi::DatasetSummary] array of datasets found
      def list_datasets(partial_name = '')
        list_dataset_url = "/data?partialName=#{partial_name}"
        response = self.class.get(list_dataset_url, headers: @headers)
        if response.success?
          results = []
          response.parsed_response['items'].each do |dr|
            results << NexosisApi::DatasetSummary.new(dr)
          end
          results
        else
          raise HttpException.new("There was a problem listing datasets: #{response.code}.", "listing datasets with partial name #{partial_name}", response)
        end
      end

      # Get the data in the set, with paging, and optional projection.
      #
      # @param dataset_name [String] name of the dataset for which to retrieve data.
      # @param page_number [Integer] zero-based page number of results to retrieve
      # @param page_size [Integer] Count of results to retrieve in each page (max 1000).
      # @param query_options [Hash] options hash for limiting and projecting returned results
      # @note Query Options includes start_date as a DateTime or ISO 8601 compliant string,
      #    end_date, also as a DateTime or string, and :include as an Array of strings indicating the columns to return.
      #    The dates can be used independently and are inclusive. Lack of options returns all values within the given page.
      def get_dataset(dataset_name, page_number = 0, page_size = 50, query_options = {})
        response = get_dataset_internal(dataset_name, page_number, page_size, query_options)
        if response.success?
          NexosisApi::DatasetData.new(response.parsed_response)
        else
          raise HttpException.new("There was a problem getting the dataset: #{response.code}.", "getting dataset #{dataset_name}", response)
        end
      end

      # Get the data in the set, written to a CSV file, optionally filtering it.
      #
      # @param dataset_name [String] name of the dataset for which to retrieve data.
      # @param page_number [Integer] zero-based page number of results to retrieve
      # @param page_size [Integer] Count of results to retrieve in each page (max 1000).
      # @param query_options [Hash] options hash for limiting and projecting returned results
      # @note Query Options includes start_date as a DateTime or ISO 8601 compliant string,
      #    end_date, also as a DateTime or string, and :include as an Array of strings indicating the columns to return.
      #    The dates can be used independently and are inclusive. Lack of options returns all values within the given page.
      # @example get page 1 with 20 results each page
      #    NexosisApi.client.get_dataset_csv('MyDataset', 1, 20, {:include => 'sales'})
      def get_dataset_csv(dataset_name, page_number = 0, page_size = 50, query_options = {})
        response = get_dataset_internal(dataset_name, page_number, page_size, query_options, 'text/csv')
        if response.success?
          response.body
        else
          raise HttpException.new("There was a problem getting the dataset: #{response.code}.", "getting dataset #{dataset_name}", response)
        end
      end

      # Remove data from a data set or the entire set.
      #
      # @param dataset_name [String] the name of the dataset from which to remove data
      # @param filter_options [Hash] filtering which data to remove
      # @note Options: start_date, end_date, cascade_forecast, cascade_sessions, cascade
      #    - start_date - the first date on which to start removing data
      #    - end_date - the last date on which to finish removing data
      #    - cascade_forecast - will cascade deletes to all related forecasts
      #    - cascade_session - will cascade deletes to all related sessions
      #    - cascade_view - will cascade deletes to all related views (any part of join - think twice)
      #    - cascade - will cascade deletes to all related forecasts and sessions
      # @example - request delete with cascade forecast
      #    NexosisApi.client.remove_dataset('mydataset', {:cascade_forecast => true})
      def remove_dataset(dataset_name, filter_options = {})
        raise ArgumentError 'dataset_name was not provided and is not optional ' if dataset_name.to_s.empty?
        dataset_remove_url = "/data/#{dataset_name}"
        query = {}
        if filter_options.empty? == false
          cascade_query = create_cascade_options(filter_options)
          query['cascade'] = cascade_query unless cascade_query.nil?
          query['startDate'] = [filter_options[:start_date].to_s] unless filter_options[:start_date].nil?
          query['endDate'] = [filter_options[:end_date].to_s] unless filter_options[:end_date].nil?
        end
        normalizer = proc { |query_set| query_set.map { |key, value| value.map { |v| "#{key}=#{v}" } }.join('&') }
        response = self.class.delete(dataset_remove_url,
                                     headers: @headers,
                                     query: query,
                                     query_string_normalizer: normalizer)
        if response.success?
          return
        else
          raise HttpException.new("There was a problem removing the dataset: #{response.code}.", "removing dataset #{dataset_name}", response)
        end
      end

      private

      # @private
      def create_dataset(dataset_name, content, content_type)
        raise ArgumentError 'dataset_name was not provided and is not optional ' if dataset_name.to_s.empty?
        dataset_url = "/data/#{dataset_name}"
        headers = { 'api-key' => @api_key, 'Content-Type' => content_type }
        response = self.class.put(dataset_url, headers: headers, body: content)
        if response.success?
          NexosisApi::DatasetSummary.new(response)
        else
          raise HttpException.new("There was a problem uploading the dataset: #{response.code}.", "uploading dataset #{dataset_name}", response)
        end
      end

      # @private
      def get_dataset_internal(dataset_name, page_number = 0, page_size = 50, query_options = {}, content_type = 'application/json')
        raise ArgumentError 'page size must be <= 100 items per page' unless page_size <= 100
        raise ArgumentError 'dataset_name was not provided and is not optional' unless dataset_name.to_s.empty? == false
        dataset_url = "/data/#{dataset_name}"
        headers = { 'api-key' => @api_key, 'Accept' => content_type }
        self.class.get(dataset_url, headers: headers, query: create_query(page_number, page_size, query_options))
      end

      # @private
      def create_query(page_number, page_size, options = {})
        options.store(:page_number, page_number)
        options.store(:page_size, page_size)
        query = {
          'startDate' => options[:start_date].to_s,
          'endDate' => options[:end_date].to_s,
          'page' => options[:page_number],
          'pageSize' => options[:page_size],
          'include' => options[:include]
        }
        query
      end

      # @private
      def create_cascade_options(option_hash)
        return nil if option_hash.nil?
        return %w[session view forecast] if option_hash.key?(:cascade)
        options_set = []
        option_hash.each_key { |k| options_set << k.to_s.gsub(/cascade_/, '') if k.to_s.include? 'cascade_' }
        # HACK: required to be backward compatible with incorrect key names
        options_set.map { |s| s.chomp('s') }
      end
    end
  end
end
