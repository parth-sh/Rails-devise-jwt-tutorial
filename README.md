# Development process

### Project initialization
https://guides.rubyonrails.org/api_app.html
```
rails new backend-api -T -d postgresql --api
bin/rails db:create
bin/rake db:migrate
```

### Generate scaffold for home
```
rails g scaffold home -T
bin/rake db:migrate
```

### changing development port
```
port ENV.fetch("PORT") { 8080 }
```

### Setting up testing framework
```
skipping it
```

### Changing Development Port
```
config.action_mailer.default_url_options = { host: 'localhost', port: 8080 }
```

### User authentication
```
gem 'devise'
bundle install
rails g devise:install
      create  config/initializers/devise.rb
      create  config/locales/devise.en.yml
===============================================================================

Depending on your application's configuration some manual setup may be required:

  1. Ensure you have defined default url options in your environments files. Here
     is an example of default_url_options appropriate for a development environment
     in config/environments/development.rb:

       config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }

     In production, :host should be set to the actual host of your application.

     * Required for all applications. *

  2. Ensure you have defined root_url to *something* in your config/routes.rb.
     For example:

       root to: "home#index"
     
     * Not required for API-only Applications *

  3. Ensure you have flash messages in app/views/layouts/application.html.erb.
     For example:

       <p class="notice"><%= notice %></p>
       <p class="alert"><%= alert %></p>

     * Not required for API-only Applications *

  4. You can copy Devise views (for customization) to your app by running:

       rails g devise:views
       
     * Not required *

===============================================================================
```
```
rails g devise user
invoke  active_record
create    db/migrate/20231214191203_devise_create_users.rb
create    app/models/user.rb
insert    app/models/user.rb
route  devise_for :users
```
```
rails db:migrate
```

## Code

YT-6: Setting-up-users-api-endpoint: Created users_controller, inside api folder, defined show method, fixed routes

YT-7: Adding find_by_email method, Added find_by_email to users collections route,

YT-8: Added rack-cors to project, configured the CORS middleware in config/initializers/cors.rb

YT-9: Adding error message to login form