class SessionsController < ApplicationController
  require 'yaml'

  #GET /password to reset
  def password
  end

  #POST /reset_pass
  def reset_pass

    if User.where(email: params[:session][:email].to_s.downcase) != [] && params[:session][:email].to_s != ''
      @user = User.find(User.where(email: params[:session][:email].to_s.downcase).map(&:id)*",")
    else
      @user =''
    end

    if @user != ''
      number ||= rand(999)
      number2 ||= rand(999)
      $reset_pass = number2.to_s + number.to_s
      $userid = @user.id
      UserMailer.with(user: @user).reset_password.deliver_now
      flash[:info] = "Please, verify your email and follow the instructions."
      redirect_to password_reset_path
    else
      flash[:danger] = "We can't verify your email, please try again!!!" # Not quite right!
      render 'password'
    end
  end

  #GET
  def reset_password
  end
  #POST
  def reset_password_post
    if params[:session][:code] == $reset_pass
      if params[:session][:new_password] == params[:session][:repeat_password] && params[:session][:repeat_password] != ''

        salt  = 'CCEKvUgNbXByO6eAp2pgb56Nur/E16tHA1cYY2Ofai8='
        key   = ActiveSupport::KeyGenerator.new('password').generate_key(salt, 32)
        crypt = ActiveSupport::MessageEncryptor.new(key)
        encrypted_data = crypt.encrypt_and_sign(params[:session][:new_password], purpose: :login)

        r = RethinkDB::RQL.new
        conn = r.connect(:host => "localhost", :port => 28015)

        r.db('treasury_development').table("users").filter({
          :id => $userid}).update({
            :password_digest => encrypted_data
        }).run(conn)

        conn.close

        $reset_pass='76872645826uytutfaskgdfjashdg'

        flash[:success] = "Password was successfully updated.!"
        redirect_to login_path

      else
        flash[:danger] = "Password does not mach. Try again..."
        render 'reset_password'
      end
    else
      flash[:danger] = "Email code is not correct. Try again..."
      render 'reset_password'
    end

  end

  def new
  end

  def create
    user = User.where(username: params[:session][:username].to_s)
    pass = User.where(username: params[:session][:username].to_s).map(&:password_digest)*",".to_s
    verified = User.where(username: params[:session][:username].to_s).map(&:verified)*",".to_s

    if pass != ''
      salt  = 'CCEKvUgNbXByO6eAp2pgb56Nur/E16tHA1cYY2Ofai8='
      key   = ActiveSupport::KeyGenerator.new('password').generate_key(salt, 32)
      crypt = ActiveSupport::MessageEncryptor.new(key)
      pass = crypt.decrypt_and_verify(pass, purpose: :login)
    end

    if user && params[:session][:"password"].to_s == pass && pass != '' && verified.to_s == "true"
      log_in user
      flash[:info] = "Welcome to treasury app"
      redirect_to tr_statements_path
    else
      if user && params[:session][:"password"].to_s == pass && pass != ''
        flash[:danger] = 'User not yet verified, contact Veda member.' # Not quite right!
        render 'new'
      else
        flash[:danger] = 'Invalid username/password combination' # Not quite right!
        render 'new'
      end
    end
  end

  def destroy
    log_out
    redirect_to root_url
  end
end
