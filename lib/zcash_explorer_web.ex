defmodule ZcashExplorerWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, live views, etc.
  """

  def static_paths, do: ~w(assets css fonts images js favicon.ico robots.txt privacy.html)

  def controller do
    quote do
      use Phoenix.Controller, namespace: ZcashExplorerWeb

      import Plug.Conn
      import Phoenix.Controller
      import ZcashExplorerWeb.Gettext

      alias ZcashExplorerWeb.Router.Helpers, as: Routes
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {ZcashExplorerWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      unquote(html_helpers())
    end
  end

  # Legacy support for old .View modules (block_view, address_view, etc.)
  def view do
    quote do
      use Phoenix.View,
        root: "lib/zcash_explorer_web/templates",
        namespace: ZcashExplorerWeb

      import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1]
      import Phoenix.Component

      # import ZcashExplorerWeb.ErrorHelpers
      import ZcashExplorerWeb.Gettext

      alias ZcashExplorerWeb.Router.Helpers, as: Routes
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.HTML.Form
      import Phoenix.Component

      import ZcashExplorerWeb.Gettext
      alias ZcashExplorerWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
