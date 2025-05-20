# lib/easy_params/validator.rb
require 'active_model'

module EasyParams
  class Validator
    include ActiveModel::Model # 让我们能使用 ActiveModel 的功能，特别是 errors
    include ActiveModel::Attributes # 如果需要类型转换，这个会很有用

    attr_reader :definition, :params, :errors, :controller

    # 动态定义属性访问器
    # 这个方法会在初始化时被调用，根据 DSL 定义来创建 attribute
    def self.define_attributes_from_dsl(definition)
      definition.attributes.each do |name, config|
        # 使用 ActiveModel::Attributes 来处理类型（如果需要）
        # 注意：基本的类型转换（如 :string, :integer）需要 ActiveModel 7.1+
        # 或者需要自己实现转换逻辑或使用其他库
        # 为了简单起见，我们暂时只定义访问器，类型检查通过 validates 实现
        attr_accessor name

        # 如果是嵌套结构或自定义验证器，也定义访问器
        if config[:type] == :nested || config[:type] == :nested_validator || config[:type] == :array
          attr_accessor "#{name}_attributes" # 通常嵌套表单提交参数的方式
        end
      end

      # 应用 DSL 中定义的顶层验证规则
      definition.validations.each do |validation|
        validates(*validation[:attributes], validation[:options])
      end
    end

    def initialize(definition, params, controller = nil)
      @definition = definition
      @params = params.deep_symbolize_keys # 确保所有键都是符号
      @controller = controller
      @errors = ActiveModel::Errors.new(self)

      # 动态定义当前实例需要的属性访问器和验证
      # 注意：这里直接修改类定义，可能影响并发请求。更好的方式是
      # 创建一个匿名的 ActiveModel 类，或者在实例上动态应用验证。
      # 为了简化示例，我们先用这种方式。
      # self.class.define_attributes_from_dsl(definition)

      # 更安全的方式：创建一个临时的匿名类
      @validation_model_instance = build_validation_model_instance(definition, @params)

      # 将参数赋值给实例变量或模型实例
      # assign_parameters(@params, definition.attributes)
    end

    def valid?
      @errors.clear # 清除之前的错误

      # 验证顶层属性
      validate_level(@params, definition, @errors)

      @errors.empty?
    end

    # 递归验证方法
    def validate_level(current_params, current_definition, current_errors, parent_key = nil)
      # 1. 创建一个临时的 ActiveModel 对象来运行当前层的验证
      temp_model = build_temp_model(current_definition)

      # 2. 将当前层的参数赋值给临时模型
      current_definition.attributes.each_key do |name|
        param_value = current_params[name]
        begin
          temp_model.send("#{name}=", param_value) if temp_model.respond_to?("#{name}=")
        rescue ActiveModel::AttributeAssignmentError => e
          # 处理赋值错误（例如类型不匹配）
          key = parent_key ? "#{parent_key}.#{name}" : name
          current_errors.add(key.to_sym, "is invalid: #{e.message}")
        end
      end

      # 3. 运行临时模型的验证
      temp_model.validate # 调用 ActiveModel 的验证

      # 4. 合并错误到主 errors 对象，并添加前缀
      temp_model.errors.each do |error|
        # error 是 ActiveModel::Error 对象 (ActiveModel 6.1+)
        original_key = error.attribute
        message = error.message
        full_key = parent_key ? "#{parent_key}.#{original_key}" : original_key
        # 避免重复添加相同的错误信息
        unless current_errors.added?(full_key.to_sym, message)
          current_errors.add(full_key.to_sym, message)
        end
      end

      # 5. 递归处理嵌套结构、自定义验证器和数组
      current_definition.attributes.each do |name, config|
        param_value = current_params[name]
        nested_key = parent_key ? "#{parent_key}.#{name}" : name

        case config[:type]
        when :nested
          if param_value.is_a?(Hash) && config[:nested_dsl]
            validate_level(param_value.deep_symbolize_keys, config[:nested_dsl], current_errors, nested_key)
          elsif param_value.nil? && config[:nested_dsl].validations.any? { |v| v[:options][:presence] }
             # 如果嵌套参数缺失，但内部有 presence 验证，可能需要添加错误
             # （ActiveModel 的 validates_presence_of 通常会处理这种情况，但这里可以明确处理）
             # current_errors.add(nested_key.to_sym, "can't be blank")
             # 注意：上面的 validates *已经* 添加到 temp_model，所以 presence 应该会被触发
          elsif !param_value.is_a?(Hash) && !param_value.nil?
            current_errors.add(nested_key.to_sym, "must be an object")
          end
        when :nested_validator
          if param_value.is_a?(Hash) && config[:validator_class]
            validator_instance = config[:validator_class].new(param_value)
            unless validator_instance.valid?
              validator_instance.errors.each do |error|
                original_key = error.attribute
                message = error.message
                full_key = "#{nested_key}.#{original_key}"
                 unless current_errors.added?(full_key.to_sym, message)
                   current_errors.add(full_key.to_sym, message)
                 end
              end
            end
          elsif !param_value.is_a?(Hash) && !param_value.nil?
             current_errors.add(nested_key.to_sym, "must be an object for #{config[:validator_class].name}")
          end
        when :array
          if param_value.is_a?(Array)
            element_validator_class = config[:options][:element_validator] # 假设选项中指定了元素验证器
            element_dsl = config[:nested_dsl] # 或者使用嵌套 DSL 定义

            param_value.each_with_index do |item, index|
              item_key = "#{nested_key}[#{index}]"
              if element_dsl && item.is_a?(Hash)
                 validate_level(item.deep_symbolize_keys, element_dsl, current_errors, item_key)
              elsif element_validator_class && item.is_a?(Hash)
                 element_instance = element_validator_class.new(item)
                 unless element_instance.valid?
                   element_instance.errors.each do |error|
                     original_key = error.attribute
                     message = error.message
                     full_key = "#{item_key}.#{original_key}"
                     unless current_errors.added?(full_key.to_sym, message)
                       current_errors.add(full_key.to_sym, message)
                     end
                   end
                 end
               elsif !item.is_a?(Hash) && (element_dsl || element_validator_class)
                 current_errors.add(item_key.to_sym, "must be an object")
               # TODO: 添加对简单类型数组的验证 (如果需要)
               # else
               #  验证 item 是否符合 config[:options][:element_type] 等
               end
            end
          elsif !param_value.is_a?(Array) && !param_value.nil?
            current_errors.add(nested_key.to_sym, "must be an array")
          end
        end
      end
    end

    # 辅助方法，动态创建一个包含当前层级属性和验证的匿名 ActiveModel 类
    def build_temp_model(definition)
      Class.new do
        include ActiveModel::Model
        include ActiveModel::Attributes # 可选，用于类型转换

        # 根据 DSL 定义属性
        definition.attributes.each_key do |name|
           # 使用 attribute 而不是 attr_accessor 来获得可能的类型转换
           attribute name # 类型可以在这里指定，如果 DSL 支持的话
        end

        # 应用当前层级的验证
        definition.validations.each do |validation|
          validates(*validation[:attributes], validation[:options])
        end

        # 如果有嵌套 DSL，为其属性也添加 validates_nested
        # (这需要更复杂的处理，可能需要在 assign 时手动触发嵌套验证)
        # definition.attributes.each do |name, config|
        #   if config[:nested_dsl]
        #     validates_associated name # 但这需要 name 是一个 ActiveModel 对象
        #   end
        # end

      end.new # 返回该匿名类的实例
    end

    # ActiveModel 需要这个方法来报告错误
    def read_attribute_for_validation(attr)
      # @validation_model_instance.send(attr)
      @params[attr] # 或者直接从 params 读取，但这可能绕过类型转换
    end

  end
end