# spec/requests/easy_params_validation_spec.rb
require 'rails_helper'

# 需要一个虚拟的 Controller 来测试
class TestOrdersController < ActionController::Base
  # !!!! 重要 !!!!
  # 在测试环境中，Engine 的自动 include 可能不会像在实际应用中那样工作。
  # 最可靠的方法是在测试 Controller 中显式 include。
  # 或者，确保你的 rails_helper 正确加载了 Engine 并触发了 on_load 钩子。
  # 为简单起见，我们显式 include：
  include EasyParams::ControllerConcern

  # 定义虚拟路由来访问 action
  def self.load_routes
    routes = Rails.application.routes
    routes.draw do
      post '/test_orders/basic_create', to: 'test_orders#basic_create'
      post '/test_orders/nested_create', to: 'test_orders#nested_create'
      post '/test_orders/array_create', to: 'test_orders#array_create'
    end
  end
  load_routes # 加载路由

  # --- 测试用例 1: Basic ---
  validates_params :basic_create do
    attribute :customer_name, :string
    attribute :email, :string
    validates :customer_name, :email, presence: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  end

  def basic_create
    # 验证成功后，before_action 不会渲染，会执行到这里
    render json: { message: "Basic create success!" }, status: :ok
  end

  # --- 测试用例 2: Nested ---
  class TestAddressValidator
     include ActiveModel::Model
     include ActiveModel::Attributes
     attribute :street, :string
     attribute :city, :string
     validates :street, :city, presence: true
  end

  validates_params :nested_create do
     attribute :order_id, :integer
     attribute :address, TestAddressValidator # 使用自定义验证器
     validates :order_id, presence: true
  end

  def nested_create
    render json: { message: "Nested create success!" }, status: :ok
  end

  # --- 测试用例 3: Array ---
  class TestItemValidator
    include ActiveModel::Model
    include ActiveModel::Attributes
    attribute :name, :string
    attribute :quantity, :integer
    validates :name, presence: true
    validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  end

  validates_params :array_create do
    attribute :items, :array, element_validator: TestItemValidator # 自定义选项
  end

  def array_create
    render json: { message: "Array create success!" }, status: :ok
  end

  # --- 保护方法，避免路由找不到方法 ---
   private
   def _validate_easy_params_for_basic_create!; super; end
   def _validate_easy_params_for_nested_create!; super; end
   def _validate_easy_params_for_array_create!; super; end
end

RSpec.describe TestOrdersController, type: :controller do # 或者 :request 类型
  before(:all) do
    # 确保路由已加载
    Rails.application.reload_routes!
  end

   describe "POST #basic_create" do
     context "with valid parameters" do
       let(:valid_params) { { customer_name: "Test User", email: "test@example.com" } }

       it "returns http success" do
         post :basic_create, params: valid_params, format: :json
         expect(response).to have_http_status(:ok)
         expect(JSON.parse(response.body)["message"]).to eq("Basic create success!")
       end
     end

     context "with invalid parameters" do
       let(:invalid_params) { { customer_name: "", email: "invalid-email" } }

       it "returns unprocessable entity" do
         post :basic_create, params: invalid_params, format: :json
         expect(response).to have_http_status(:unprocessable_entity)
       end

       it "returns specific error messages" do
         post :basic_create, params: invalid_params, format: :json
         errors = JSON.parse(response.body)["errors"]
         expect(errors).to include("Customer name can't be blank")
         expect(errors).to include("Email is invalid")
       end
     end
   end

   describe "POST #nested_create" do
     context "with valid parameters" do
        let(:valid_params) { { order_id: 123, address: { street: "123 Main St", city: "Anytown" } } }
        it "returns http success" do
          post :nested_create, params: valid_params, format: :json
          expect(response).to have_http_status(:ok)
        end
     end
     context "with invalid nested parameters" do
        let(:invalid_params) { { order_id: 123, address: { street: "", city: "" } } }
        it "returns unprocessable entity with nested errors" do
          post :nested_create, params: invalid_params, format: :json
          expect(response).to have_http_status(:unprocessable_entity)
          errors = JSON.parse(response.body)["errors"]
          expect(errors).to include("Address.street can't be blank")
          expect(errors).to include("Address.city can't be blank")
        end
     end
   end

   describe "POST #array_create" do
     context "with valid array parameters" do
        let(:valid_params) { { items: [{ name: "Item 1", quantity: 2 }, { name: "Item 2", quantity: 1 }] } }
         it "returns http success" do
           post :array_create, params: valid_params, format: :json
           expect(response).to have_http_status(:ok)
         end
     end
     context "with invalid array parameters" do
        let(:invalid_params) { { items: [{ name: "", quantity: 2 }, { name: "Item 2", quantity: 0 }] } }
         it "returns unprocessable entity with indexed errors" do
           post :array_create, params: invalid_params, format: :json
           expect(response).to have_http_status(:unprocessable_entity)
           errors = JSON.parse(response.body)["errors"]
           expect(errors).to include("Items[0].name can't be blank")
           expect(errors).to include("Items[1].quantity must be greater than 0")
         end
     end
     context "with invalid parameter type (not an array)" do
        let(:invalid_params) { { items: "not an array" } }
         it "returns unprocessable entity with type error" do
           post :array_create, params: invalid_params, format: :json
           expect(response).to have_http_status(:unprocessable_entity)
           errors = JSON.parse(response.body)["errors"]
           expect(errors).to include("Items must be an array")
         end
     end
   end
end