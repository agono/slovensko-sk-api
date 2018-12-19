class StatusController < ApplicationController
  def internal
    check_environment_variables
    check_database_connection
    check_worker_status

    check_api_token_key
    check_obo_token_key

    check_sp_certificate
    check_sts_certificate

    render status: :ok, json: { message: 'Internal systems operational' }
  rescue => error
    render status: :internal_server_error, json: { message: error.message }
  end

  def external
    check_ez_service
    check_sktalk_service

    render status: :ok, json: { message: 'External systems operational' }
  rescue => error
    render status: :internal_server_error, json: { message: error.message }
  end

  private

  def check_environment_variables
    variables = Rails.root.join('.env').read.lines.map { |v| v.split('=', 2).first if v.present? }.compact
    variables << 'DATABASE_URL'

    unset = variables.select { |v| ENV[v].blank? }

    raise "Unset environment variables #{unset.to_sentence}" if unset.any?
  rescue
    raise 'Unable to read environment variables'
  end

  def check_database_connection
    ActiveRecord::Base.establish_connection
  ensure
    raise 'Unable to establish database connection' unless ActiveRecord::Base.connected?
  end

  def check_worker_status
    beat = DelayedBeat.find_by(job_class: DownloadAllFormTemplatesJob.name)
    raise "Unbeaten #{beat.job_class} with last beat at #{beat.updated_at}" if beat && beat.updated_at < 28.hours.ago
  rescue
    raise 'Unable to acquire worker status'
  end

  def check_api_token_key
    Environment.api_token_authenticator # initializes API token authenticator with identifier cache and RSA public key
  rescue
    raise 'Unable to read API token key expiration'
  end

  def check_obo_token_key
    Environment.obo_token_authenticator # initializes OBO token authenticator with assertion store and RSA key pair
  rescue
    raise 'Unable to read OBO token key expiration'
  end

  def check_sp_certificate
    sp_ks = KeyStore.new(ENV.fetch('UPVS_SP_KS_FILE'), ENV.fetch('UPVS_SP_KS_PASSWORD'))
    sp_na = Time.parse(sp_ks.certificate(ENV.fetch('UPVS_SP_KS_ALIAS')).not_after.to_s)
    raise "SP certificate expires in #{sp_na}" if sp_na < 2.months.from_now
  rescue
    raise 'Unable to read SP certificate expiration'
  end

  def check_sts_certificate
    sts_ks = KeyStore.new(ENV.fetch('UPVS_STS_KS_FILE'), ENV.fetch('UPVS_STS_KS_PASSWORD'))
    sts_na = Time.parse(sts_ks.certificate(ENV.fetch('UPVS_STS_KS_ALIAS')).not_after.to_s)
    raise "STS certificate expires in #{sp_na}" if sts_na < 2.months.from_now
  rescue
    raise 'Unable to read STS certificate expiration'
  end

  def check_ez_service
    UpvsEnvironment.eform_service.fetch_all_form_template_ids # invokes EZ service with STS certificate
  rescue
    raise 'Unable to retrieve EZ service'
  end

  def check_sktalk_service
    UpvsEnvironment.upvs_proxy.sktalk # initializes SKTalk service with STS certificate
  rescue
    raise 'Unable to retrieve SKTalk service'
  end
end
