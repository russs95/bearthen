.pragma library
.import QtQuick.LocalStorage 2.0 as LS

// ── Storage paths ─────────────────────────────────────────────────────────────
// Qt creates ~/.local/share/bearthen.russs95/ automatically for LocalStorage.
// We store files FLAT in that directory — no subdirs, so no mkdir ever needed.
// Filenames are prefixed: cover_<id>.jpg  book_<id>.epub
var APP_DATA_DIR = "/home/phablet/.local/share/bearthen.russs95"
var BOOKS_DIR    = APP_DATA_DIR   // flat — no subdir
var COVERS_DIR   = APP_DATA_DIR   // flat — no subdir

function coverPath(bookId) { return APP_DATA_DIR + "/cover_" + bookId + ".jpg" }
function bookPath(bookId)  { return APP_DATA_DIR + "/book_"  + bookId + ".epub" }

// ── Database bootstrap ────────────────────────────────────────────────────────
function _db() {
    return LS.LocalStorage.openDatabaseSync(
        "bearthen", "1.0",
        "Bearthen local library database",
        10 * 1024 * 1024   // 10 MB
    )
}

function init() {
    var db = _db()
    db.transaction(function(tx) {
        // books_tb
        tx.executeSql('\
            CREATE TABLE IF NOT EXISTS books_tb (\
                id            TEXT PRIMARY KEY,\
                title         TEXT NOT NULL,\
                author_id     TEXT,\
                author_display TEXT,\
                cover_url     TEXT DEFAULT "",\
                cover_local   TEXT DEFAULT "",\
                epub_url      TEXT DEFAULT "",\
                file_path     TEXT DEFAULT "",\
                source        TEXT DEFAULT "gutenberg",\
                source_id     TEXT DEFAULT "",\
                category      TEXT DEFAULT "other",\
                subjects      TEXT DEFAULT "[]",\
                language      TEXT DEFAULT "en",\
                date_added    INTEGER DEFAULT 0,\
                last_read     INTEGER DEFAULT 0,\
                read_percent  INTEGER DEFAULT 0,\
                read_position TEXT DEFAULT "",\
                is_finished   INTEGER DEFAULT 0,\
                tags          TEXT DEFAULT "[]",\
                notes         TEXT DEFAULT "",\
                eco_score     REAL,\
                downloads     INTEGER DEFAULT 0,\
                copyright     INTEGER,\
                birth_year    INTEGER,\
                death_year    INTEGER\
            )')

        // authors_tb
        tx.executeSql('\
            CREATE TABLE IF NOT EXISTS authors_tb (\
                id           TEXT PRIMARY KEY,\
                name_display TEXT NOT NULL,\
                name_sort    TEXT NOT NULL,\
                birth_year   INTEGER,\
                death_year   INTEGER,\
                nationality  TEXT\
            )')

        // reading_lists_tb
        tx.executeSql('\
            CREATE TABLE IF NOT EXISTS reading_lists_tb (\
                id          TEXT PRIMARY KEY,\
                name        TEXT NOT NULL,\
                description TEXT DEFAULT "",\
                created_at  INTEGER DEFAULT 0,\
                updated_at  INTEGER DEFAULT 0\
            )')

        // reading_list_entries_tb
        tx.executeSql('\
            CREATE TABLE IF NOT EXISTS reading_list_entries_tb (\
                list_id  TEXT NOT NULL,\
                book_id  TEXT NOT NULL,\
                position INTEGER DEFAULT 0,\
                PRIMARY KEY (list_id, book_id)\
            )')

        // Migrate: clear stale local paths from previous failed write attempts.
        // Any path containing "/covers/" or "/books/" subdir is from an old
        // broken build — wipe them so UI falls back to cover_url gracefully.
        try {
            tx.executeSql(
                "UPDATE books_tb SET cover_local = '' WHERE cover_local LIKE '%/covers/%'")
            tx.executeSql(
                "UPDATE books_tb SET cover_local = '' WHERE cover_local LIKE '%/QML/OfflineStorage/%'")
            tx.executeSql(
                "UPDATE books_tb SET file_path = '' WHERE file_path LIKE '%/books/%'")
            tx.executeSql(
                "UPDATE books_tb SET file_path = '' WHERE file_path LIKE '%/QML/OfflineStorage/%'")
        } catch(e) {}
    })
    console.log("Library: database ready")
}

// ── File helpers ──────────────────────────────────────────────────────────────

function _touchFile(path) {
    try {
        var xhr = new XMLHttpRequest()
        xhr.open("PUT", "file://" + path, false)
        xhr.send("")
    } catch(e) {}
}

// ── Books ─────────────────────────────────────────────────────────────────────

function addBook(book) {
    if (hasBook(book.id)) {
        console.log("Library.addBook: already exists:", book.id)
        return false
    }
    var now = Math.floor(Date.now() / 1000)
    var db  = _db()
    var ok  = false
    db.transaction(function(tx) {
        tx.executeSql('\
            INSERT INTO books_tb\
            (id, title, author_id, author_display, cover_url, cover_local,\
             epub_url, file_path, source, source_id, category, subjects,\
             language, date_added, last_read, read_percent, read_position,\
             is_finished, tags, notes, downloads, copyright, birth_year, death_year)\
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,0,0,"",0,"[]","",?,?,?,?)',
            [
                book.id,
                book.title || "",
                book.author_id || "",
                book.author_display || book.author || "",
                book.cover_url || book.cover || "",
                book.cover_local || "",
                book.epub_url || "",
                book.file_path || "",
                book.source || "gutenberg",
                book.source_id || "",
                book.category || "other",
                JSON.stringify(book.subjects || []),
                book.language || "en",
                now,
                book.downloads || 0,
                book.copyright === false ? 0 : (book.copyright === true ? 1 : null),
                book.birth_year || null,
                book.death_year || null
            ]
        )
        // Ensure author record exists
        if (book.author_id && (book.author_display || book.author)) {
            _ensureAuthor(tx, book.author_id, book.author_display || book.author)
        }
        ok = true
        console.log("Library.addBook: inserted", book.id)
    })
    return ok
}

function getBooks() {
    var db = _db()
    var books = []
    db.readTransaction(function(tx) {
        var rs = tx.executeSql(
            'SELECT * FROM books_tb ORDER BY date_added DESC')
        for (var i = 0; i < rs.rows.length; i++) {
            books.push(_rowToBook(rs.rows.item(i)))
        }
    })
    return books
}

function getBook(id) {
    var db = _db()
    var book = null
    db.readTransaction(function(tx) {
        var rs = tx.executeSql('SELECT * FROM books_tb WHERE id = ?', [id])
        if (rs.rows.length > 0) book = _rowToBook(rs.rows.item(0))
    })
    return book
}

function hasBook(id) {
    if (!id || id === "") return false
    var db = _db()
    var found = false
    db.readTransaction(function(tx) {
        var rs = tx.executeSql('SELECT id FROM books_tb WHERE id = ?', [id])
        found = rs.rows.length > 0
    })
    return found
}

function updateCoverLocal(id, localPath) {
    var db = _db()
    db.transaction(function(tx) {
        tx.executeSql('UPDATE books_tb SET cover_local = ? WHERE id = ?', [localPath, id])
    })
    console.log("Library.updateCoverLocal:", id, "->", localPath)
}

function updateFilePath(id, filePath) {
    var db = _db()
    db.transaction(function(tx) {
        tx.executeSql('UPDATE books_tb SET file_path = ? WHERE id = ?', [filePath, id])
    })
    console.log("Library.updateFilePath:", id, "->", filePath)
}

function updatePosition(id, cfi, percent) {
    var now = Math.floor(Date.now() / 1000)
    var db  = _db()
    db.transaction(function(tx) {
        tx.executeSql('\
            UPDATE books_tb SET\
                read_position = ?, read_percent = ?, last_read = ?\
            WHERE id = ?',
            [cfi, percent, now, id])
    })
}

function updateReadPercent(id, percent) {
    updatePosition(id, "", percent)
    console.log("Library.updateReadPercent:", id, "->", percent + "%")
}

function markFinished(id) {
    var db = _db()
    db.transaction(function(tx) {
        tx.executeSql(
            'UPDATE books_tb SET is_finished = 1, read_percent = 100 WHERE id = ?', [id])
    })
}

function removeBook(id) {
    var db = _db()
    db.transaction(function(tx) {
        tx.executeSql('DELETE FROM books_tb WHERE id = ?', [id])
    })
}

function getRecentlyRead(limit) {
    var db = _db()
    var books = []
    db.readTransaction(function(tx) {
        var rs = tx.executeSql(
            'SELECT * FROM books_tb WHERE last_read > 0 ORDER BY last_read DESC LIMIT ?',
            [limit || 10])
        for (var i = 0; i < rs.rows.length; i++)
            books.push(_rowToBook(rs.rows.item(i)))
    })
    return books
}

function getByCategory(category) {
    var db = _db()
    var books = []
    db.readTransaction(function(tx) {
        var rs = tx.executeSql(
            'SELECT * FROM books_tb WHERE category = ? ORDER BY date_added DESC', [category])
        for (var i = 0; i < rs.rows.length; i++)
            books.push(_rowToBook(rs.rows.item(i)))
    })
    return books
}

// ── Row mapper ────────────────────────────────────────────────────────────────

function _rowToBook(row) {
    return {
        id:            row.id,
        title:         row.title,
        author_id:     row.author_id,
        author:        row.author_display,
        author_display: row.author_display,
        cover_url:     row.cover_url,
        cover_local:   row.cover_local,
        cover:         row.cover_local !== "" ? row.cover_local : row.cover_url,
        epub_url:      row.epub_url,
        file_path:     row.file_path,
        source:        row.source,
        source_id:     row.source_id,
        category:      row.category,
        subjects:      _parseJson(row.subjects, []),
        language:      row.language,
        date_added:    row.date_added,
        last_read:     row.last_read,
        read_percent:  row.read_percent,
        read_position: row.read_position,
        is_finished:   row.is_finished === 1,
        tags:          _parseJson(row.tags, []),
        notes:         row.notes,
        downloads:     row.downloads,
        copyright:     row.copyright === 0 ? false : (row.copyright === 1 ? true : null),
        birth_year:    row.birth_year,
        death_year:    row.death_year,
        hasEpub:       (row.epub_url || "") !== ""
    }
}

function _parseJson(str, fallback) {
    try { return JSON.parse(str) } catch(e) { return fallback }
}

// ── Authors ───────────────────────────────────────────────────────────────────

function _ensureAuthor(tx, authorId, authorDisplay) {
    var rs = tx.executeSql('SELECT id FROM authors_tb WHERE id = ?', [authorId])
    if (rs.rows.length > 0) return
    var parts    = authorDisplay.trim().split(" ")
    var lastName = parts.length > 1 ? parts[parts.length - 1] : authorDisplay
    var nameSort = parts.length > 1
        ? lastName + ", " + parts.slice(0, parts.length - 1).join(" ")
        : authorDisplay
    tx.executeSql(
        'INSERT INTO authors_tb (id, name_display, name_sort) VALUES (?,?,?)',
        [authorId, authorDisplay, nameSort])
}

function getAuthor(id) {
    var db = _db()
    var author = null
    db.readTransaction(function(tx) {
        var rs = tx.executeSql('SELECT * FROM authors_tb WHERE id = ?', [id])
        if (rs.rows.length > 0) author = rs.rows.item(0)
    })
    return author
}

// ── Reading lists ─────────────────────────────────────────────────────────────

function getLists() {
    var db = _db(); var lists = []
    db.readTransaction(function(tx) {
        var rs = tx.executeSql('SELECT * FROM reading_lists_tb ORDER BY updated_at DESC')
        for (var i = 0; i < rs.rows.length; i++) {
            var row  = rs.rows.item(i)
            var list = { id: row.id, name: row.name, description: row.description,
                         created_at: row.created_at, updated_at: row.updated_at, book_ids: [] }
            var rs2  = tx.executeSql(
                'SELECT book_id FROM reading_list_entries_tb WHERE list_id = ? ORDER BY position',
                [row.id])
            for (var j = 0; j < rs2.rows.length; j++)
                list.book_ids.push(rs2.rows.item(j).book_id)
            lists.push(list)
        }
    })
    return lists
}

function createList(name, desc) {
    var id  = "list-" + Math.random().toString(36).substr(2, 9)
    var now = Math.floor(Date.now() / 1000)
    var db  = _db()
    db.transaction(function(tx) {
        tx.executeSql(
            'INSERT INTO reading_lists_tb (id, name, description, created_at, updated_at) VALUES (?,?,?,?,?)',
            [id, name, desc || "", now, now])
    })
    return id
}

function addToList(listId, bookId) {
    var db = _db()
    db.transaction(function(tx) {
        var rs  = tx.executeSql(
            'SELECT MAX(position) as maxpos FROM reading_list_entries_tb WHERE list_id = ?',
            [listId])
        var pos = rs.rows.length > 0 ? (rs.rows.item(0).maxpos || 0) + 1 : 0
        tx.executeSql(
            'INSERT OR IGNORE INTO reading_list_entries_tb (list_id, book_id, position) VALUES (?,?,?)',
            [listId, bookId, pos])
        tx.executeSql(
            'UPDATE reading_lists_tb SET updated_at = ? WHERE id = ?',
            [Math.floor(Date.now() / 1000), listId])
    })
}

function removeFromList(listId, bookId) {
    var db = _db()
    db.transaction(function(tx) {
        tx.executeSql(
            'DELETE FROM reading_list_entries_tb WHERE list_id = ? AND book_id = ?',
            [listId, bookId])
    })
}

function deleteList(listId) {
    var db = _db()
    db.transaction(function(tx) {
        tx.executeSql('DELETE FROM reading_list_entries_tb WHERE list_id = ?', [listId])
        tx.executeSql('DELETE FROM reading_lists_tb WHERE id = ?', [listId])
    })
}

// ── Sync helpers ──────────────────────────────────────────────────────────────

function getSince(timestamp) {
    var db = _db(); var books = []
    db.readTransaction(function(tx) {
        var rs = tx.executeSql(
            'SELECT * FROM books_tb WHERE date_added > ? OR last_read > ?',
            [timestamp, timestamp])
        for (var i = 0; i < rs.rows.length; i++)
            books.push(_rowToBook(rs.rows.item(i)))
    })
    return books
}

function exportJSON() {
    var lib = {
        meta: { version: 2, exported_at: Math.floor(Date.now() / 1000) },
        books_tb:         getBooks(),
        reading_lists_tb: getLists()
    }
    return JSON.stringify(lib, null, 2)
}
