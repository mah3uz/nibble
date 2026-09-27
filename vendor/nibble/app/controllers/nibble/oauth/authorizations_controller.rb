module Nibble
  module Oauth
    class AuthorizationsController < Nibble::Cp::BaseController
      PENDING_FOR = 10.minutes
      KEEP_PENDING = 3

      content_security_policy { |policy| policy.frame_ancestors :none }
      before_action { response.headers["X-Frame-Options"] = "DENY" }
      before_action { response.headers["Cache-Control"] = "no-store" }
      before_action :require_agent_access
      before_action :require_device_sign_in, only: %i[device lookup]
      rate_limit to: 10, within: 10.minutes, only: :lookup, with: -> { refuse("Too many codes tried. Wait a few minutes and try again.") }

      def new
        client = Nibble::Oauth.client!(params[:client_id])
        redirect_uri = params[:redirect_uri].to_s
        return refuse("The app asked to send you back to an address it didn't register.") unless client.allows_redirect?(redirect_uri)
        return back(redirect_uri, "unsupported_response_type", "response_type must be code") unless params[:response_type] == "code"
        unless params[:code_challenge_method] == "S256" && params[:code_challenge].to_s.match?(/\A[A-Za-z0-9_-]{43}\z/)
          return back(redirect_uri, "invalid_request", "PKCE with code_challenge_method S256 is required")
        end

        resource = Nibble::Oauth.resource!(request, params[:resource])
        return refuse("Your role can't connect apps. Ask an administrator.") unless Nibble::Access.can?(Nibble::Current.user, "apps.connect")

        id = remember("client_id" => client.client_id, "redirect_uri" => redirect_uri, "code_challenge" => params[:code_challenge],
          "state" => params[:state], "resource" => resource)
        render inertia: "cp/oauth/Authorize", props: consent_props(client, id, redirect_host: URI.parse(redirect_uri).host)
      rescue Nibble::Oauth::Error => error
        error.code == "invalid_target" ? back(redirect_uri, error.code, error.message) : refuse(error.message)
      end

      def create
        pending = recall(params[:request_id]) or return refuse("This request has expired. Start again from the app.")
        client = OauthClient.find_by!(client_id: pending["client_id"])
        device = pending["device_code_id"] && DeviceCode.pending.find_by(id: pending["device_code_id"])
        return refuse("This code has expired. Start again from the app.") if pending["device_code_id"] && device.nil?
        return decline(pending, device) unless params[:decision] == "approve"
        return refuse("Your role can't connect apps. Ask an administrator.") unless Nibble::Access.can?(Nibble::Current.user, "apps.connect")

        preset = params[:preset].to_s
        abilities = Consent.new(Nibble::Current.user, device: device.present?).abilities(preset, params[:areas]&.to_unsafe_h)
        if preset == "everything" && !elevated?
          return redirect_back_or_to cp_root_path, inertia: { errors: { preset: "Confirm your password to give an app everything you can do." } }
        end

        grant = Grant.create!(user: Nibble::Current.user, oauth_client: client, kind: "app", name: client.known_name || client.name,
          preset:, abilities:, via: device ? "device" : "browser")
        forget(params[:request_id])
        Nibble::Records::Notification.notify(Nibble::Current.user.id, "apps.connected", title: grant.name)
        return finish_device(device, grant) if device

        code = OauthCode.issue(grant:, redirect_uri: pending["redirect_uri"], code_challenge: pending["code_challenge"], resource: pending["resource"])
        leave Nibble::Oauth.redirect_with(pending["redirect_uri"], code:, state: pending["state"], iss: Nibble::Oauth.issuer(request))
      rescue Nibble::Oauth::Error => error
        redirect_back_or_to cp_root_path, inertia: { errors: { preset: error.message } }
      end

      def device
        render inertia: "cp/oauth/Device", props: { code: params[:code].to_s.first(20) }
      end

      def lookup
        device = DeviceCode.pending.find_by(user_code: DeviceCode.normalize(params[:code]))
        return redirect_to("/cp/device", inertia: { errors: { code: "That code isn't valid, or it has expired." } }) unless device
        return refuse("Your role can't connect apps. Ask an administrator.") unless Nibble::Access.can?(Nibble::Current.user, "apps.connect")

        id = remember("client_id" => device.oauth_client.client_id, "device_code_id" => device.id)
        render inertia: "cp/oauth/Authorize", props: consent_props(device.oauth_client, id, redirect_host: nil, device:)
      end

      private

      def require_device_sign_in
        refuse("Signing in with a code is turned off on this site. Sign in from a browser on the same computer instead.") unless AgentAccess.device_sign_in?
      end

      def require_agent_access
        refuse("Connecting apps is turned off on this site. An administrator can turn it on under Agent access.") unless AgentAccess.enabled?
      end

      def consent_props(client, id, redirect_host:, device: nil)
        consent = Consent.new(Nibble::Current.user, device: device.present?)
        { request_id: id, site: Nibble::Oauth.site_name, presets: consent.presets, areas: consent.areas, elevated: elevated?,
          client: { name: client.name, known: client.known_name, client_id: client.client_id, id_host: client.id_host,
                    redirect_host:, loopback: client.loopback_only?, verified: client.verified? },
          device: device && { code: device.display_code, ip: device.requested_ip } }
      end

      def decline(pending, device)
        forget(params[:request_id])
        if device
          device.update!(status: "denied")
          return render inertia: "cp/oauth/Done", props: { approved: false }
        end

        leave Nibble::Oauth.redirect_with(pending["redirect_uri"], error: "access_denied", state: pending["state"], iss: Nibble::Oauth.issuer(request))
      end

      def finish_device(device, grant)
        device.update!(grant:, status: "approved")
        render inertia: "cp/oauth/Done", props: { approved: true, name: grant.name }
      end

      def remember(values)
        pending = session[:oauth_requests].to_h.select { |_, item| Time.zone.parse(item["expires_at"].to_s)&.future? }
        id = SecureRandom.hex(16)
        pending[id] = values.merge("expires_at" => PENDING_FOR.from_now.iso8601)
        session[:oauth_requests] = pending.to_a.last(KEEP_PENDING).to_h
        id
      end

      def recall(id)
        item = session[:oauth_requests].to_h[id.to_s]
        item if item && Time.zone.parse(item["expires_at"].to_s)&.future?
      end

      def forget(id) = session[:oauth_requests] = session[:oauth_requests].to_h.except(id.to_s)

      def back(redirect_uri, error, description)
        leave Nibble::Oauth.redirect_with(redirect_uri, error:, error_description: description, state: params[:state], iss: Nibble::Oauth.issuer(request))
      end

      def leave(url) = request.inertia? ? inertia_location(url) : redirect_to(url, allow_other_host: true)

      def refuse(message) = render(inertia: "cp/oauth/Refused", props: { message: }, status: :bad_request)
    end
  end
end
