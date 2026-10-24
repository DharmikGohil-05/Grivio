# models/

Data models live inside their feature service files (e.g. `GrivioTask` in
`services/task_service.dart`, `FocusSession` in `services/focus_service.dart`)
next to their `fromJson`/`toJson` logic, so each model and its API contract
stay in one place.
