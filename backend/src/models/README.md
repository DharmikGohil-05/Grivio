# models/

No ORM models are used — the schema lives in `backend/migrations/*.sql` and
services query it directly with `pg`. This folder is kept for parity with the
original project layout.
