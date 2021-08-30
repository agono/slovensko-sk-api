# See https://tools.ietf.org/html/rfc7519

class OboTokenAuthenticator
  def initialize(assertion_store:, key_pair:, proxy_subject:)
    @assertion_store = assertion_store
    @key_pair = key_pair
    @proxy_subject = proxy_subject
  end

  def generate_token(response, scopes: [])
    assertion = parse_assertion(response)

    sub = response.attributes['SubjectID'].to_s
    exp = response.not_on_or_after.to_i
    nbf = response.not_before.to_i
    iat = assertion.attributes['IssueInstant'].to_time.to_i

    name = response.attributes['Subject.FormattedName'].to_s
    scopes = scopes.to_a

    now = Time.now.to_f

    raise ArgumentError, :exp if exp <= now
    raise ArgumentError, :nbf if nbf > now
    raise ArgumentError, :iat if iat > nbf

    ass = assertion_to_s(assertion)

    loop do
      jti = SecureRandom.uuid

      payload = { sub: sub, exp: exp, nbf: nbf, iat: iat, jti: jti, name: name, scopes: scopes }
      exp_in = exp - Time.now.to_f

      raise ArgumentError, :exp if exp_in <= 0

      next unless @assertion_store.write(jti, ass, expires_in: exp_in, unless_exist: true)

      begin
        return JWT.encode(payload, @key_pair, 'RS256')
      rescue => error
        @assertion_store.delete(jti) and raise(error)
      end
    end
  end

  def invalidate_token(token)
    verify_token(token) do |payload, _|
      result = @assertion_store.delete(payload['jti'])
      result && result.to_s != '0'
    end
  end

  def verify_token(token, scope: nil)
    options = {
      algorithm: 'RS256',
      verify_expiration: false,
      verify_not_before: false,
      verify_iat: false,
      verify_jti: true,
    }

    payload, header = JWT.decode(token, @key_pair.public_key, true, options)
    exp, nbf, iat, jti = payload['exp'], payload['nbf'], payload['iat'], payload['jti']

    raise JWT::InvalidPayload, :exp unless exp.is_a?(Integer)
    raise JWT::InvalidPayload, :nbf unless nbf.is_a?(Integer)
    raise JWT::InvalidPayload, :iat unless iat.is_a?(Integer)

    now = Time.now.to_f

    raise JWT::ExpiredSignature, :exp if exp <= now
    raise JWT::ImmatureSignature, :nbf if nbf > now
    raise JWT::InvalidIatError, :iat if iat > nbf

    scopes = payload['scopes'].to_a

    raise JWT::InvalidPayload, :scope if scope && scopes.exclude?(scope)

    ass = @assertion_store.read(jti)

    raise JWT::InvalidJtiError unless ass

    return yield payload, header if block_given?

    [@proxy_subject, ass]
  end

  private

  def parse_assertion(response)
    document = response.decrypted_document || response.document
    assertion = REXML::XPath.first(document, '//saml:Assertion')

    raise ArgumentError unless assertion

    # force namespaces directly on element, otherwise they are not present
    assertion.namespaces.slice('dsig', 'saml', 'xsi').each do |prefix, uri|
      assertion.add_namespace(prefix, uri)
    end

    # force double quotes on attributes, actually preserve response format
    assertion.context[:attribute_quote] = :quote

    assertion
  end

  def assertion_to_s(assertion)
    formatter = REXML::Formatters::Pretty.new(0)
    formatter.compact = true
    formatter.write(assertion, buffer = '')
    buffer.remove("\n")
  end
end
