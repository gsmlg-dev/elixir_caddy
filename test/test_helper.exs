ExUnit.start()

Application.ensure_started(:mox)

Mox.defmock(Caddy.Admin.RequestMock, for: Caddy.Admin.RequestBehaviour)
Mox.defmock(Caddy.ConfigManagerMock, for: Caddy.ConfigManager.Behaviour)

Caddy.start()
