defmodule JellyfishWeb.Router do
  use JellyfishWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug :bearer_auth
  end

  scope "/room", JellyfishWeb do
    pipe_through :api

    resources("/", RoomController,
      only: [:create, :index, :show, :delete],
      param: "room_id"
    )

    resources("/:room_id/peer", PeerController, only: [:create, :delete])
    resources("/:room_id/component", ComponentController, only: [:create, :delete])
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:jellyfish, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: JellyfishWeb.Telemetry
    end

    pipeline :open_api_spec do
      plug OpenApiSpex.Plug.PutApiSpec, module: JellyfishWeb.ApiSpec
    end

    scope "/" do
      pipe_through :open_api_spec
      get "/openapi.json", OpenApiSpex.Plug.RenderSpec, []
      get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/openapi.json"
    end
  end

  def bearer_auth(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         true <- token == Application.fetch_env!(:jellyfish, :token) do
      conn
    else
      false ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:unauthorized)
        |> json(%{errors: "Invalid token"})
        |> halt()

      _other ->
        conn
        |> put_resp_content_type("application/json")
        |> put_status(:unauthorized)
        |> json(%{errors: "Missing token"})
        |> halt()
    end
  end
end
