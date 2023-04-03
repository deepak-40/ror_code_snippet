# frozen_string_literal: true

module UserConcern
  extend ActiveSupport::Concern

  def get_states
    @states = CS.states(params[:country])
  end

  def check_existing_email
    if params.key?(:type)
      # For Registration
      response = true # email not exists
      if params[:user][:email].present? && User.unscoped.exists?(email: params[:user][:email])
        response = false # email exists
      end
    else
      # For Forgot User
      response = false # email not exists
      if params[:user][:email].present? && User.unscoped.exists?(email: params[:user][:email])
        response = true # email exists
      end
    end
    render json: response
  end

  # eg. check existence of username
  def check_existing_column
    response = true
    if request.xhr? && params[:model].present? && params[:column].present? && params[params[:model].to_s][params[:column].to_s].present?
      column_val = params[params[:model].to_s][params[:column].to_s]
      if params[:existing_data].present? && params[:existing_data].strip == column_val
        response = true
      elsif params[:model].camelize.constantize.unscoped.exists?("#{params[:column].downcase}": column_val)
        response = false
      end
    end
    render json: response and return
  end

  def check_current_password
    response = true
    if request.xhr? && params[:user][:current_password].present?
      user = User.unscoped.find_by_id(current_user.id)
      response = 'false' unless user.valid_password?(params[:user][:current_password])
    end
    render json: response
  end

  def change_password
    return unless request.post?

    user = current_user
    check = params[:user][:password] == params[:user][:password_confirmation]
    # check end
    if user&.valid_password?(params[:user][:current_password]) && check
      if user.update(password: params[:user][:password])
        flash[:notice] = I18n.t('change_password.update.success')
        sign_out(user)
      else
        flash[:error] = I18n.t('common.error')
      end
    end
    redirect_to new_user_session_path
  end
end
