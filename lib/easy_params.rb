# lib/easy_params.rb
require "easy_params/version"
require "easy_params/engine" # 加载 Engine
require "easy_params/dsl"    # 我们将在这里定义 DSL 相关类
require "easy_params/validator" # 我们将在这里定义验证逻辑
require "easy_params/controller_concern" # 引入 Controller 功能的模块

module EasyParams
  # 可以在这里定义 Gem 级别的配置或方法（如果需要）
end