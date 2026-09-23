class FormsController < ActionController::Base
  skip_forgery_protection

  def create
    form = Nibble::Forms.find(request.path_parameters[:handle]) or return head(:not_found)
    result = Nibble::Forms::Submit.call(form, request.request_parameters, ip: request.remote_ip, user_agent: request.user_agent,
      locale: request.request_parameters["_locale"])
    json? ? respond_json(form, result) : respond_html(form, result)
  end

  private

  def json? = request.format.json? || request.content_mime_type&.json?

  def respond_json(form, result)
    case result.status
    when :ok then render json: { ok: true, message: form.success["message"], redirect: form.success["redirect"] }, status: :created
    when :rate_limited then render json: { ok: false, errors: result.errors }, status: :too_many_requests
    else render json: { ok: false, errors: result.errors }, status: :unprocessable_entity
    end
  end

  def respond_html(form, result)
    if result.ok? && (target = form.success["redirect"].presence)
      return redirect_to(target, status: :see_other, allow_other_host: target.start_with?("http"))
    end

    flash[:nibble_form] = if result.ok?
      { "handle" => form.handle, "status" => "sent", "message" => form.success["message"] }
    else
      { "handle" => form.handle, "status" => "invalid", "errors" => result.errors.transform_values { |messages| Array(messages).first } }
    end
    redirect_back_or_to "/", status: :see_other
  end
end
