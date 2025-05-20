# lib/easy_params/controller_concern.rb
require 'active_support/concern'

module EasyParams
  module ControllerConcern
    extend ActiveSupport::Concern # 使用 ActiveSupport::Concern 来简化模块包含和类方法扩展

    included do
      # 类级别的存储，用于存放每个 action 的验证定义
      class_attribute :_easy_params_definitions, instance_writer: false, default: {}

      # 定义一个 before_action 来触体验证
      # 注意：我们在这里定义了 helper 方法，但需要用户在自己的 Controller
      # 或者 ApplicationController 中显式调用 before_action :_validate_easy_params!
      # 或者我们可以在这里强制添加 before_action，但这可能不够灵活
      # 让我们提供一个方法，让 Engine 或用户来决定是否自动添加 before_action
      # 另一种方法：让 validates_params 自动添加 before_action
    end

    module ClassMethods
      # DSL 方法：validates_params
      def validates_params(action_name, &block)
        definition = EasyParams::Dsl.new(&block)
        # 存储定义，使用 dup 防止后续修改影响已存储的定义
        self._easy_params_definitions = _easy_params_definitions.dup.tap do |h|
          h[action_name.to_sym] = definition
        end

        # 在定义验证时，自动为该 action 添加 before_action 钩子
        before_action :"_validate_easy_params_for_#{action_name}!", only: [action_name]

        # 动态定义对应的私有 before_action 方法
        define_method("_validate_easy_params_for_#{action_name}!") do
          _validate_easy_params!(action_name.to_sym)
        end
        private "_validate_easy_params_for_#{action_name}!"
      end
    end

    private

    # 实际执行验证的 before_action 逻辑
    def _validate_easy_params!(action_name)
      definition = self.class._easy_params_definitions[action_name]
      return unless definition # 如果没有为当前 action 定义验证，则跳过

      # 使用定义和当前请求的 params 来创建和执行验证器
      validator = EasyParams::Validator.new(definition, params.to_unsafe_h, self) # 传递 controller 实例以备将来使用
      unless validator.valid?
        # 如果验证失败，渲染错误信息
        # 这里的响应格式可以根据需要定制
        render json: { errors: validator.errors.full_messages }, status: :unprocessable_entity # 422 状态码
      end
    end
  end
end