=begin
 Summary: This module is used to handle flutterwave payment
=end
module FlutterwavePayment
  #This function is used to encrypt the payment information, In this function we need authorization key(key from flutterwave merchant account) and card details(user card details)
  def encrypt_payload(key, data)
    cipher = OpenSSL::Cipher.new("des-ede3")
    cipher.encrypt # Call this before setting key
    cipher.key = key
    data = data.to_json
    ciphertext = cipher.update(data)
    ciphertext << cipher.final
    return Base64.encode64(ciphertext)
  end

  #This function is used to get information that depends on current host
  def get_current_host
    hash = {}
      hash[:encryption_key] = LIVE_ENCRYPTION_KEY
      hash[:secret_key] = LIVE_SECRET_KEY
      hash[:redirect_url] = LIVE_REDIRECT_URL
    end
    hash
  end

  #This method is used to transfer amount to bank account
  def create_flutterwave_transfer(params)
      require 'net/http'
      require 'uri'
      require 'json'
      hash = get_current_host
      uri = URI.parse("https://api.flutterwave.com/v3/transfers")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"
      request["Authorization"] = "Bearer #{hash[:secret_key]}"
      request.body = "{\n    \"account_bank\": \"#{params[:bank_code]}\",\n    \"account_number\": \"#{params[:account_number]}\",\n    \"amount\": \"#{params[:amount].to_f}\",\n    \"narration\": \"Amount transferred to bank\",\n    \"currency\": \"#{CURRENCY}\",\n    \"reference\": \"#{current_user.id.to_s+Time.now.to_i.to_s}\",\n    \"callback_url\": \"#{CHARGE_CARD_REDIRECT_URL}\",\n    \"debit_currency\": \"#{CURRENCY}\"\n}"
      #abort request.body.inspect
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      p response.code
      p response.body
      result_hash = JSON.parse response.body
      return result_hash
  end

  #This method is the first step to take payment from the user card
  def charge_flutterwave_card(params)
      require 'net/http'
      require 'uri'
      require 'json'
      hash = get_current_host
      expiry = params[:card_expiry].split("/")
      data = {
         "card_number": params[:card_number],
         "cvv": params[:card_verification],
         "expiry_month": expiry[0],
         "expiry_year": expiry[1],
         "currency": CURRENCY,
         "amount": params[:amount],
         "email": current_user.email,
         #"fullname": (current_user.first_name.present? ? current_user.first_name.titlecase : '')+" "+(current_user.last_name.present? ? current_user.last_name.titlecase : ''),
         #"fullname": params[:full_name].present? ? params[:full_name].titlecase : "",
         "tx_ref": current_user.id.to_s+Time.now.to_i.to_s,
         "redirect_url": CHARGE_CARD_REDIRECT_URL,
         "authorization":{
            "mode":"pin",
            "pin": params[:card_pin]
          }
      }

      encrypted_payload =  encrypt_payload(hash[:encryption_key], data)
      uri = URI.parse("https://api.flutterwave.com/v3/charges?type=card")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"
      request["Authorization"] = "Bearer #{hash[:secret_key]}"
      request.body = JSON.dump({
        "client" => encrypted_payload
      })
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      p response.code
      p response.body
      result_hash = JSON.parse response.body
      return result_hash
  end

  #This method is the second step to take payment from the user card
  def verify_flutterwave_charge(params)
      require 'net/http'
      require 'uri'
      require 'json'
      hash = get_current_host
      uri = URI.parse("https://api.flutterwave.com/v3/validate-charge")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"
      request["Authorization"] = "Bearer #{hash[:secret_key]}"
      request.body = "{\n    \"otp\": \"#{params[:otp]}\",\n    \"flw_ref\": \"#{params[:flw_ref]}\"\n}"
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      p response.code
      p response.body
      result_hash = JSON.parse response.body
      return result_hash
  end


  def get_flutterwave_bank_full_name(params)
      require 'net/http'
      require 'uri'
      require 'json'
      hash = get_current_host
      uri = URI.parse("https://api.flutterwave.com/v3/accounts/resolve")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"
      request["Authorization"] = "Bearer #{hash[:secret_key]}"
      request.body = "{\n    \"account_number\": \"#{params[:account_number]}\",\n    \"account_bank\": \"#{params[:bank_code]}\"\n}"
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      p response.code
      p response.body
      result_hash = JSON.parse response.body
      return result_hash

  end



    #This method is used to send money from bank account to wallet
  def charge_flutterwave_bank_account(params)
      require 'net/http'
      require 'uri'
      require 'json'
      hash = get_current_host
      uri = URI.parse("https://api.flutterwave.com/v3/charges?type=debit_ng_account")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"
      request["Authorization"] = "Bearer #{hash[:secret_key]}"
      request.body = "{\n    \"tx_ref\": \"#{current_user.id.to_s+Time.now.to_i.to_s}\",\n    \"account_number\": \"#{params[:account_number]}\",\n    \"amount\": \"#{params[:amount].to_f}\",\n    \"account_bank\": \"#{params[:bank_code]}\",\n    \"currency\": \"#{CURRENCY}\",\n    \"email\": \"#{current_user.email}\",\n    \"fullname\": \"#{params[:full_name]}\",\n    \"phone_number\": \"#{current_user.user_detail.phone}\"\n}"
     # abort request.body.inspect

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      p response.code
      p response.body
      result_hash = JSON.parse response.body
      return result_hash
  end


  #This is just for reference to create token from the card, This function is not in use
  def token_create_from_card
      require "uri"
      require "net/http"
      hash = get_current_host
      #data_id is returned from  charge_card function
      url = URI.parse("https://api.flutterwave.com/v3/transactions/#{data_id}/verify")
      http = Net::HTTP.new(url.host, url.port);
      request = Net::HTTP::Get.new(url)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{hash[:secret_key]}"
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      response = JSON.parse response.body
      return response
  end


      #This method is used to create virtual account
  def charge_flutterwave_virtual_account(params)
      if defined?(params[:child_id]) && params[:child_id].present?
          current_login_user = User.find_by_id(decrypt(params[:child_id]))
        else
          current_login_user = current_user
        end



      require 'net/http'
      require 'uri'
      require 'json'
      hash = get_current_host
      uri = URI.parse("https://api.flutterwave.com/v3/charges?type=bank_transfer")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"

      request["Authorization"] = "Bearer #{LIVE_SECRET_KEY}"
      #request.body = "{\n    \"tx_ref\": \"#{current_user.id.to_s+Time.now.to_i.to_s}\",\n    \"amount\": \"#{params[:amount].to_f}\",\n    \"currency\": \"#{CURRENCY}\",\n    \"email\": \"#{current_user.email}\",\n    \"phone_number\": \"#{current_user.user_detail.phone}\"\n}"
      bvn = BVN
      request.body = "{\n    \"tx_ref\": \"#{current_user.id.to_s+Time.now.to_i.to_s}\",\n    \"amount\": \"#{params[:amount].to_f}\",\n    \"email\": \"#{current_user.email}\",\n    \"bvn\": \"#{bvn}\",\n    \"meta['user_id']\": \"#{current_login_user.id}\",\n    \"phone_number\": \"#{current_user.user_detail.phone}\",\n    \"currency\": \"#{CURRENCY}\"\n}"

      #abort request.body.inspect

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      p response.code

      p response.body
      result_hash = JSON.parse response.body
      #abort response.body.inspect
      return result_hash
  end


end
