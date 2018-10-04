ExUnit.start
Application.ensure_all_started(:mox)
Application.ensure_all_started(:stream_data)

Mox.defmock(ExHal.ClientMock, for: ExHal.Client)
Mox.defmock(ExHal.HttpClientMock, for: ExHal.HttpClient)
