defmodule Caddy.Admin.RequestBehaviour do
  @moduledoc """
  A behaviour for Caddy Admin requests.
  """

  alias Caddy.Admin.Request

  @callback get(path :: binary()) :: {:ok, Request.t(), map() | binary()}
  @callback post(path :: binary(), data :: binary(), content_type :: binary()) ::
              {:ok, Request.t(), map() | binary()}
  @callback patch(path :: binary(), data :: binary(), content_type :: binary()) ::
              {:ok, Request.t(), map() | binary()}
  @callback put(path :: binary(), data :: binary(), content_type :: binary()) ::
              {:ok, Request.t(), map() | binary()}
  @callback delete(path :: binary(), data :: binary(), content_type :: binary()) ::
              {:ok, Request.t(), map() | binary()}
end
