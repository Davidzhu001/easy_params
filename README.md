# EasyParams

**EasyParams** is a lightweight and extensible parameter validation library for Rails. It provides a simple DSL (Domain-Specific Language) for defining and validating parameters, including support for nested attributes, custom validators, and arrays.

---

## 🚀 Quick Start

### 1. Install the Gem

Add the gem to your `Gemfile`:

```ruby
gem 'easy_params_enhanced'
```

Then run:

```bash
bundle install
```

### 2. Include the Module

Include the `EasyParams` module in your controller:

```ruby
class ApplicationController < ActionController::Base
  include EasyParams
end
```

## 📖 Examples

### 1. Basic Parameter Validation

Define and validate parameters for a create action:

```ruby
class OrdersController < ApplicationController
  include EasyParams

  validates_params :create do
    attribute :customer_name, :string
    attribute :email, :string
    attribute :address do
      attribute :street, :string
      attribute :city, :string
      attribute :zip, :string

      validates :street, :city, :zip, presence: true
    end

    validates :customer_name, :email, presence: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  end

  def create
    render json: { message: "Order created successfully!" }
  end
end
```

* Example Request:

```json
{
  "customer_name": "",
  "email": "invalid_email",
  "address": {
    "street": "",
    "city": "",
    "zip": ""
  }
}
```

* Example Response:

```json
{
  "errors": [
    "customer_name can't be blank",
    "email is invalid",
    "address.street can't be blank",
    "address.city can't be blank",
    "address.zip can't be blank"
  ]
}
```

### 2. Complex Parameter Validation with Nested Validator

You can define custom nested validators using `ActiveModel`:

```ruby
class OrdersController < ApplicationController
  validates_params :create do
    attribute :customer_name, :string
    attribute :email, :string
    attribute :address, :string

    # Use a nested validator for payment details
    attribute :payment, PaymentValidator

    validates :customer_name, presence: true
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :address, presence: true
  end

  def create
    render json: { message: "Order created successfully!" }
  end

  # Nested validator class
  class PaymentValidator
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :card_number, :string
    attribute :expiration_date, :string
    attribute :cvv, :string

    validates :card_number, presence: true, length: { is: 16 }
    validates :expiration_date, presence: true
    validates :cvv, presence: true, length: { is: 3 }
  end
end
```

### 3. Nested Array Validation

You can also validate arrays of nested objects:

```ruby 
class OrdersController < ApplicationController
  validates_params :create do
    attribute :customer_name, :string
    attribute :email, :string
    attribute :address, :string

    # Use a nested validator for items
    attribute :items, ItemValidator

    validates :customer_name, presence: true
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :address, presence: true
  end

  def create
    render json: { message: "Order created successfully!" }
  end

  # Nested validator class
  class ItemValidator
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :quantity, :integer
    attribute :price, :decimal

    validates :name, presence: true
    validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :price, presence: true, numericality: { greater_than: 0 }
  end
end
```

## 🔧 Installation and Usage

To install and use EasyParams in your Rails application:

1. Add the gem to your Gemfile:

```bash
gem 'easy_params_enhanced'
```

2. Run bundle install.

3. Include the EasyParams module in your ApplicationController or specific controllers.

4. Use the validates_params method to define and validate parameters.

## 📚 References


- [ActiveModel::Validations](https://api.rubyonrails.org/classes/ActiveModel/Validations.html)  
  Learn about ActiveModel's validation features for building custom validation logic.

- [ActiveModel::Attributes](https://api.rubyonrails.org/classes/ActiveModel/Attributes.html)  
  Understand how to define and manage attributes in ActiveModel-based objects.

- [Rails Guide on Creating and Customizing Rails Generators & Templates](https://guides.rubyonrails.org/generators.html)  
  Explore how to create and customize Rails generators and templates for your projects.

- [EasyParams GitHub Repository](https://github.com/your-repo/easy_params)  
  Visit the official EasyParams repository for source code, issues, and contributions.

## 🤝 Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes.

## 📝 License

This project is licensed under the MIT License.

