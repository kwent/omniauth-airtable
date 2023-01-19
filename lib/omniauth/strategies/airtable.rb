require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Airtable < OmniAuth::Strategies::OAuth2

      SITE_REGEXP = /(?:https:\/\/)?(?:([^.]+)\.)?airtable\.com/

      args %i[client_id client_secret]

      option :name, 'airtable'

      option :client_options, {
        site: "https://api.airtable.com",
        authorize_url: "https://airtable.com/oauth2/v1/authorize",
        token_url: "https://airtable.com/oauth2/v1/token",
      }

      option :pkce, true

      # When `true`, client_id and client_secret are returned in extra['raw_info'].
      option :extra_client_id_and_client_secret, false

      def request_phase
        super
      end

      def authorize_params
        super.tap do |params|
          %w[client_options].each do |v|
            if request.params[v]
              params[v.to_sym] = request.params[v]
            end
          end
        end
      end

      def build_access_token
        verifier = request.params["code"]
        # Override regular client when using setup: proc
        if env['omniauth.params']['client_id'] && env['omniauth.params']['client_secret']
          client = ::OAuth2::Client.new(
            env['omniauth.params']['client_id'],
            env['omniauth.params']['client_secret'],
            site: options.client_options.site,
            authorize_url: options.client_options.authorize_url,
            token_url: options.client_options.token_url
          )
          client.auth_code.get_token(verifier, {:redirect_uri => callback_url}.merge(token_params.merge!(headers: {'Authorization' => basic_auth_header(env['omniauth.params']['client_id'], env['omniauth.params']['client_secret']) }).to_hash(:symbolize_keys => true)), deep_symbolize(options.auth_token_params))
        else
          super
        end
      end

      uid { Digest::SHA2.hexdigest("#{me['id']}-#{access_token.client.id}") }

      extra do
        { raw_info: raw_info, me: me }
      end

      def raw_info
        @raw_info ||= options[:extra_client_id_and_client_secret] ? { client_id: smart_client_id, client_secret: smart_client_secret } : {}
      end

      def me
        access_token.options[:mode] = :header
        @me ||= access_token.get('v0/meta/whoami', :headers => { 'Content-Type' => 'application/json' }).parsed
      end

      def smart_client_id
        @smart_client_id ||= env['omniauth.params']['client_id'] || env['omniauth.strategy'].options.client_id
      end

      def smart_client_secret
        @smart_client_secret ||= env['omniauth.params']['client_secret'] || env['omniauth.strategy'].options.client_secret
      end

      def callback_url
        full_host + script_name + callback_path
      end

      def basic_auth_header(client_id, client_secret)
        "Basic " + Base64.strict_encode64("#{client_id}:#{client_secret}")
      end
    end
  end
end

OmniAuth.config.add_camelization 'airtable', 'Airtable'