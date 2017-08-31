# frozen_string_literal: true

module NexosisApi
  # class to hold a join defintion initialized by a hash of join values
  class Join
    def initialize(join_hash)
      join_hash.each do |k, v|
        if k == 'dataSet'
          @join_target = NexosisApi::DatasetJoinTarget.new(v)
        elsif k == 'calendar'
          @join_target = NexosisApi::CalendarJoinTarget.new(v)
        elsif k == 'columnOptions'
          @column_options = v unless v.nil?
        elsif k == 'joins'
          joins = []
          next if v.nil?
          v.each do |join|
            joins << NexosisApi::Join.new(join)
            @joins = joins
          end
        end
      end
    end

    # The details of the data source that will be participating in the join
    # @return [Object] details of the join target
    attr_accessor :join_target

    # The optional column definition for the join which
    # defines how columns should be used from the joined dataset
    # @return [Array of NexosisApi::ColumnOptions] column options definition
    attr_accessor :column_options

    # Optional additional data source to be joined to this data source
    # @return [Array of NexosisApi::Join] zero or more additional joins
    attr_accessor :joins

    def to_hash
      hash = @join_target.to_hash
      if column_options.nil? == false
        hash['columns'] = {}
        column_options.each do |column|
          hash['columns'].merge!(column.to_hash)
        end
      end
      if joins.nil? == false
        hash['joins'] = []
        joins.each do |join|
          hash['joins'] << join.to_hash
        end
      end
      hash
    end

    def to_json
      to_hash.to_json
    end
  end
end
