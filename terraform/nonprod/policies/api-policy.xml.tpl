<!--
  policies/api-policy.xml.tpl
  Combined APIM inbound + outbound policy — rendered by Terraform templatefile().

  Merges:
    - rate-limit-policy  (inbound:  JWT validation, rate limit, quota, CORS, header enrichment)
    - transform-response (outbound: JSON field stripping, security headers, App Insights metrics)

  Template variables (injected by apim.tf):
    tenant_id       - Azure AD / Entra ID tenant GUID
    audience        - App registration client ID used as the API audience
    allowed_origins - list(string) of permitted CORS origins
-->
<policies>
  <inbound>
    <base />

    <!--
      1. JWT Validation
      Validates Bearer tokens issued by Azure AD / Entra ID.
    -->
    <validate-jwt
        header-name="Authorization"
        failed-validation-httpcode="401"
        failed-validation-error-message="Unauthorized: valid Azure AD token required."
        require-expiration-time="true"
        require-scheme="Bearer"
        require-signed-tokens="true">

      <openid-config url="https://login.microsoftonline.com/${tenant_id}/v2.0/.well-known/openid-configuration" />

      <audiences>
        <audience>api://${audience}</audience>
      </audiences>

      <issuers>
        <issuer>https://sts.windows.net/${tenant_id}/</issuer>
        <issuer>https://login.microsoftonline.com/${tenant_id}/v2.0</issuer>
      </issuers>

      <!-- Require at least one of these scopes -->
      <required-claims>
        <claim name="scp" match="any">
          <value>Packages.Read</value>
          <value>Packages.ReadWrite</value>
        </claim>
      </required-claims>
    </validate-jwt>

    <!--
      2. Rate Limiting — 1,000 calls per 5-minute window per subscription key
    -->
    <rate-limit calls="1000" renewal-period="300">
      <set-header name="Retry-After" exists-action="override">
        <value>@(context.Response.Headers.GetValueOrDefault("Retry-After", "60"))</value>
      </set-header>
    </rate-limit>

    <!-- Monthly hard cap -->
    <quota calls="500000" renewal-period="2592000" />

    <!--
      3. CORS — origins injected from Terraform variable apim_cors_origins
    -->
    <cors allow-credentials="true">
      <allowed-origins>
%{ for origin in allowed_origins ~}
        <origin>${origin}</origin>
%{ endfor ~}
      </allowed-origins>
      <allowed-methods preflight-result-max-age="300">
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
        <method>PATCH</method>
        <method>DELETE</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>Content-Type</header>
        <header>Authorization</header>
        <header>X-Request-ID</header>
      </allowed-headers>
      <expose-headers>
        <header>X-Request-ID</header>
        <header>X-Rate-Limit-Remaining</header>
      </expose-headers>
    </cors>

    <!--
      4. Enrich backend request
      Forward the caller's object ID and subscription name for audit logging.
    -->
    <set-header name="X-Caller-Object-Id" exists-action="override">
      <value>@(context.Request.Headers.GetValueOrDefault("Authorization","").Split(' ').Last()
               .Split('.')[1]
               .PadRight(((int)Math.Ceiling(context.Request.Headers.GetValueOrDefault("Authorization","").Split(' ').Last().Split('.')[1].Length / 4.0)) * 4, '=')
               |> Convert.FromBase64String
               |> System.Text.Encoding.UTF8.GetString
               |> Newtonsoft.Json.Linq.JObject.Parse
               |> (o => o["oid"]?.ToString() ?? "unknown"))</value>
    </set-header>

    <set-header name="X-Subscription-Name" exists-action="override">
      <value>@(context.Subscription.Name)</value>
    </set-header>

    <!-- Propagate or generate a request correlation ID -->
    <set-header name="X-Request-ID" exists-action="skip">
      <value>@(Guid.NewGuid().ToString())</value>
    </set-header>

    <set-backend-service backend-id="backend-fastapi" />

  </inbound>

  <backend>
    <base />
  </backend>

  <outbound>
    <base />

    <!--
      5. Transform JSON response body
      - Strip internal fields (internal_ref, _etag) — never expose to external callers
      - Rename "owner" → "team" for v1 client backwards compatibility
      Only applies to 200-series responses with a JSON body.
    -->
    <choose>
      <when condition="@(context.Response.StatusCode >= 200 && context.Response.StatusCode < 300
                         && context.Response.Headers.GetValueOrDefault(&quot;Content-Type&quot;,&quot;&quot;)
                                                     .Contains(&quot;application/json&quot;))">
        <set-body>@{
          var body = context.Response.Body.As<JObject>(preserveContent: true);

          if (body != null)
          {
            body.Remove("internal_ref");
            body.Remove("_etag");

            if (body["owner"] != null)
            {
              body["team"] = body["owner"];
              body.Remove("owner");
            }

            return body.ToString(Newtonsoft.Json.Formatting.None);
          }

          // Array wrapper — e.g. GET /packages returns { items: [...] }
          var wrapper = context.Response.Body.As<JObject>(preserveContent: true);
          if (wrapper?["items"] is JArray items)
          {
            foreach (JObject item in items)
            {
              item.Remove("internal_ref");
              item.Remove("_etag");
              if (item["owner"] != null)
              {
                item["team"] = item["owner"];
                item.Remove("owner");
              }
            }
            return wrapper.ToString(Newtonsoft.Json.Formatting.None);
          }

          return context.Response.Body.As<string>(preserveContent: true);
        }</set-body>
      </when>
    </choose>

    <!--
      6. Security and cache-control headers
    -->
    <set-header name="Cache-Control" exists-action="override">
      <value>no-store, no-cache, must-revalidate</value>
    </set-header>

    <set-header name="X-Content-Type-Options" exists-action="override">
      <value>nosniff</value>
    </set-header>

    <set-header name="X-Frame-Options" exists-action="override">
      <value>DENY</value>
    </set-header>

    <set-header name="Strict-Transport-Security" exists-action="override">
      <value>max-age=31536000; includeSubDomains</value>
    </set-header>

    <!-- Echo the correlation ID set during inbound processing -->
    <set-header name="X-Request-ID" exists-action="override">
      <value>@(context.Request.Headers.GetValueOrDefault("X-Request-ID", Guid.NewGuid().ToString()))</value>
    </set-header>

    <!--
      7. Emit custom telemetry to Application Insights
      Tracks response time and status for SLA monitoring.
    -->
    <emit-metric name="api-response-time" value="@((double)context.Elapsed.TotalMilliseconds)">
      <dimension name="api-name"       value="@(context.Api.Name)" />
      <dimension name="operation-name" value="@(context.Operation.Name)" />
      <dimension name="status-code"    value="@(context.Response.StatusCode.ToString())" />
      <dimension name="subscription"   value="@(context.Subscription.Name)" />
    </emit-metric>

  </outbound>

  <on-error>
    <base />
    <!-- Return a consistent error envelope on policy failures -->
    <set-status code="@(context.Response.StatusCode)" reason="@(context.Response.StatusReason)" />
    <set-body>@{
      return new JObject(
        new JProperty("errors", new JArray(
          new JObject(
            new JProperty("code",    context.Response.StatusCode.ToString()),
            new JProperty("message", context.Response.StatusReason),
            new JProperty("requestId", context.Request.Headers.GetValueOrDefault("X-Request-ID",""))
          )
        ))
      ).ToString();
    }</set-body>
  </on-error>

</policies>
