# frozen_string_literal: true

module Api
  class UsersController < ApplicationController
    def show
      @user = User.find(params[:id])
      render json: @user
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: 404
    end

  end
end
