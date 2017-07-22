# 3846masa/nginx-omniauth-adapter

Docker image Slack/GitHub auth adapter using [sorah/nginx_omniauth_adapter].

[sorah/nginx_omniauth_adapter]: https://github.com/sorah/nginx_omniauth_adapter

## Usage

1. Copy `auth.example.env` to `auth.env`.
2. Configure `auth.env`.
3. (Optional) Add `ports` config in `docker-compose.yml` if needed.
4. Run `docker-compose up -d`.
5. Set up nginx config (See [here][nginx-config] for details).

[nginx-config]: http://techlife.cookpad.com/entry/2015/10/16/080000

### With [jwilder/nginx-proxy]

1. Copy `auth.example.env` to `auth.env`.
2. Configure `auth.env`.
  - Don't forget to set `VIRTUAL_HOST`.
3. Copy `vhost.d` files (See [here][vhost.d] for details).
  - If you requires auth in `foo.example.com`,
    - Copy `foo.example.com` to `vhost.d/[YOUR_DOMAIN]`.
    - Copy `foo.example.com_location` to `vhost.d/[YOUR_DOMAIN]_location`.
4. Run `docker-compose up -d -f ./docker-compose.with-proxy.yml`.

[jwilder/nginx-proxy]: https://github.com/jwilder/nginx-proxy
[vhost.d]: https://github.com/jwilder/nginx-proxy#custom-nginx-configuration

## LICENSE

MIT License

(c) 2017 3846masa
