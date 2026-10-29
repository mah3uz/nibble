class FormsController < ActionController::Base
  skip_forgery_protection

  REFILL_BYTES = 2000

  def create
    form = Nibble::Forms.find(request.path_parameters[:handle]) or return head(:not_found)
    result = Nibble::Forms::Submit.call(form, request.request_parameters, ip: request.remote_ip, user_agent: request.user_agent,
      locale:, query: request.query_parameters)
    json? ? respond_json(form, result) : respond_html(form, result)
  end

  private

  def locale = request.request_parameters["_locale"]

  def json? = request.format.json? || request.content_mime_type&.json?

  def respond_json(form, result)
    case result.status
    when :ok then render json: { ok: true, message: form.success(locale)["message"], redirect: form.success(locale)["redirect"] }, status: :created
    when :rate_limited then render json: { ok: false, errors: result.errors }, status: :too_many_requests
    else render json: { ok: false, errors: result.errors }, status: :unprocessable_entity
    end
  end

  def respond_html(form, result)
    if result.ok? && (target = form.success(locale)["redirect"].presence)
      return redirect_to(target, status: :see_other, allow_other_host: target.start_with?("http"))
    end

    flash[:nibble_form] = if result.ok?
      { "handle" => form.handle, "status" => "sent", "message" => form.success(locale)["message"] }
    else
      { "handle" => form.handle, "status" => "invalid", "errors" => result.errors.transform_values { |messages| Array(messages).first },
        "values" => refill(form, result.values) }
    end
    redirect_back_or_to "/", status: :see_other
  end

  # The session is a cookie, so what is handed back has to fit with the errors.
  def refill(form, values)
    left = REFILL_BYTES
    form.fields.all.values.each_with_object({}) do |field, kept|
      next if field.type == "files" || field.get("hidden") == true || field.get("input_type") == "password"

      value = values[field.handle]
      next if value.nil?
      next unless Array.wrap(value).all? { |item| item.is_a?(String) || item.is_a?(Numeric) || item == true || item == false }

      left -= value.to_json.bytesize
      kept[field.handle] = value if left >= 0
    end
  end
end
