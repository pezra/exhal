ExUnit.start
Application.ensure_all_started(:mox)

Mox.defmock(ExHal.ClientMock, for: ExHal.Client)

Application.put_env(:exhal, :client, ExHal.ClientMock)
