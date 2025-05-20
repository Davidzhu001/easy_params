# lib/easy_params/dsl.rb
module EasyParams
  class Dsl
    attr_reader :attributes, :validations

    def initialize(&block)
      @attributes = {}
      @validations = []
      # 使用 instance_eval 在 Dsl 实例的上下文中执行 block
      instance_eval(&block) if block_given?
    end

    # DSL 方法：attribute
    # type 可以是 :string, :integer, :boolean, :array, 或者一个自定义验证器类
    # options 可以包含例如 :default, :element_type (用于数组) 等
    def attribute(name, type_or_validator = :string, options = {}, &block)
      name = name.to_sym
      nested_dsl = nil
      validator_class = nil

      if type_or_validator.is_a?(Class)
        # 如果是自定义验证器类 (如 PaymentValidator)
        validator_class = type_or_validator
        type = :nested_validator # 内部类型标记
      elsif block_given?
        # 如果提供了块，表示是嵌套结构
        nested_dsl = Dsl.new(&block)
        type = :nested # 内部类型标记
      else
        # 基本类型或数组
        type = type_or_validator.to_sym
      end

      @attributes[name] = {
        type: type,
        options: options,
        nested_dsl: nested_dsl,             # 存储嵌套 DSL
        validator_class: validator_class    # 存储自定义验证器类
      }
    end

    # DSL 方法：validates
    # 接收一个或多个属性名，以及 ActiveModel::Validations 的选项
    def validates(*attr_names)
      options = attr_names.extract_options! # 提取哈希选项
      @validations << { attributes: attr_names.map(&:to_sym), options: options }
    end
  end
end