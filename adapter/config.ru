#
# Forked from https://github.com/sorah/nginx_omniauth_adapter/blob/18495d60d88617e90f3c9cf387d315c8c7edc53a/config.ru
# Copyright (c) 2015 Shota Fukumori (sora_h)
#

require 'nginx_omniauth_adapter'
require 'omniauth'
require 'open-uri'
require 'json'

if !ENV['NGX_OMNIAUTH_SESSION_SECRET']
  raise 'You should specify $NGX_OMNIAUTH_SESSION_SECRET'
end

allowed_app_callback_url =
  if ENV['NGX_OMNIAUTH_ALLOWED_APP_CALLBACK_URL']
    Regexp.new(ENV['NGX_OMNIAUTH_ALLOWED_APP_CALLBACK_URL'])
  else
    nil
  end

allowed_back_to_url =
  if ENV['NGX_OMNIAUTH_ALLOWED_BACK_TO_URL']
    Regexp.new(ENV['NGX_OMNIAUTH_ALLOWED_BACK_TO_URL'])
  else
    nil
  end

use(
  Rack::Session::Cookie,
  key:          ENV['NGX_OMNIAUTH_SESSION_COOKIE_NAME'] || 'ngx_omniauth',
  expire_after: ENV['NGX_OMNIAUTH_SESSION_COOKIE_TIMEOUT'] ? ENV['NGX_OMNIAUTH_SESSION_COOKIE_TIMEOUT'].to_i : (60 * 60 * 24 * 3),
  secret:       ENV['NGX_OMNIAUTH_SESSION_SECRET'] || 'ngx_omniauth_secret_dev',
  old_secret:   ENV['NGX_OMNIAUTH_SESSION_SECRET_OLD'],
)

providers = []

gh_teams = ENV['NGX_OMNIAUTH_GITHUB_TEAMS'] && ENV['NGX_OMNIAUTH_GITHUB_TEAMS'].split(/[, ]/)
gh_orgs = ENV['NGX_OMNIAUTH_GITHUB_ORGS'] && ENV['NGX_OMNIAUTH_GITHUB_ORGS'].split(/[, ]/)

use OmniAuth::Builder do
  configure do |config|
    config.full_host = ENV['NGX_OMNIAUTH_HOST']
  end

  if ENV['NGX_OMNIAUTH_SLACK_KEY'] && ENV['NGX_OMNIAUTH_SLACK_SECRET']
    require 'omniauth-slack'
    team_id = ENV['NGX_OMNIAUTH_SLACK_TEAM_ID'] || nil
    provider :slack, ENV['NGX_OMNIAUTH_SLACK_KEY'], ENV['NGX_OMNIAUTH_SLACK_SECRET'], scope: 'identity.basic', team: team_id
    providers << :slack
  end

  if ENV['NGX_OMNIAUTH_GITHUB_KEY'] && ENV['NGX_OMNIAUTH_GITHUB_SECRET']
    require 'omniauth-github'
    gh_client_options = {}
    if ENV['NGX_OMNIAUTH_GITHUB_HOST']
      gh_client_options[:site] = "#{ENV['NGX_OMNIAUTH_GITHUB_HOST']}/api/v3"
      gh_client_options[:authorize_url] = "#{ENV['NGX_OMNIAUTH_GITHUB_HOST']}/login/oauth/authorize"
      gh_client_options[:token_url] = "#{ENV['NGX_OMNIAUTH_GITHUB_HOST']}/login/oauth/access_token"
    end

    gh_scope = ''
    if ENV['NGX_OMNIAUTH_GITHUB_TEAMS'] || ENV['NGX_OMNIAUTH_GITHUB_ORGS']
      gh_scope = 'read:org'
    end

    provider :github, ENV['NGX_OMNIAUTH_GITHUB_KEY'], ENV['NGX_OMNIAUTH_GITHUB_SECRET'], client_options: gh_client_options, scope: gh_scope
    providers << :github
  end
end

run NginxOmniauthAdapter.app(
  providers: providers,
  secret: ENV['NGX_OMNIAUTH_SECRET'],
  host: ENV['NGX_OMNIAUTH_HOST'],
  allowed_app_callback_url: allowed_app_callback_url,
  allowed_back_to_url: allowed_back_to_url,
  app_refresh_interval: ENV['NGX_OMNIAUTH_APP_REFRESH_INTERVAL'] && ENV['NGX_OMNIAUTH_APP_REFRESH_INTERVAL'].to_i,
  adapter_refresh_interval: ENV['NGX_OMNIAUTH_ADAPTER_REFRESH_INTERVAL'] && ENV['NGX_OMNIAUTH_APP_REFRESH_INTERVAL'].to_i,
  policy_proc: proc {
    if current_user[:provider] == 'slack' && ENV['NGX_OMNIAUTH_SLACK_TEAM_ID']
      unless (current_user[:info].team_id == ENV['NGX_OMNIAUTH_SLACK_TEAM_ID'])
        next false
      end
    end

    if current_user[:provider] == 'github'
      if gh_teams
        unless (current_user_data[:gh_teams] || []).any? { |team| gh_teams.include?(team) }
          next false
        end
      end

      if gh_orgs
        unless (current_user_data[:gh_orgs] || []).any? { |org| gh_orgs.include?(org) }
          next false
        end
      end
    end

    true
  },
  on_login_proc: proc {
    auth = env['omniauth.auth']
    case auth[:provider]
    when 'github'
      if gh_teams
        api_host = ENV['NGX_OMNIAUTH_GITHUB_HOST'] ? "#{ENV['NGX_OMNIAUTH_GITHUB_HOST']}/api/v3" : "https://api.github.com"
        current_user_data[:gh_teams] = open("#{api_host}/user/teams", 'Authorization' => "token #{auth['credentials']['token']}") { |io|
          JSON.parse(io.read).map {|_| "#{_['organization']['login']}/#{_['slug']}" }.select { |team| gh_teams.include?(team) }
        }
      end

      if gh_orgs
        api_host = ENV['NGX_OMNIAUTH_GITHUB_HOST'] ? "#{ENV['NGX_OMNIAUTH_GITHUB_HOST']}/api/v3" : "https://api.github.com"
        current_user_data[:gh_orgs] = open("#{api_host}/user/orgs", 'Authorization' => "token #{auth['credentials']['token']}") { |io|
          JSON.parse(io.read).map {|_| "#{_['login']}" }.select { |org| gh_orgs.include?(org) }
        }
      end
    end

    true
  },
)
