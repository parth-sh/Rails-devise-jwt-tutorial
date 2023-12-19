This project will be built around the concept of a student accommodation platform, employing Next.js for the frontend and Ruby on Rails for the backend. Prompt engineering with the OpenAI GPT-4 model will utilized to expedite the coding process for both the frontend and backend, enhancing development speed. The entire project will be designed, developed, and deployed significantly aided by the use of an AI-powered coding chatbot.

## Setting up rails server

Thanks to the guide [Rails for API-only Applications](https://guides.rubyonrails.org/api_app.html)

For setting up the rails only api application, we will run these commands

```sh
rails new backend-api -T -d postgresql --api
bin/rails db:create
bin/rake db:migrate
```

-T flag denotes 
```-T, [--skip-test-unit], [--no-skip-test-unit]          # Skip Test::Unit files```

As we will be working with a frontend application too, changing the development port to 8080

```rb
# config/puma.rb
port ENV.fetch("PORT") { 8080 }
```

```rb
# config/enviroments/development.rb
config.action_mailer.default_url_options = { host: 'localhost', port: 8080 }
```

It also a good idea to change the action mailer port to 8080


## Setting up authentication 

Thanks to the guide [Rails Devise JWT Tutorial](https://github.com/DakotaLMartinez/rails-devise-jwt-tutorial)

Using devise and devise-jwt with jsonapi-serializer response.

### Configure Rack Middleware

As this is an API Only application, we have to handle ajax requests. So for that, we have to Rack Middleware for handling Cross-Origin Resource Sharing (CORS)

To do that, Just uncomment the

```rb
gem 'rack-cors'
```

line from your generated Gemfile. And uncomment the contents of `config/initialzers/cors.rb` the following lines to application.rb, adding an expose option in the process:

```rb
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource(
     '*',
     headers: :any,
     expose: ["Authorization"],
     methods: [:get, :patch, :put, :delete, :post, :options, :show]
    )
  end
end
```

Here, we can see that there should be an "Authorization" header exposed which will be used to dispatch and receive JWT tokens in Auth headers.

### Add the needed Gems

Here, we are going to add gem like ‘devise’ and ‘devise-jwt’ for authentication and the dispatch and revocation of JWT tokens and ‘jsonapi-serializer’ gem for json response.

```rb
gem 'devise'
gem 'devise-jwt'
gem 'jsonapi-serializer'
```

Then, do

```bash
bundle install
```

### Configure devise

By running the following command to run a generator

```
$ rails generate devise:install
```

Add the following line (This is suggested after devise setup)

```rb
# config/environments/development.rb
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```
As we have our development port set to 8080, action mailer port also needs to be same


It is important to set our navigational formats to empty in the generated devise.rb by uncommenting and modifying the following line since it’s an api only app.

```rb
# config/initializers/devise.rb
config.navigational_formats = []
```

### Create User model

You can create a devise model to represent a user. It can be named as anything. So, I’m gonna be going ahead with User. Run the following command to create User model.

```sh
$ rails generate devise User
```

Then run migrations using,

```sh
$ rails db:migrate
```

### Create devise controllers and routes

```sh
rails g devise:controllers users -c sessions registrations
```

-c flag denoted only these controllers will be generated

specify that they will be responding to JSON requests. The files will look like this:

```rb
class Users::SessionsController < Devise::SessionsController
  respond_to :json
end
```

```rb
class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json
end
```

Then, add the routes aliases to override default routes provided by devise in the routes.rb

```rb
Rails.application.routes.draw do
  devise_for :users, path: '', path_names: {
    sign_in: 'login',
    sign_out: 'logout',
    registration: 'signup'
  },
  controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }
end
```

### Configure devise-jwt

Add the following lines

```rb
# config/initializers/devise.rb
config.jwt do |jwt|
    jwt.secret = Rails.application.credentials.fetch(:secret_key_base)
    jwt.dispatch_requests = [
      ['POST', %r{^/login$}]
    ]
    jwt.revocation_requests = [
      ['DELETE', %r{^/logout$}]
    ]
    jwt.expiration_time = 30.minutes.to_i
end
```

Here, we are just specifying that on every post request to login call, append JWT token to Authorization header as “Bearer” + token when there’s a successful response sent back and on a delete call to logout endpoint, the token should be revoked.

The `jwt.expiration_time` sets the expiration time for the generated token. In this example, it’s 30 minutes.

### Set up a revocation strategy

Revocation of tokens is an important security concern. The `devise-jwt` gme comes with three revocation strategies out of the box. You can read more about them in this [blog post on token recovation strategies](https://waiting-for-dev.github.io/blog/2017/01/24/jwt_revocation_strategies).

For now, we'll be going with the one they recommended with is to store a single valid user attached token with the user record in the users table.

Here, the model class acts itself as the revocation strategy. It needs a new string column with name `jti` to be added to the user. `jti` stands for JWT ID, and it is a standard claim meant to uniquely identify a token.

It works like the following:

- When a token is dispatched for a user, the `jti` claim is taken from the `jti` column in the model (which has been initialized when the record has been created).
- At every authenticated action, the incoming token `jti` claim is matched against the `jti` column for that user. The authentication only succeeds if they are the same.
- When the user requests to sign out its `jti` column changes, so that provided token won't be valid anymore.

In order to use it, you need to add the `jti` column to the user model. So, you have to set something like the following in a migration:

```ruby
def change
  add_column :users, :jti, :string, null: false
  add_index :users, :jti, unique: true
  # If you already have user records, you will need to initialize its `jti` column before setting it to not nullable. Your migration will look this way:
  # add_column :users, :jti, :string
  # User.all.each { |user| user.update_column(:jti, SecureRandom.uuid) }
  # change_column_null :users, :jti, false
  # add_index :users, :jti, unique: true
end
```

To add this, we can run

```
rails g migration addJtiToUsers jti:string:index:unique
```

And then make sure to add `null: false` to the `add_column` line and `unique: true` to the `add_index` line

**Important:** You are encouraged to set a unique index in the `jti` column. This way we can be sure at the database level that there aren't two valid tokens with same `jti` at the same time.

Then, you have to add the strategy to the model class and configure it accordingly:

```ruby
class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self
end
```

In our case, we won't be needing to interact with the jwt_payload directly, so we can move on for now. Next, we'll run migrations using

```bash
rails db:migrate
```

### Add respond_with using jsonapi-serializer method

As we already added the `jsonapi-serializer` gem, we can generate a serializer to configure the json format we'll want to send to our front end API.

```sh
$ rails generate serializer user id email created_at
```

It will create a serializer with a predefined structure. Now, we have to add the attributes we want to include as a user response. So, we'll add the user's id, email and created_at. So the final version of user_serializer.rb looks like this:

```rb
# app/serializers/user_serializer.rb
class UserSerializer
  include JSONAPI::Serializer
  attributes :id, :email, :created_at
end
```

We can access serializer data for single record by,

```rb
UserSerializer.new(resource).serializable_hash[:data][:attributes]
And multiple records by,
UserSerializer.new(resource).serializable_hash[:data].map{|data| data[:attributes]}
```

Now, we have to tell devise to communicate through JSON by adding these methods in the `RegistrationsController` and `SessionsController`

```rb
class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json
  private

  def respond_with(resource, _opts = {})
    if resource.persisted?
      render json: {
        status: {code: 200, message: 'Signed up sucessfully.'},
        data: UserSerializer.new(resource).serializable_hash[:data][:attributes]
      }
    else
      render json: {
        status: {message: "User couldn't be created successfully. #{resource.errors.full_messages.to_sentence}"}
      }, status: :unprocessable_entity
    end
  end
end

class Users::SessionsController < Devise::SessionsController
  respond_to :json
  private

  def respond_with(resource, _opts = {})
    render json: {
      status: {code: 200, message: 'Logged in sucessfully.'},
      data: UserSerializer.new(resource).serializable_hash[:data][:attributes]
    }, status: :ok
  end

  def respond_to_on_destroy
    if current_user
      render json: {
        status: 200,
        message: "logged out successfully"
      }, status: :ok
    else
      render json: {
        status: 401,
        message: "Couldn't find an active session."
      }, status: :unauthorized
    end
  end
end
```

Now we create a controller, and add a method

```rb
class CurrentUserController < ApplicationController
  before_action :authenticate_user!
  def index
    render json: current_user, status: :ok
  end
end
```

Adding the `before_action :authenticate_user` will ensure that we only see a 200 response if we have a valid JWT in the headers. If we don't this endpoint should return a `401` status code.

Finally, it’s done

---

## Testing


While testing from postman, its forcing us to use seesions, for that there is a solution

This is a bug with devise which is not solved yet:

### Disabling session store

https://github.com/waiting-for-dev/devise-jwt/issues/235#issuecomment-1453383251


Centrally configure store: false, instead of overwriting each methods separately that might need it:

```rb
#config/initializers/devise.rb
Devise.setup do |config|
  # ... other config
  
  config.warden do |warden|
    warden.scope_defaults :user, store: false  # <---- This will use the config even if it's not passed to the method opts
    warden.scope_defaults :admin, store: false # <---- You need to configure it for each scope you need it for
    # you might also want to overwrite the FailureApp in this section
  end
end
```

This way you don't need to hack the session store in rack, it's enough to disable it altogether (if you don't use an api_only application already):

```rb
# config/application.rb
module YourApp
  class Application < Rails::Application
    # ... other config
    
    config.session_store :disabled
  end
end
```

### users/registrations#create


![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/2y2th0xdgrlxv1vj0c23.png)

In headers we can see, we got our authorization token

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/gm9u65ucndxwuvn8z9fe.png)

and body as

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/92bkroa3tiyrddpnlgvp.png)

### users/sessions#create

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/fcac6sgxe0a2b9aaixdp.png)

We got our JWT token

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/at7ni2xl03ysocer32ze.png)

### api/users#index

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/3opvlmcaei5qzd213855.png)

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/ju4fpwunjc5szws1waec.png)

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/00b4a9tdoqgd4vpaulzf.png)

### users/sessions#destroy

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/bqskb14sy92gdl5gppnz.png)
