# frozen_string_literal: true

module Api
  class UsersController < ApplicationController
    before_action :authenticate_user!, :except => [:find_by_email]
    def index
      render json: current_user, status: :ok
    end

    def show
      @user = User.find(params[:id])
      render json: @user
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: :not_found
    end

    def find_by_email
      @user = User.find_by(email: params[:email])
      if @user
        render json: @user
      else render json: { error: 'User not found' }, status: :not_found
      end
    end

  end
end
