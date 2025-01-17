# frozen_string_literal: true

require "active_support/concern"

module EasyParams
  extend ActiveSupport::Concern

  included do
    # Define a class-level attribute to store parameter validation classes
    class_attribute :_param_validations, default: {}
  end

  class_methods do
    # DSL to define validations for a specific action
    def validates_params(action_name, &block)
      # Dynamically generate a validator class
      validator_class = Class.new do
        include ActiveModel::Model
        include ActiveModel::Attributes

        # Define attributes and validations
        instance_eval(&block)

        # Initialize and filter parameters
        def initialize(params = {})
          permitted_params = self.class.filter_nested_attributes(params)
          super(permitted_params)
        end

        # Filter nested attributes recursively
        def self.filter_nested_attributes(params)
          filtered_params = params.slice(*attribute_types.keys.map(&:to_s))

          # Handle nested attributes
          attribute_types.each do |key, type|
            if type.is_a?(Class) && type < ActiveModel::Model
              nested_params = params[key.to_s] || params[key.to_sym]
              if nested_params.is_a?(Array)
                # For arrays, validate each element
                filtered_params[key] = nested_params.map { |np| type.new(np) }
              elsif nested_params.is_a?(Hash)
                # For single nested objects
                filtered_params[key] = type.new(nested_params)
              end
            end
          end

          filtered_params
        end

        # Validate nested attributes recursively
        def valid?
          super && validate_nested_attributes
        end

        private

        def validate_nested_attributes
          self.class.attribute_types.all? do |key, type|
            next true unless type.is_a?(Class) && type < ActiveModel::Model

            nested_value = send(key)
            if nested_value.is_a?(Array)
              nested_value.all?(&:valid?)
            elsif nested_value.is_a?(ActiveModel::Model)
              nested_value.valid?
            else
              true
            end
          end
        end
      end

      # Extend the `attribute` DSL to support both blocks and explicit validators
      def validator_class.attribute(name, type = nil, **options, &block)
        if block_given?
          # If a block is given, create a nested validator class
          nested_class = Class.new do
            include ActiveModel::Model
            include ActiveModel::Attributes

            # Define nested attributes inside the block
            instance_eval(&block)
          end
          attribute(name, nested_class, **options)
        else
          # If no block, define a regular attribute or use an explicit validator
          super(name, type, **options)
        end
      end

      # Store the validator class for the specified action
      self._param_validations = _param_validations.merge(action_name.to_sym => validator_class)

      # Add a before_action to validate parameters
      before_action only: action_name do
        validator = validator_class.new(params.to_unsafe_h)

        # Respond with errors if validation fails
        unless validator.valid?
          respond_with_validation_errors(validator)
        end
      end
    end
  end

  private

  # Handle validation errors
  def respond_with_validation_errors(validator)
    respond_to do |format|
      format.json { render json: { errors: collect_errors(validator) }, status: :unprocessable_entity }
      format.html { render plain: collect_errors(validator).join(", "), status: :unprocessable_entity }
    end
  end

  # Recursively collect errors from nested validators
  def collect_errors(validator, prefix = nil)
    errors = []

    validator.errors.each do |attribute, message|
      full_key = prefix ? "#{prefix}.#{attribute}" : attribute.to_s
      errors << "#{full_key} #{message}"
    end

    validator.class.attribute_types.each do |key, type|
      next unless type.is_a?(Class) && type < ActiveModel::Model

      nested_value = validator.send(key)
      if nested_value.is_a?(Array)
        nested_value.each_with_index do |nested_item, index|
          errors.concat(collect_errors(nested_item, "#{key}[#{index}]")) if nested_item.respond_to?(:errors)
        end
      elsif nested_value.respond_to?(:errors)
        errors.concat(collect_errors(nested_value, key.to_s))
      end
    end

    errors
  end
end
