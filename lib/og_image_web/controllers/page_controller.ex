defmodule OgImageWeb.PageController do
  use OgImageWeb, :controller

  def home(conn, _params) do
    conn
    |> assign(:page_title, "Open Graph Image Generator for Dial")
    |> render(:home, layout: false)
  end
end
