# lib/easy_params/engine.rb
module EasyParams
  class Engine < ::Rails::Engine
    isolate_namespace EasyParams # 推荐做法，避免命名空间冲突

    # 使用 ActiveSupport.on_load 在 ActionController 加载时执行代码
    config.to_prepare do
      ActiveSupport.on_load(:action_controller_base) do
        # 将我们的 Controller 功能模块 include 进来
        include EasyParams::ControllerConcern
      end
      # 如果你的应用有 ActionController::API，也可能需要 include
      # ActiveSupport.on_load(:action_controller_api) do
      #   include EasyParams::ControllerConcern
      # end
    end
  end
end