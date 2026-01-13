defmodule OgImageWeb.ImageRenderer do
  @moduledoc """
  Functions responsible for rendering images.
  """

  import Phoenix.Controller
  import Phoenix.Template, only: [render_to_string: 4]
  import Plug.Conn

  alias OgImage.ImageCache
  alias OgImageWeb.ImageHTML

  @doc """
  Renders the image template as either a PNG or HTML response (depending on the path).
  """
  @spec render_image(Plug.Conn.t(), template :: atom()) :: Plug.Conn.t()
  def render_image(%{path_info: ["image"]} = conn, template) do
    image =
      if cache_enabled?() do
        maybe_get_cached_image(conn, template)
      else
        generate_image(conn, template)
      end

    conn
    |> put_resp_content_type("image/png", nil)
    |> put_resp_header(
      "cache-control",
      "public, immutable, no-transform, s-maxage=31536000, max-age=31536000"
    )
    |> send_resp(200, image)
  end

  # When the request path is `/preview`, return the HTML representation
  def render_image(%{path_info: ["preview"]} = conn, template) do
    render(conn, template)
  end

  # Private helpers

  defp maybe_get_cached_image(conn, template) do
    cache_key = generate_cache_key(conn)
    cache_dir = cache_dir()

    case ImageCache.get_path(cache_dir, cache_key) do
      nil ->
        generate_image(conn, template)

      path ->
        case File.read(path) do
          {:ok, data} -> Base.decode64!(data)
          {:error, _} -> generate_image(conn, template)
        end
    end
  end

  defp generate_image(conn, template) do
    assigns = Map.put(conn.assigns, :layout, {OgImageWeb.Layouts, "image"})
    html = render_to_string(ImageHTML, to_string(template), "html", assigns)
    image_data = NodeJS.call!("take-screenshot", [html], binary: true)

    if cache_enabled?() do
      cache_key = generate_cache_key(conn)
      cache_dir = cache_dir()
      ImageCache.put(cache_dir, cache_key, image_data, cache_max_bytes())
    end

    Base.decode64!(image_data)
  end

  defp generate_cache_key(%{query_string: query_string} = _conn) do
    version = Application.get_env(:og_image, :image_cache)[:version] || "1"

    query_string_hash =
      :sha256
      |> :crypto.hash(query_string)
      |> Base.url_encode64(padding: false)

    "#{version}.#{query_string_hash}"
  end

  defp cache_enabled? do
    !!Application.get_env(:og_image, :image_cache)[:enabled]
  end

  defp cache_max_bytes do
    Application.get_env(:og_image, :image_cache)[:max_bytes] || 1_000_000
  end

  defp cache_dir do
    Path.join(System.tmp_dir!(), "og_image_cache")
  end

  @doc """
  Renders an image by screenshotting a URL, optionally screenshotting just a specific element.
  """
  @spec render_url_image(Plug.Conn.t(), url :: String.t(), selector :: String.t() | nil) ::
          Plug.Conn.t()
  def render_url_image(%{path_info: ["image"]} = conn, url, selector) do
    image = generate_url_image(url, selector)

    conn
    |> put_resp_content_type("image/png", nil)
    |> put_resp_header(
      "cache-control",
      "public, immutable, no-transform, s-maxage=31536000, max-age=31536000"
    )
    |> send_resp(200, image)
  end

  def render_url_image(conn, _url, _selector) do
    conn
    |> put_status(:not_found)
    |> text("URL screenshots only available via /image endpoint")
  end

  defp generate_url_image(url, selector) do
    # Pass selector as nil if not provided, Node.js will handle it
    selector_arg = selector || nil
    image_data = NodeJS.call!("screenshot-url", [url, selector_arg], binary: true)
    Base.decode64!(image_data)
  end
