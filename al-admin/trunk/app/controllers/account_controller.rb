class AccountController < ApplicationController
  # say something nice, you goof!  something sweet.
  def index
    if logged_in?
      redirect_to(top_path)
    else
      redirect_to(:action => 'login')
    end
  end

  def login
    return unless request.post?
    self.current_user = User.authenticate(params[:login], params[:password])
    if logged_in?
      if params[:remember_me] == "1"
        current_user.remember_me
        cookies[:auth_token] = {
          :value => current_user.remember_token,
          :expires => current_user.remember_token_expires_at
        }
      end
      redirect_back_or_default(top_url)
      flash[:notice] = "Logged in successfully"
    else
      flash[:notice] = "Login or Password is incorrect"
    end
  end

  def signup
    @user = LdapUser.new(params[:user])
    return unless request.post?
    if @user.save
      @system_user = User.create(:login => @user.id)
      unless @system_user.new_record?
        self.current_user = @system_user
        redirect_back_or_default(top_path)
        flash[:notice] = "Thanks for signing up!"
      end
    end
  end

  def logout
    current_user.forget_me if logged_in?
    cookies.delete :auth_token
    reset_session
    flash[:notice] = "You have been logged out."
    redirect_back_or_default(top_path)
  end
end
