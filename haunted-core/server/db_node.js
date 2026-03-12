const REQUEST_EVENT = 'haunted:db:node:request';
const RESPONSE_EVENT = 'haunted:db:node:response';

let mysql = null;
let pool = null;
let initialized = false;

function serializeError(error) {
    if (!error) return 'unknown_error';
    if (typeof error === 'string') return error;
    if (error.sqlMessage) return error.sqlMessage;
    if (error.message) return error.message;
    return JSON.stringify(error);
}

function emitResponse(requestId, ok, result, error) {
    emit(RESPONSE_EVENT, requestId, ok, result ?? null, error ?? null);
}

function isNumericKeyObject(obj) {
    const keys = Object.keys(obj);
    if (keys.length === 0) return false;
    for (const key of keys) {
        if (!/^\d+$/.test(key)) {
            return false;
        }
    }
    return true;
}

function normalizeParams(params) {
    if (params === undefined || params === null) {
        return [];
    }

    if (Array.isArray(params)) {
        return params;
    }

    if (typeof params !== 'object') {
        return [params];
    }

    if (isNumericKeyObject(params)) {
        return Object.keys(params)
            .sort((a, b) => Number(a) - Number(b))
            .map((key) => params[key]);
    }

    const out = {};
    for (const [key, value] of Object.entries(params)) {
        out[key] = value;
        if (key.startsWith('@') || key.startsWith(':')) {
            const alias = key.substring(1);
            if (out[alias] === undefined) out[alias] = value;
        } else {
            if (out[`@${key}`] === undefined) out[`@${key}`] = value;
            if (out[`:${key}`] === undefined) out[`:${key}`] = value;
        }
    }
    return out;
}

function normalizeQueryAndParams(query, params) {
    let sql = String(query || '');
    const normalized = normalizeParams(params);

    if (!Array.isArray(normalized)) {
        sql = sql.replace(/@([a-zA-Z0-9_]+)/g, ':$1');
    }

    return { sql, params: normalized };
}

function firstScalar(rows) {
    if (!Array.isArray(rows) || rows.length === 0) {
        return null;
    }

    const firstRow = rows[0];
    if (firstRow === null || typeof firstRow !== 'object') {
        return firstRow ?? null;
    }

    const keys = Object.keys(firstRow);
    if (keys.length === 0) {
        return null;
    }

    return firstRow[keys[0]];
}

function getNativeConfig(config) {
    const cfg = config || {};
    return {
        host: cfg.Host || '127.0.0.1',
        port: Number(cfg.Port) || 3306,
        user: cfg.User || 'root',
        password: cfg.Password || '',
        database: cfg.Database || '',
        charset: cfg.Charset || 'utf8mb4',
        waitForConnections: true,
        connectionLimit: Number(cfg.ConnectionLimit) || 10,
        queueLimit: Number(cfg.QueueLimit) || 0,
        supportBigNumbers: cfg.SupportBigNumbers !== false,
        bigNumberStrings: !!cfg.BigNumberStrings,
        namedPlaceholders: true,
        multipleStatements: false,
        enableKeepAlive: cfg.EnableKeepAlive !== false,
        keepAliveInitialDelay: Number(cfg.KeepAliveInitialDelay) || 0,
        connectTimeout: Number(cfg.ConnectTimeoutMs) || 10000
    };
}

async function initPool(config) {
    if (initialized && pool) {
        return true;
    }

    if (!mysql) {
        try {
            mysql = require('mysql2/promise');
        } catch (error) {
            throw new Error(
                `mysql2 dependency missing. Run npm install in haunted-core (${serializeError(error)})`
            );
        }
    }

    pool = mysql.createPool(getNativeConfig(config));

    const connection = await pool.getConnection();
    try {
        await connection.query('SELECT 1');
    } finally {
        connection.release();
    }

    initialized = true;
    return true;
}

async function runQuery(method, query, params) {
    const { sql, params: bound } = normalizeQueryAndParams(query, params);
    const lowerMethod = String(method || 'query').toLowerCase();

    if (lowerMethod === 'query' || lowerMethod === 'prepare') {
        const [rows] = await pool.query(sql, bound);
        return rows;
    }

    if (lowerMethod === 'single') {
        const [rows] = await pool.query(sql, bound);
        if (!Array.isArray(rows) || rows.length === 0) {
            return null;
        }
        return rows[0];
    }

    if (lowerMethod === 'scalar') {
        const [rows] = await pool.query(sql, bound);
        return firstScalar(rows);
    }

    if (lowerMethod === 'insert') {
        const [result] = await pool.query(sql, bound);
        return Number(result.insertId || 0);
    }

    if (lowerMethod === 'update' || lowerMethod === 'execute') {
        const [result] = await pool.query(sql, bound);
        return Number(result.affectedRows || 0);
    }

    throw new Error(`unsupported_method:${lowerMethod}`);
}

async function runTransaction(queries) {
    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();
        for (const item of queries || []) {
            const sql = item.query || item[1];
            const values = item.values || item.params || item[2] || [];
            if (!sql) {
                continue;
            }
            const normalized = normalizeQueryAndParams(sql, values);
            await connection.query(normalized.sql, normalized.params);
        }
        await connection.commit();
        return true;
    } catch (error) {
        try {
            await connection.rollback();
        } catch (_) {
        }
        throw error;
    } finally {
        connection.release();
    }
}

on(REQUEST_EVENT, async (requestId, action, payload) => {
    try {
        if (action === 'init') {
            await initPool(payload || {});
            emitResponse(requestId, true, { ready: true }, null);
            return;
        }

        if (action === 'close') {
            if (pool) {
                await pool.end();
            }
            pool = null;
            initialized = false;
            emitResponse(requestId, true, true, null);
            return;
        }

        if (!initialized || !pool) {
            throw new Error('native_mariadb_not_initialized');
        }

        if (action === 'execute') {
            const request = payload || {};
            if (request.method === 'transaction') {
                const success = await runTransaction(request.queries || []);
                emitResponse(requestId, true, success, null);
                return;
            }

            const result = await runQuery(request.method, request.query, request.params);
            emitResponse(requestId, true, result, null);
            return;
        }

        throw new Error(`unknown_action:${String(action)}`);
    } catch (error) {
        emitResponse(requestId, false, null, serializeError(error));
    }
});

on('onResourceStop', async (resource) => {
    if (resource !== GetCurrentResourceName()) {
        return;
    }

    if (pool) {
        try {
            await pool.end();
        } catch (_) {
        }
    }
    pool = null;
    initialized = false;
});
