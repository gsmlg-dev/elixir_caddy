defmodule Caddy.Admin.RequestBehaviour do
  @moduledoc """
  A behaviour for Caddy Admin requests.
  """

  alias Caddy.Admin.Request

  @type response_body :: map() | list() | binary()
  @type result :: {:ok, Request.t(), response_body()} | {:error, term()}

  @callback get(path :: binary()) :: result()
  @callback get(path :: binary(), headers :: list()) :: result()
  @callback post(path :: binary(), data :: binary(), content_type :: binary()) ::
              result()
  @callback post(path :: binary(), data :: binary(), content_type :: binary(), headers :: list()) ::
              result()
  @callback patch(path :: binary(), data :: binary(), content_type :: binary()) ::
              result()
  @callback patch(path :: binary(), data :: binary(), content_type :: binary(), headers :: list()) ::
              result()
  @callback put(path :: binary(), data :: binary(), content_type :: binary()) ::
              result()
  @callback put(path :: binary(), data :: binary(), content_type :: binary(), headers :: list()) ::
              result()
  @callback delete(path :: binary(), data :: binary(), content_type :: binary()) ::
              result()
  @callback delete(
              path :: binary(),
              data :: binary(),
              content_type :: binary(),
              headers :: list()
            ) ::
              result()
end
