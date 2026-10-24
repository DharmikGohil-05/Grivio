# services/

One service per backend feature (`auth`, `profile`, `goal`, `task`, `focus`,
`progress`, `weekly_review`, `ai`). Every network call goes through
`api_client.dart` — the single place for the Bearer header, timeout and error
mapping. `auth_storage.dart` wraps flutter_secure-storage for the JWT and the
theme preference.
