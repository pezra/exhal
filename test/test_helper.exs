ExUnit.start
Application.ensure_all_started(:mox)
Application.ensure_all_started(:stream_data)

Mox.defmock(ExHal.ClientMock, for: ExHal.Client)

Application.put_env(:exhal, :client, ExHal.ClientMock)
