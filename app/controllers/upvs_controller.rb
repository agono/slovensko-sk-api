class UpvsController < ApiController
  def login
    session[:login_callback_url] = fetch_callback_url(:login, Environment.login_callback_urls)

    redirect_to '/auth/saml'
  end

  def callback
    response = request.env['omniauth.auth']['extra']['response_object']
    scopes = ['sktalk/receive', 'sktalk/receive_and_save_to_outbox']
    token = Environment.obo_token_authenticator.generate_token(response, scopes: scopes)

    redirect_to callback_url_with_token(session[:login_callback_url], token)
  end

  def logout
    if params[:SAMLRequest]
      redirect_to "/auth/saml/slo?#{slo_request_params.to_query}"
    elsif params[:SAMLResponse]
      redirect_to "/auth/saml/slo?#{slo_response_params(session[:logout_callback_url]).to_query}"
    else
      Environment.api_token_authenticator.invalidate_token(authenticity_token, obo: true)
      session[:logout_callback_url] = fetch_callback_url(:logout, Environment.logout_callback_urls)

      redirect_to '/auth/saml/spslo'
    end
  end

  CallbackError = Class.new(StandardError)

  rescue_from(CallbackError) { |error| render_bad_request(error.message) }

  private

  def fetch_callback_url(action, registered_urls)
    raise CallbackError, "No #{action} callback" if params[:callback].blank?
    raise CallbackError, "Unregistered #{action} callback" if registered_urls.none? { |url| params[:callback] =~ url }
    params[:callback]
  end

  def callback_url_with_token(callback_url, token)
    URI.parse(callback_url).tap { |url| url.query = [url.query, "token=#{token}"].compact.join('&') }.to_s
  end

  def slo_request_params
    params.permit(:SAMLRequest, :SigAlg, :Signature)
  end

  def slo_response_params(redirect_url)
    params.permit(:SAMLResponse, :SigAlg, :Signature).merge(RelayState: redirect_url)
  end
end
