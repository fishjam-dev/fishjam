defmodule JellyfishWeb.ErrorView do
  use JellyfishWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".

  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def template_not_found(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
