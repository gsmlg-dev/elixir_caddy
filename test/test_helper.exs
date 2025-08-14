ExUnit.start()

Application.ensure_started(:mox)

Mox.defmock(Caddy.Admin.RequestMock, for: Caddy.Admin.RequestBehaviour)

Caddy.start()
