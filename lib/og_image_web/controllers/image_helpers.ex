defmodule OgImageWeb.ImageHelpers do
  @moduledoc """
  A collection of helpers for preparing template data.
  """

  alias HtmlSanitizeEx.Scrubber

  @doc """
  Convert emojis to <img> tags.
  """
  @spec emojify(value :: any()) :: String.t() | nil
  def emojify(value) when is_binary(value) do
    NodeJS.call!("emojify", [value], binary: true)
  end

  def emojify(_), do: nil

  @doc """
  Takes input that might contain HTML and prepares it for rendering by scrubbing
  any unacceptable tags and converting emoji to images.
  """
  @spec prepare_html(value :: any(), default :: any()) :: Phoenix.HTML.safe() | nil
  def prepare_html(value, default \\ nil)

  def prepare_html(value, _default) when is_binary(value) and value != "" do
    value
    |> Scrubber.scrub(OgImage.Scrubber)
    |> emojify()
    |> Phoenix.HTML.raw()
  end

  def prepare_html(_, default) when is_binary(default), do: Phoenix.HTML.raw(default)
  def prepare_html(_, default), do: default

  @doc """
  Splits text and applies gradient styling to "From your wallet." part.
  Returns HTML-safe string with gradient applied.
  """
  @spec prepare_text_with_gradient(value :: any()) :: Phoenix.HTML.safe() | nil
  def prepare_text_with_gradient(value) when is_binary(value) do
    # Check if text contains "From your wallet." pattern
    if String.contains?(value, "From your wallet.") do
      # Split and rebuild with gradient
      [before, rest] = String.split(value, "From your wallet.", parts: 2)
      
      before_html = if before != "", do: Phoenix.HTML.safe_to_string(prepare_html(before)), else: ""
      rest_html = if rest != "", do: Phoenix.HTML.safe_to_string(prepare_html(rest)), else: ""
      
      gradient_html = ~s(<span class="bg-gradient-to-r from-cyan-400 to-emerald-400 bg-clip-text text-transparent">From your wallet.</span>)
      
      Phoenix.HTML.raw("#{before_html}#{gradient_html}#{rest_html}")
    else
      # No gradient pattern, return normal HTML
      prepare_html(value)
    end
  end

  def prepare_text_with_gradient(_), do: nil
end
