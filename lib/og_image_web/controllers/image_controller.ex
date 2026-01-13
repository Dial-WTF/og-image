defmodule OgImageWeb.ImageController do
  use OgImageWeb, :controller

  import OgImageWeb.ImageHelpers
  import OgImageWeb.ImageRenderer

  def show(conn, %{"template" => "light", "text" => text}) do
    conn
    |> assign(:text, prepare_html(text))
    |> render_image(:light)
  end

  def show(conn, %{"template" => "dark", "text" => text}) do
    conn
    |> assign(:text, prepare_html(text))
    |> render_image(:dark)
  end

  def show(conn, %{"template" => "dial_dark", "text" => text}) do
    conn
    |> assign(:text, text)
    |> assign(:text_html, prepare_text_with_gradient(text))
    |> render_image(:dial_dark)
  end

  def show(conn, %{"template" => "dial_light", "text" => text}) do
    conn
    |> assign(:text, prepare_html(text))
    |> render_image(:dial_light)
  end

  # Screenshot from URL
  def show(conn, %{"url" => url}) do
    selector = Map.get(conn.params, "selector")
    render_url_image(conn, url, selector)
  end

  # -- Add more templates here --

  def show(conn, _params) do
    render_image(conn, :fallback)
  end
end
