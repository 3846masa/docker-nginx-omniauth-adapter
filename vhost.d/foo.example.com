location = /_auth/challenge {
  internal;

  proxy_pass_request_body off;
  proxy_set_header Content-Length "";
  proxy_set_header Host $http_host;

  proxy_pass http://adapter:8080/test;
  break;
}

location = /_auth/initiate {
  internal;
  proxy_pass_request_body off;
  proxy_set_header Content-Length "";
  proxy_set_header Host $http_host;
  proxy_set_header x-ngx-omniauth-initiate-back-to https://$http_host$request_uri;
  proxy_set_header x-ngx-omniauth-initiate-callback https://$http_host/_auth/callback;
  proxy_pass http://adapter:8080/initiate;
  break;
}

location = /_auth/callback {
  auth_request off;

  proxy_set_header Host $http_host;

  proxy_pass http://adapter:8080/callback;
  break;
}

