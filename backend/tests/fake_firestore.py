"""A tiny in-memory stand-in for the Firestore client.

It supports only what the backend uses: collection/document paths, get, set,
delete, stream, ``where(filter=FieldFilter(...))``, ``order_by`` and ``limit``.
"""

from datetime import datetime, timezone

from google.cloud import firestore


class FakeSnapshot:
    def __init__(self, doc_id, data):
        self.id = doc_id
        self._data = data

    @property
    def exists(self):
        return self._data is not None

    def to_dict(self):
        return dict(self._data) if self._data is not None else None


class FakeDocument:
    def __init__(self, store, path):
        self._store = store
        self._path = path  # (collection, id, collection, id, ...)

    def get(self):
        return FakeSnapshot(self._path[-1], self._store.get(self._path))

    def set(self, data, merge=False):
        new = {
            k: (datetime.now(timezone.utc) if v is firestore.SERVER_TIMESTAMP else v)
            for k, v in data.items()
        }
        self._store[self._path] = {**self._store.get(self._path, {}), **new} if merge else new

    def delete(self):
        self._store.pop(self._path, None)

    def collection(self, name):
        return FakeQuery(self._store, self._path + (name,))


class FakeQuery:
    def __init__(self, store, path, filters=(), order=None, size=None):
        self._store = store
        self._path = path
        self._filters = tuple(filters)
        self._order = order
        self._size = size

    def document(self, doc_id):
        return FakeDocument(self._store, self._path + (doc_id,))

    def where(self, *, filter):
        return FakeQuery(self._store, self._path, self._filters + (filter,), self._order, self._size)

    def order_by(self, field, direction="ASCENDING"):
        return FakeQuery(self._store, self._path, self._filters, (field, direction), self._size)

    def limit(self, size):
        return FakeQuery(self._store, self._path, self._filters, self._order, size)

    def stream(self):
        n = len(self._path)
        rows = [
            (path[-1], data)
            for path, data in self._store.items()
            if len(path) == n + 1 and path[:n] == self._path
        ]
        for f in self._filters:
            assert f.op_string == ">=", "the fake only knows >="
            rows = [r for r in rows if r[1].get(f.field_path) is not None and r[1][f.field_path] >= f.value]
        if self._order:
            field, direction = self._order
            rows.sort(key=lambda r: r[1][field], reverse=direction == "DESCENDING")
        if self._size is not None:
            rows = rows[: self._size]
        return iter(FakeSnapshot(i, d) for i, d in rows)


class FakeFirestore:
    def __init__(self):
        self._store = {}

    def collection(self, name):
        return FakeQuery(self._store, (name,))

    def put(self, *path_and_data):
        """put('users', 'u1', {...}) stores one document (a test helper)."""
        *path, data = path_and_data
        self._store[tuple(path)] = data
